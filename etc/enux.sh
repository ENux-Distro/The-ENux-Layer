# The ENux Layer - shell profile snippet.
#
# Put the cross-command directory on PATH so other layers' programs are
# runnable by name (each runs inside its own layer). Appended, not
# prepended, so the base system's own commands keep priority; cross only
# fills in commands the base does not have.
#
# Install: symlink or copy to /etc/profile.d/enux.sh

if [ -d /enux/cross/bin ]; then
    case ":$PATH:" in
        *:/enux/cross/bin:*) ;;
        *) PATH="$PATH:/enux/cross/bin" ;;
    esac
    export PATH
fi
