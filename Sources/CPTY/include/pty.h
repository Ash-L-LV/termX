#ifndef PTY_H
#define PTY_H

/*
 * Thin C wrappers around forkpty()/ioctl() so Swift can manage
 * pseudo-terminals without fragile @_silgen_name declarations.
 */

int pty_forkpty(int *master_fd);
int pty_spawn(const char *path, char *const argv[], char *const envp[], const char *cwd, int *master_fd);
int pty_set_winsize(int fd, int rows, int cols);

#endif
