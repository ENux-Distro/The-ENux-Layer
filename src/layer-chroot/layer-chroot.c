/*
 * layer-chroot - run a command inside an ENux layer AS THE CALLING USER,
 * with no root, no setuid and no namespaces. It relies solely on the
 * cap_sys_chroot file capability (set with `setcap cap_sys_chroot=ep`), so the
 * only privileged operation it can perform is chroot(2) - it cannot escalate.
 *
 * This is what lets a cross command run in its layer's FULL view (its own
 * /etc, /usr, interpreters - so scripts, rpm's rpmrc, configs all resolve) as
 * the real user (so GUI apps keep the user's X authority) without sudo, and
 * even from inside another chroot (a --gui desktop) - it breaks out to the
 * absolute root first. Plain chroot needs no user namespace, so it is immune
 * to the kernel's "no unprivileged userns inside a chroot" rule that stops
 * bwrap there.
 *
 * Inspired by Bedrock Linux 1.0beta1 "brc" by Daniel Thau (GPL-2.0), itself
 * derived from capchroot by Thomas Baechler. ENux changes: layer layout, a
 * root-owned-directory security gate instead of a .conf check, a libcap-free
 * implementation, a break-out anchor under /enux that is never a layer
 * ancestor, and renamed to layer-chroot to match ENux libexec conventions.
 *
 * License: GPL-2.0.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>

#define LAYERDIR "/enux/layer/"
/* Break-out anchor: a real, root-owned directory that is NEVER an ancestor of
 * a layer root, so that after chroot()ing into it our old cwd lies OUTSIDE the
 * new root and `cd ..` can walk up to the true absolute root. /enux/libexec is
 * where this very binary lives, so it always exists. */
#define BREAKOUT "/enux/libexec"

/*
 * Escape any surrounding chroot and land at the true absolute root.
 *
 * Trick (from capchroot): chroot() does not move cwd. So chroot() into a
 * directory while cwd sits outside it leaves cwd "above" the new root; the
 * kernel then lets `cd ..` climb past it. We climb until "." and ".." share an
 * inode (the real root is its own parent), then re-root there.
 *
 * Works whether or not we start inside a chroot: from the base, cwd "/" is
 * already an ancestor of BREAKOUT so we simply re-root at "/".
 */
static void break_out_of_chroot(void)
{
	struct stat here, up;

	if (chdir("/") != 0) {
		perror("layer-chroot: chdir /");
		exit(1);
	}
	if (chroot(BREAKOUT) != 0) {
		fprintf(stderr,
			"layer-chroot: chroot failed (%s) - the cap_sys_chroot capability is missing.\n"
			"     fix as root:  setcap cap_sys_chroot=ep /enux/libexec/layer-chroot\n",
			strerror(errno));
		exit(1);
	}
	do {
		if (chdir("..") != 0) {
			perror("layer-chroot: chdir ..");
			exit(1);
		}
		if (stat(".", &here) != 0 || stat("..", &up) != 0) {
			perror("layer-chroot: stat");
			exit(1);
		}
	} while (here.st_ino != up.st_ino);

	if (chroot(".") != 0) {
		perror("layer-chroot: chroot to absolute root");
		exit(1);
	}
}

int main(int argc, char *argv[])
{
	if (argc < 2) {
		fprintf(stderr, "usage: layer-chroot <layer> [command [args...]]\n");
		exit(2);
	}
	char *layer = argv[1];

	/* Reject anything that could escape the layer dir by name. */
	if (layer[0] == '\0' || strchr(layer, '/') != NULL ||
	    strcmp(layer, ".") == 0 || strcmp(layer, "..") == 0) {
		fprintf(stderr, "layer-chroot: invalid layer name '%s'\n", layer);
		exit(1);
	}

	/* Remember cwd so we can restore it inside the layer. */
	char cwd[PATH_MAX + 1];
	if (getcwd(cwd, sizeof cwd) == NULL) {
		cwd[0] = '/';
		cwd[1] = '\0';
	}

	/* Escape to the absolute root before doing anything else, so the security
	 * check below is made against the real filesystem, not a bind-mounted view
	 * inside some chroot. */
	break_out_of_chroot();

	/* Resolve the target. The "enux" layer IS the base (the absolute root). */
	char target[sizeof(LAYERDIR) + NAME_MAX + 1];
	if (strcmp(layer, "enux") == 0) {
		strcpy(target, "/");
	} else {
		if (snprintf(target, sizeof target, "%s%s", LAYERDIR, layer) >=
		    (int)sizeof target) {
			fprintf(stderr, "layer-chroot: layer name too long\n");
			exit(1);
		}
		/* SECURITY GATE: only ever chroot into a real, ROOT-OWNED layer dir.
		 * Users cannot create root-owned directories under /enux/layer, so this
		 * whitelists genuine installed layers and nothing the caller controls -
		 * essential for a cap_sys_chroot binary that any user may run. */
		struct stat st;
		if (stat(target, &st) != 0 || !S_ISDIR(st.st_mode)) {
			fprintf(stderr, "layer-chroot: layer '%s' is not installed\n", layer);
			exit(1);
		}
		if (st.st_uid != 0) {
			fprintf(stderr, "layer-chroot: refusing - layer '%s' is not root-owned\n",
				layer);
			exit(1);
		}
	}

	if (chdir(target) != 0) {
		perror("layer-chroot: chdir layer");
		exit(1);
	}
	if (chroot(".") != 0) {
		perror("layer-chroot: chroot layer");
		exit(1);
	}
	/* Restore the working directory if it exists in the layer. */
	if (chdir(cwd) != 0)
		(void)chdir("/");

	/* Pick the command: the given one, else $SHELL if present, else /bin/sh. */
	char *fallback[2];
	char **cmd;
	if (argc > 2) {
		cmd = argv + 2;
	} else {
		char *sh = getenv("SHELL");
		struct stat s;
		fallback[0] = (sh != NULL && stat(sh, &s) == 0) ? sh : "/bin/sh";
		fallback[1] = NULL;
		cmd = fallback;
	}

	/* cap_sys_chroot drops on exec (file caps don't propagate unless the new
	 * binary also carries them), so the command runs as the plain calling user
	 * and cannot re-chroot. */
	execvp(cmd[0], cmd);
	perror("layer-chroot: execvp");
	return 127;
}
