# Prevent duplicate entries in the PATH
typeset -U PATH path

# PATH setup
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin

# oh-my-zsh components
export ZSH="${HOME}/.oh-my-zsh"
export ZSH_THEME="af-magic"
export plugins=(asdf aws git docker helm kubectl zsh-completions)

# shellcheck source=/dev/null
source "${ZSH}/oh-my-zsh.sh"

# Source other dotfiles
for file in "${HOME}/.dotfiles"/*; do
  if [[ -d "${file}" ]]; then
    # If it's a directory, source all files inside it
    for subfile in "${file}"/*; do
      if [[ -f "${subfile}" && -r "${subfile}" ]]; then
        # shellcheck source=/dev/null
        source "${subfile}"
      fi
    done
  elif [[ -f "${file}" && -r "${file}" ]]; then
    # If it's a file, source it directly
    # shellcheck source=/dev/null
    source "${file}"
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
