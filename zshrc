# PATH setup
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:$HOME/.local/bin

# oh-my-zsh components
export ZSH="${HOME}/.oh-my-zsh"
export ZSH_THEME="af-magic"
source "${ZSH}/oh-my-zsh.sh"
export plugins=(asdf aws git docker helm kubectl zsh-completions)

# Source other dotfiles
for file in "${HOME}/.dotfiles"/*; do
  if [[ -f "${file}" && -r "${file}" ]]; then
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

# Set default editor to vim
export EDITOR='vim'

# Add the dot-update command
if [[ -f "${HOME}/.dotfiles/.dotinstalldir" ]]; then
  alias dot-update="(cd \$(cat \"\${HOME}\"/.dotfiles/.dotinstalldir) \
    && git pull origin main &> /dev/null && bash install_dot_files.sh)"
fi

# Remove the % from the end of terminal output
export PROMPT_EOL_MARK=''
export ASDF_PATH="/Users/l/.asdf"
export PATH="$ASDF_PATH/bin:$ASDF_PATH/shims:$PATH"
. "$ASDF_PATH/asdf.sh"
