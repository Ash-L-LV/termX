import Foundation
import Darwin
import CPTY
import TermXCore

/// Manages a child process attached to a pseudo-terminal: raw output delivery
/// with bounded backpressure, input writes, terminal resize, and graceful
/// termination (SIGHUP with a SIGKILL fallback).
enum PTYError: Error {
    case spawnFailed(Int32)
}

/// Manages a child process attached to a pseudo-terminal.
final class PTYProcess {
    private var masterFD: Int32 = -1
    private(set) var childPID: pid_t = -1
    private var readerThread: Thread?
    private let stateLock = NSLock()
    private var stoppedFlag = false
    /// Limits how many output chunks can be queued to the main thread before
    /// the reader pauses (bounded queue + natural backpressure). Uses an
    /// NSCondition instead of a DispatchSemaphore because GCD traps when a
    /// semaphore is deallocated while a thread is still waiting on it.
    private let gateCondition = NSCondition()
    private var inFlightChunks = 0

    /// Called on a background thread with raw bytes read from the pty.
    var onData: ((Data) -> Void)?
    /// Called on the main thread once the pty reaches EOF.
    var onExit: (() -> Void)?

    var isStopped: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return stoppedFlag
    }

    /// Called by the consumer (main thread) after a chunk has been fully
    /// processed, releasing a slot so the reader can continue.
    func processedChunk() {
        gateCondition.lock()
        if inFlightChunks > 0 {
            inFlightChunks -= 1
        }
        gateCondition.signal()
        gateCondition.unlock()
    }

    private func acquireSlot() {
        gateCondition.lock()
        while inFlightChunks >= 2, !isStopped {
            gateCondition.wait(until: Date().addingTimeInterval(0.2))
        }
        if !isStopped {
            inFlightChunks += 1
        }
        gateCondition.unlock()
    }

    private func releaseSlot() {
        gateCondition.lock()
        if inFlightChunks > 0 {
            inFlightChunks -= 1
        }
        gateCondition.unlock()
    }

    private func setStopped(_ value: Bool) {
        stateLock.lock()
        stoppedFlag = value
        stateLock.unlock()
    }

    @discardableResult
    func spawn(path: String,
               arguments: [String],
               environment: [String: String]? = nil,
               workingDirectory: String? = nil) throws -> pid_t {
        var env = ProcessInfo.processInfo.environment
        if let environment {
            env.merge(environment) { _, new in new }
        }

        var cargs: [UnsafeMutablePointer<CChar>?] = ([path] + arguments).map { strdup($0) }
        var cenv: [UnsafeMutablePointer<CChar>?] = env.map { strdup("\($0.key)=\($0.value)") }
        cargs.append(nil)
        cenv.append(nil)
        defer {
            cargs.forEach { if let p = $0 { free(p) } }
            cenv.forEach { if let p = $0 { free(p) } }
        }

        var master: Int32 = -1
        let nsCwd: NSString? = workingDirectory.map { $0 as NSString }
        let cwdPointer = nsCwd?.utf8String
        let pid = cargs.withUnsafeMutableBufferPointer { argBuffer -> Int32 in
            cenv.withUnsafeMutableBufferPointer { envBuffer -> Int32 in
                pty_spawn(path, argBuffer.baseAddress, envBuffer.baseAddress, cwdPointer, &master)
            }
        }
        guard pid >= 0, master >= 0 else {
            throw PTYError.spawnFailed(errno)
        }

        childPID = pid
        masterFD = master
        setStopped(false)
        startReader()
        return pid
    }

    func write(_ data: Data) {
        guard !isStopped else { return }
        let fd = masterFD
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            var total = 0
            while total < data.count {
                let n = Darwin.write(fd, base.advanced(by: total), data.count - total)
                if n < 0 {
                    if errno == EINTR { continue }
                    break
                }
                total += n
            }
        }
    }

    func write(_ text: String) {
        write(Data(text.utf8))
    }

    func resize(rows: Int, cols: Int) {
        guard masterFD >= 0, !isStopped else { return }
        pty_set_winsize(masterFD, Int32(rows), Int32(cols))
    }

    /// Sends SIGHUP to the child and lets the reader thread drain and exit.
    func terminate() {
        setStopped(true)
        // Unblock the reader in case it is waiting for a processing slot.
        gateCondition.lock()
        gateCondition.broadcast()
        gateCondition.unlock()
        let pid = childPID
        if pid > 0 {
            Darwin.kill(pid, SIGHUP)
            // Some processes (e.g. an authenticated `ssh -N` tunnel) can
            // survive SIGHUP; escalate to SIGKILL shortly after so the
            // process and any forwarded ports are guaranteed to go away.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
                if Darwin.kill(pid, 0) == 0 {
                    Darwin.kill(pid, SIGKILL)
                }
            }
            reapChildAsync(pid)
        }
    }

    private func reapChildAsync(_ pid: pid_t) {
        DispatchQueue.global(qos: .utility).async {
            var status: Int32 = 0
            var attempts = 0
            while attempts < 100 {
                let result = Darwin.waitpid(pid, &status, WNOHANG)
                if result == pid || (result == -1 && errno == ECHILD) {
                    return
                }
                usleep(20_000)
                attempts += 1
            }
        }
    }

    private func startReader() {
        let fd = masterFD
        let thread = Thread { [weak self] in self?.readerLoop(fd: fd) }
        thread.name = "TermX-PTY-\(childPID)"
        readerThread = thread
        thread.start()
    }

    private func readerLoop(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            if isStopped { break }
            acquireSlot()
            if isStopped { break }
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let pollResult = Darwin.poll(&pfd, 1, 200)
            if isStopped { break }
            if pollResult < 0 {
                if errno == EINTR { continue }
                releaseSlot()
                break
            }
            if pollResult == 0 {
                releaseSlot()
                continue
            }
            if (pfd.revents & Int16(POLLIN)) == 0 {
                releaseSlot()
                break
            }
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count > 0 {
                let data = Data(bytes: buffer, count: count)
                onData?(data)
            } else if count == 0 {
                releaseSlot()
                break
            } else if errno != EINTR {
                releaseSlot()
                break
            }
        }
        Darwin.close(fd)
        setStopped(true)
        DispatchQueue.main.async { [weak self] in
            self?.onExit?()
        }
    }
}
