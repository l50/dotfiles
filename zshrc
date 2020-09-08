# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="norm"

plugins=(git docker docker-compose nmap tmux)

# User configuration
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin:/usr/local/git/bin:/usr/local/sbin:/usr/local/packer

source $ZSH/oh-my-zsh.sh

[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

alias sd='cd /Volumes/SD && ls'

# Enable mouse use in all modes for vim
set mouse=a

source ~/.dotfiles/docker
source ~/.dotfiles/bashutils
source ~/.dotfiles/aws
source ~/.dotfiles/python
source ~/.dotfiles/android
if [[ `uname` == 'Darwin' ]]; then
  source ~/.dotfiles/osx
  # Used for brew to specify the path Brew uses before the path for the default system packages
  export PATH="/usr/local/bin:$PATH"
  export GOPATH=$HOME/programs/go
  export GOROOT=/usr/local/opt/go/libexec
  # Add go to PATH - so we can run executables from anywhere
  export PATH=$PATH:$GOPATH/bin
  export PATH=$PATH:$GOROOT/bin
  # Set bin directory for go executables
  export GOBIN=$HOME/programs/go/bin
fi

# For work specific configurations
if [ -f $HOME/.work ]; then
  source ~/.work
fi

export EDITOR='vim'

if [[ -f $HOME/.dotfiles/.dotinstalldir ]]; then
  alias dot-update="(cd $(cat ~/.dotfiles/.dotinstalldir) && git pull origin master &> /dev/null && bash installDotFiles.sh)"
fi

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
