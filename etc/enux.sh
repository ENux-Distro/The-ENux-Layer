# The ENux Layer - shell profile snippet.
#
# 1. Puts the cross-command directory on PATH so other layers' programs are
#    runnable by name (each runs inside its own layer via layer-chroot).
#    Appended, not prepended: the base system's own commands keep priority.
#
# 2. Wraps sudo and every package manager in shell functions so that after
#    any install/remove/upgrade the shell's hash table is automatically cleared.
#    Without this, bash caches "not found" for newly installed cross commands
#    and the user would need to re-login before using them.

if [ -d /enux/cross/bin ]; then
    case ":$PATH:" in
        *:/enux/cross/bin:*) ;;
        *) PATH="$PATH:/enux/cross/bin" ;;
    esac
    export PATH
fi

# sudo wrapper: clear the hash table after every sudo call.
# This is the critical case: aliases are not expanded under sudo, so
# `sudo apt install foo` would bypass the PM aliases below entirely.
# Wrapping sudo itself ensures hash -r runs for ALL privileged commands,
# which is correct - any sudo call can add or remove commands on the system.
sudo() {
    command sudo "$@"
    _enux_rc=$?
    hash -r 2>/dev/null || true
    return "$_enux_rc"
}

# PM aliases for unprivileged ops (apt search, dnf info, etc.) and for shells
# where the user runs a PM without sudo (will fail with permission denied, but
# hash -r is still correct to run after any PM invocation).
_enux_pm() {
    _enux_pm_cmd="$1"; shift
    "/enux/cross/bin/$_enux_pm_cmd" "$@"
    _enux_pm_rc=$?
    hash -r 2>/dev/null || true
    return "$_enux_pm_rc"
}

for _enux_p in apt apt-get aptitude dpkg \
               dnf dnf5 yum microdnf rpm \
               pacman \
               apk \
               xbps-install xbps-remove xbps-query \
               zypper \
               emerge; do
    # shellcheck disable=SC2139
    alias "$_enux_p"="_enux_pm $_enux_p"
done
unset _enux_p
