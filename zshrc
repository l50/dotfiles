# Path to your oh-my-zsh installation.
export ZSH=/Users/l/.oh-my-zsh

ZSH_THEME="norm"

plugins=(git docker docker-compose nmap)
# User configuration
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin:/usr/local/git/bin:/Users/l/.rvm/bin:/usr/local/packer:/Applications/Racket\ v6.3/bin/

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

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Only for OSX
#alias emacs='/Applications/Emacs.app/Contents/MacOS/Emacs'

eval $(thefuck --alias)

# mvim stuff
alias mvim="/Applications/MacVim.app/contents/MacOS/MacVim"
# Fix set paste formatting issues - http://superuser.com/questions/437730/always-use-set-paste-is-it-a-good-idea
alias vim='gvim -v'
set mouse=a

# Haskell
export PATH="$HOME/Library/Haskell/bin:$PATH"

source ~/.sensitive
source ~/.dotfiles/docker
source ~/.dotfiles/bashutils
if [[ `uname` == 'Darwin' ]]
then
  source ~/.dotfiles/osx
fi
