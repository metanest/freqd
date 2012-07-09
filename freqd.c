#include <sys/types.h>
#include <sys/sysctl.h>
#include <string.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#include <stdlib.h>
#include <stdio.h>

#include "config.h"

#define BUFSIZE 16

int
main(void)
{
	int pipe_fds[2];

	if (pipe(pipe_fds)) {
		perror("A");
		exit(EXIT_FAILURE);
	}

	{
		pid_t child_pid;

		child_pid = fork();
		if (child_pid < -1) {
			perror("B");
			exit(EXIT_FAILURE);
		} else if (child_pid == -1) {
			perror("C");
			exit(EXIT_FAILURE);
		} else if (child_pid == 0) {
			/* here is child process */

			/* setup pipe */
			close(pipe_fds[0]);
			close(1);
			dup2(pipe_fds[1], 1);
			close(pipe_fds[1]);

			/* discard privilege */
			{
				gid_t nobody_gid;
				uid_t nobody_uid;

				{
					struct group *gr;
					gr = getgrnam("nobody");
					if (! gr) {
						perror("D");
						exit(EXIT_FAILURE);
					}
					nobody_gid = gr->gr_gid;
				}
				{
					struct passwd *pw;
					pw = getpwnam("nobody");
					if (! pw) {
						perror("E");
						exit(EXIT_FAILURE);
					}
					nobody_uid = pw->pw_uid;
				}

				if (setgid(nobody_gid)) {
					perror("F");
					exit(EXIT_FAILURE);
				}
				if (setuid(nobody_uid)) {
					perror("G");
					exit(EXIT_FAILURE);
				}
			}

			{
				char *prog = BASE_PATH "/freqd.awk";
				char *argv[2];

				argv[0] = prog;
				argv[1] = 0;
				execv(prog, argv);
			}
			/* failed to exec in child */
			perror("H");
			exit(EXIT_FAILURE);
		}
	}

	/* here is parent process */

	close(pipe_fds[1]);

	{
		int freq_mib[4];
		size_t freq_mib_len = sizeof(freq_mib) / sizeof(freq_mib[0]);
		FILE *fp;

		if (sysctlnametomib("dev.cpu.0.freq", freq_mib, &freq_mib_len)) {
			fputs("failed to get mib\n", stderr);
			exit(EXIT_FAILURE);
		}

		fp = fdopen(pipe_fds[0], "r");

		for (;;) {
			char *r;
			char buf[BUFSIZE];
			int freq;

			r = fgets(buf, BUFSIZE, fp);
			if (!r || (strlen(buf) >= BUFSIZE)) {
				perror("read error");
				exit(EXIT_FAILURE);
			}
			freq = atoi(r);
			/* printf("%d\n", freq); */
			if (freq < 0) {
				fputs("freq range error\n", stderr);
				exit(EXIT_FAILURE);
			}
			if (sysctl(freq_mib, 4, NULL, NULL, &freq, sizeof(freq))) {
				fputs("failed to set freq\n", stderr);
				exit(EXIT_FAILURE);
			}
		}
	}
}
