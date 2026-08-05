import AppKit
import TermXCore

/// Manages the tab strip, the terminal content area, and tab lifecycle
/// (close / detach / re-dock).
final class TerminalTabViewController: NSViewController {
    private final class TabRecord {
        let vc: TerminalViewController
        let item: TabItemView
        var title: String
        var serverTitle: String?
        init(vc: TerminalViewController, item: TabItemView, title: String, serverTitle: String? = nil) {
            self.vc = vc
            self.item = item
            self.title = title
            self.serverTitle = serverTitle
        }
    }

    private let strip = TabStripView()
    private let content = NSView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private var records: [TabRecord] = []

    var onDetach: ((TerminalViewController) -> Void)?
    var onAddRequested: ((NSView) -> Void)?
    var onTabActivated: ((TerminalViewController?) -> Void)?
    /// Fired when the last tab is closed or detached, so the (now empty)
    /// main window can close itself.
    var onAllTabsClosed: (() -> Void)?

    var activeTab: TerminalViewController? {
        records.first { $0.item.isActive }?.vc
    }

    var allTabs: [TerminalViewController] { records.map { $0.vc } }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        view = container

        let stripHeight: CGFloat = 48
        content.frame = NSRect(x: 0, y: 0, width: container.bounds.width, height: container.bounds.height - stripHeight - 1)
        content.autoresizingMask = [.width, .height]
        container.addSubview(content)

        emptyLabel.stringValue = L.t("emptyTabs")
        emptyLabel.alignment = .center
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.isHidden = true
        container.addSubview(emptyLabel)

        // The strip is added last so it is always hit-testable, even if the
        // terminal content ever overlaps its frame.
        strip.frame = NSRect(x: 0, y: container.bounds.height - stripHeight, width: container.bounds.width, height: stripHeight)
        strip.autoresizingMask = [.width, .minYMargin]
        strip.plusAction = { [weak self] anchor in self?.onAddRequested?(anchor) }
        container.addSubview(strip)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        emptyLabel.sizeToFit()
        emptyLabel.frame = NSRect(x: (view.bounds.width - emptyLabel.frame.width) / 2,
                                  y: (view.bounds.height - emptyLabel.frame.height) / 2,
                                  width: emptyLabel.frame.width,
                                  height: emptyLabel.frame.height)
    }

    // MARK: - Tab management

    @discardableResult
    func addTab(_ vc: TerminalViewController, activate: Bool = true) -> TabItemView {
        let item = TabItemView(title: vc.displayTitle, tabColor: vc.session.tabColorNSColor)
        let record = TabRecord(vc: vc, item: item, title: vc.displayTitle)
        records.append(record)

        item.onSelect = { [weak self, weak vc] in
            guard let self, let vc else { return }
            self.select(vc)
        }
        item.onClose = { [weak self, weak vc] in
            guard let self, let vc else { return }
            self.close(vc)
        }
        item.onDetach = { [weak self, weak vc] in
            guard let self, let vc else { return }
            // Remove the tab from the strip first, otherwise a ghost tab is
            // left behind in the main window after the drag-out.
            self.detach(vc)
            self.onDetach?(vc)
        }
        vc.onServerTitleChange = { [weak self, weak vc] serverTitle in
            guard let self, let vc else { return }
            self.updateServerTitle(vc, serverTitle: serverTitle)
        }
        vc.onSessionEnded = { [weak self, weak vc] in
            guard let self, let vc else { return }
            self.markEnded(vc)
        }

        refreshStrip()
        if activate {
            select(vc)
        }
        return item
    }

    func select(_ vc: TerminalViewController) {
        for record in records {
            record.item.isActive = record.vc === vc
            record.item.needsDisplay = true
        }
        guard let record = records.first(where: { $0.vc === vc }) else { return }

        // Detach every other tab's view so pages never stack on top of each
        // other (especially visible with translucent backgrounds).
        for other in records where other.vc !== vc {
            if other.vc.view.superview === content {
                other.vc.view.removeFromSuperview()
            }
        }
        if record.vc.parent !== self {
            addChild(record.vc)
        }
        if record.vc.view.superview !== content {
            record.vc.view.frame = content.bounds
            record.vc.view.autoresizingMask = [.width, .height]
            content.addSubview(record.vc.view)
            record.vc.applyAppearance()
        }
        emptyLabel.isHidden = true
        updateWindowTitle()
        onTabActivated?(vc)
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(vc.terminalView)
        }
    }

    func close(_ vc: TerminalViewController) {
        guard let index = records.firstIndex(where: { $0.vc === vc }) else { return }
        vc.terminateSession()
        records.remove(at: index)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        refreshStrip()

        if records.isEmpty {
            emptyLabel.isHidden = false
            onTabActivated?(nil)
            onAllTabsClosed?()
        } else {
            let next = records[min(index, records.count - 1)]
            select(next.vc)
        }
    }

    func detach(_ vc: TerminalViewController) {
        guard let index = records.firstIndex(where: { $0.vc === vc }) else { return }
        records.remove(at: index)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        refreshStrip()
        if records.isEmpty {
            emptyLabel.isHidden = false
            onTabActivated?(nil)
            onAllTabsClosed?()
        } else {
            select(records[min(index, records.count - 1)].vc)
        }
    }

    func markEnded(_ vc: TerminalViewController) {
        guard let record = records.first(where: { $0.vc === vc }) else { return }
        record.item.isDead = true
        record.title = vc.displayTitle + L.t("endedSuffix")
        record.item.title = record.title
        relayoutStrip()
    }

    private func updateServerTitle(_ vc: TerminalViewController, serverTitle: String?) {
        guard let record = records.first(where: { $0.vc === vc }) else { return }
        record.serverTitle = serverTitle
        record.item.subtitle = serverTitle
        relayoutStrip()
    }

    private func updateWindowTitle() {
        if let active = activeTab {
            view.window?.title = active.displayTitle
        } else {
            view.window?.title = "TermX"
        }
    }

    private func refreshStrip() {
        strip.items = records.map { $0.item }
        relayoutStrip()
    }

    private func relayoutStrip() {
        strip.needsLayout = true
        strip.layoutSubtreeIfNeeded()
    }

    /// The tab strip's frame in screen coordinates (nil if not in a window).
    var tabStripFrameInScreen: NSRect? {
        guard let window = strip.window else { return nil }
        return window.convertToScreen(strip.convert(strip.bounds, to: nil))
    }

    func setDropHighlight(_ on: Bool) {
        strip.isDropTarget = on
    }
}
