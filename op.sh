#!/usr/bin/env bash

# 1Password CLI completions (zsh only)
if [[ -n "$ZSH_VERSION" ]] && command -v op &> /dev/null; then
    eval "$(op completion zsh)"
fi

# 1Password shell plugins (biometric auth for CLIs like gh, aws)
# Initialize new plugins with: op plugin init <tool>
[[ -f "$HOME/.config/op/plugins.sh" ]] && source "$HOME/.config/op/plugins.sh"

# Quick secret read
# Usage: opsecret "Private/Database/password"
opsecret() {
    op read "op://$1"
}

# Copy a 1Password secret to clipboard
# Usage: opcp "Private/Database/password"
opcp() {
    op read "op://$1" | pbcopy && echo "Copied to clipboard."
}

# Run a command with secrets injected from an env file
# Usage: oprun .env.dev ./start-server
oprun() {
    op run --env-file "${1:-.env}" -- "${@:2}"
}
