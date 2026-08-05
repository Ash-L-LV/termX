#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <util.h>

#include "pty.h"

int pty_forkpty(int *master_fd) {
    if (master_fd == NULL) {
        errno = EINVAL;
        return -1;
    }
    *master_fd = -1;
    pid_t pid = forkpty(master_fd, NULL, NULL, NULL);
    return (int)pid;
}

int pty_spawn(const char *path, char *const argv[], char *const envp[], const char *cwd, int *master_fd) {
    if (master_fd == NULL || path == NULL || argv == NULL) {
        errno = EINVAL;
        return -1;
    }
    *master_fd = -1;
    pid_t pid = forkpty(master_fd, NULL, NULL, NULL);
    if (pid == -1) {
        return -1;
    }
    if (pid == 0) {
        /* Child: replace the image with the requested program. */
        if (cwd != NULL) {
            (void)chdir(cwd);
        }
        execve(path, argv, envp);
        _exit(127);
    }
    return (int)pid;
}

int pty_set_winsize(int fd, int rows, int cols) {
    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    ws.ws_row = (unsigned short)rows;
    ws.ws_col = (unsigned short)cols;
    return ioctl(fd, TIOCSWINSZ, &ws);
}
