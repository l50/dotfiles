# PATH setup
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin

# oh-my-zsh components
export ZSH="${HOME}/.oh-my-zsh"
export ZSH_THEME="af-magic"
source "${ZSH}/oh-my-zsh.sh"
export plugins=(asdf aws git docker helm kubectl zsh-completions)

export ASDF_PATH="$HOME/.asdf"
export PATH="$ASDF_PATH/bin:$ASDF_PATH/shims:$PATH"
. "$ASDF_PATH/asdf.sh"

# Source other dotfiles
for file in "${HOME}/.dotfiles"/*; do
  if [[ -f "${file}" && -r "${file}" ]]; then
    # shellcheck source=/dev/null
    source "${file}"
  fi
done

# Source cloud dotfiles
for provider in "${HOME}/.dotfiles/cloud"/*; do
  if [[ -d "${provider}" ]]; then
    for file in "${provider}"/*; do
      if [[ -f "${file}" && -r "${file}" ]]; then
        # shellcheck source=/dev/null
        source "${file}"
      fi
      if [[ -d "${file}" ]]; then
        for script in "${file}"/*; do
          if [[ -f "${script}" && -r "${script}" ]]; then
            # shellcheck source=/dev/null
            source "${script}"
          fi
        done
      fi
    done
  fi
done

# Mac OS specific dotfile
if [[ "$(uname)" == 'Darwin' ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.dotfiles/macos"
fi

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