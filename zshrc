# Prevent duplicate entries in the PATH
typeset -U PATH path

# PATH setup
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin

# oh-my-zsh components
export ZSH="${HOME}/.oh-my-zsh"
export ZSH_THEME="af-magic"
export plugins=(asdf aws git docker kubectl zsh-completions)

# Enable zsh completion system
autoload -U compinit && compinit


# shellcheck source=/dev/null
source "${ZSH}/oh-my-zsh.sh"

# Source other dotfiles
source_dotfiles() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        # Only source files in the root dotfiles directory, excluding the files/ directory
        while IFS= read -r -d '' script; do
            if [[ -f "$script" && -r "$script" && ! "$script" =~ /files/ ]]; then
                # shellcheck source=/dev/null
                source "$script"
            fi
        done < <(find "$dir" -type f \( -name "*.sh" -o -name "*.zsh" \) -print0)
    fi
}

# Add Android SDK to PATH if it exists
if [[ -d "$HOME/Library/Android/sdk/platform-tools" ]]; then
    export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
fi

# Source all dotfiles
source_dotfiles "${HOME}/.dotfiles"

# # Mac OS specific dotfile
# if [[ "$(uname)" == 'Darwin' ]]; then
#   # shellcheck source=/dev/null
#   source "${HOME}/.dotfiles/macos.sh"
# fi

# Work specific configurations
if [ -f "${HOME}/.work" ]; then
  # shellcheck source=/dev/null
  source "${HOME}/.work"
fi

# Set default editor to vscode
export EDITOR='code --wait'

# Add the dot-update command
if [[ -f "${HOME}/.dotfiles/.dotinstalldir" ]]; then
  alias dot-update="(cd \$(cat \"\${HOME}\"/.dotfiles/.dotinstalldir) \
    && git pull origin main &> /dev/null && bash install_dot_files.sh)"
fi

### ZSH autocomplete ###
# Install zsh-completions if it doesn't exist
if [[ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-completions" ]]; then
  git clone https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}"/plugins/zsh-completions
fi

# Add zsh-completions to the fpath
fpath+=${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/zsh-completions/src

# Remove the % from the end of terminal output
export PROMPT_EOL_MARK=''
