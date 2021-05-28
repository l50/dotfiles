# PATH setup
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin

# oh-my-zsh components
export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="af-magic"
source $ZSH/oh-my-zsh.sh

plugins=(
  # auto-completion for docker
  docker
  # bunch of great nmap aliases -> https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/nmap
  nmap
)

# Other dotfiles
source $HOME/.dotfiles/android
source $HOME/.dotfiles/aws
source $HOME/.dotfiles/bashutils
source $HOME/.dotfiles/containers
source $HOME/.dotfiles/go
source $HOME/.dotfiles/python

# Mac OS specific dotfile
if [[ `uname` == 'Darwin' ]]; then
  source $HOME/.dotfiles/macos
fi

# Work specific configurations
if [ -f $HOME/.work ]; then
  source $HOME/.work
fi

# Set default editor to vim
export EDITOR='vim'

# Add the dot-update command
if [[ -f $HOME/.dotfiles/.dotinstalldir ]]; then
  alias dot-update="(cd $(cat $HOME/.dotfiles/.dotinstalldir) && git pull origin master &> /dev/null && bash installDotFiles.sh)"
fi

# Remove the % from the end of terminal output 
export PROMPT_EOL_MARK=''
