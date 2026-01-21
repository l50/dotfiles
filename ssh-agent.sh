#!/usr/bin/env bash

# Set up SSH_AUTH_SOCK, preferring 1Password's SSH agent when available.
#
# If running locally (not over SSH) and the 1Password CLI/config is present,
# it sets SSH_AUTH_SOCK to the OS-specific 1Password agent socket. If an
# existing SSH_AUTH_SOCK points to a live socket, it keeps it. Otherwise, it
# starts ssh-agent and exports the socket.
#
# Usage:
#   setup_ssh_agent
#
# Output:
#   None. Exports SSH_AUTH_SOCK and may start ssh-agent.
#
# Example(s):
#   setup_ssh_agent
setup_ssh_agent() {
    local op_sock=""

    if [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]]; then
        return 0
    fi

    if command -v op &> /dev/null; then
        if [[ -f "${HOME}/.config/op/config" || -f "${HOME}/.config/op/config.json" ]]; then
            case "$(uname -s)" in
                Darwin)
                    op_sock="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
                    ;;
                Linux)
                    op_sock="${HOME}/.1password/agent.sock"
                    ;;
            esac
        fi
    fi

    if [[ -n "$op_sock" && -S "$op_sock" ]]; then
        export SSH_AUTH_SOCK="$op_sock"
        return 0
    fi

    if [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK}" ]]; then
        return 0
    fi

    if command -v ssh-agent &> /dev/null; then
        eval "$(ssh-agent -s)" > /dev/null
    fi
}

setup_ssh_agent
