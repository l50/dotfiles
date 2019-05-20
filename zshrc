# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="norm"

plugins=(git docker docker-compose nmap tmux)

# User configuration
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin:/usr/local/git/bin:/usr/local/sbin:/Users/l/.rvm/bin:/usr/local/packer

source $ZSH/oh-my-zsh.sh

# Added from ~/.bash_profile
export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

[[ -s "$HOME/.profile" ]] && source "$HOME/.profile" # Load the default .profile

# Used for brew to specify the path Brew uses before the path for the default system packages
export PATH="/usr/local/bin:$PATH"

alias sd='cd /Volumes/SD && ls'

# Set gopath
export GOPATH=$HOME/programs/go
# Set bin directory for go executables
export GOBIN=$HOME/programs/go/bin
# Add go to PATH - so we can run executables from anywhere
export PATH=$PATH:$GOPATH/bin

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

export PATH=$PATH:$HOME/.pyenv/bin
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# If thefuck is installed, use it
if hash thefuck 2>/dev/null; then
  eval $(thefuck --alias)
fi

# mvim stuff
alias mvim="/Applications/MacVim.app/contents/MacOS/MacVim"
# Fix set paste formatting issues - http://superuser.com/questions/437730/always-use-set-paste-is-it-a-good-idea
#alias vim='gvim -v'

# Enable mouse use in all modes for vim
set mouse=a

source ~/.dotfiles/docker
source ~/.dotfiles/bashutils
source ~/.dotfiles/aws
source ~/.dotfiles/python
if [[ `uname` == 'Darwin' ]]; then
  source ~/.dotfiles/osx
  # Set GOROOT installed with brew
  export GOROOT="$(brew --prefix golang)/libexec"
  # Add GOROOT to PATH
  export PATH="$PATH:${GOROOT}/bin"
fi

# For work specific configurations
if [ -f $HOME/.work ]; then
  source ~/.work
fi

export EDITOR='vim'

if [[ -f $HOME/.dotfiles/.dotinstalldir ]]; then
  alias dot-update="(cd $(cat ~/.dotfiles/.dotinstalldir) && git pull origin master &> /dev/null && bash installDotFiles.sh)"
fi
