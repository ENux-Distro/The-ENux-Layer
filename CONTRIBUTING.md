# Contributing to The ENux Layer

Thanks for your interest in The ENux Layer.

## Scope

This repo is the layer tooling (`enux`, `layer`, `pmm`, `debinstall`) and
the mechanics under `libexec/`. The PID-1 init lives in a separate repo,
[init.c](https://github.com/ENux-Distro/init.c); changes to boot behavior
go there.

## Code style

- **POSIX `sh`**, not bash — the scripts run as `/bin/sh` and inside login
  shells across many distros. No bashisms (`[[ ]]`, arrays, `local` ...).
- Run `make check` before sending a change; it `sh -n`-checks every script
  and runs `shellcheck` if present.
- Keep helpers small and readable; comment only non-obvious constraints
  (mount propagation, why a path is shared, etc.), not the obvious.
- Variables that a function sets must not clobber callers — POSIX `sh` has
  no `local`, so prefix working vars or run the body in a `( )` subshell
  (see `cross_update`).

## Things that bite (learned the hard way)

- A self-bind mount needs `mount --make-private` or nested binds double up
  in `mountinfo`.
- A layer must be fully disabled (all stacked mounts drained) before
  `mksquashfs`, or live `/proc`/`/dev` get baked into the image.
- `cp -a` (never plain `cp`) when copying the tooling/cross dir, so the
  hundreds of symlinks survive.
- Cross commands run a program inside its owning layer, so each layer
  carries its own `/lib`/`/usr` — never mix one distro's binaries onto
  another's base.

## Commits and PRs

- Conventional commits: `type(scope): summary`
  (`feat`, `fix`, `docs`, `refactor`, `chore`; scopes like `enux`, `layer`,
  `pmm`, `iso`).
- Describe *why*, not just *what*.
- Note how you tested (which distro layers, chroot vs. booted ISO).

## License

By contributing you agree your work is licensed under GPL-3.0, the
project's license.
