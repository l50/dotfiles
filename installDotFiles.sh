#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# installDotFiles.sh
#
# Install dot files
#
# Usage: bash installDotFiles.sh
#
# Jayson Grace, jayson.e.grace@gmail.com, 2/9/2017
#
# Last update 8/3/2017 by Jayson Grace, jayson.e.grace@gmail.com
# ----------------------------------------------------------------------------

# Stop execution of script if an error occurs
set -e

dotdir="$HOME/.dotfiles"
oldDotDir="${dotdir}.old"
installDir=$(pwd)
declare -a files=("bashutils" "docker" "osx" "aws" "python")

##### (Cosmetic) Color output
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

# Used by the docker msfconsole and msfvenom containers
install_metasploit()
{
  # Make sure it's not already there
  if [ ! -d "$HOME/metasploit-framework" ]; then
    echo -e "${BLUE}Installing metasploit, please wait...${RESET}"
    git clone git://github.com/rapid7/metasploit-framework.git $HOME/metasploit-framework
  fi
}

# Creates sqlmap folder if it doesn't already exist
sqlmapFolder()
{
  if [ ! -d "$HOME/.sqlmap" ]; then
    echo -e "${BLUE}Creating sqlmap folder at $HOME/.sqlmap, please wait...${RESET}"
    mkdir $HOME/.sqlmap
  fi
}

# Docker projects which require docker-compose
cloneDockerProjects()
{
  targetDir="${dotdir}/files/docker"

  # hackmd for collaborative md editing
  git clone git://github.com/hackmdio/docker-hackmd.git $targetDir/docker-hackmd
}

# Backup old zshrc (if one exists)
if [ -f ~/.zshrc ]; then
    echo -e "${YELLOW}Backup up old zshrc, please wait...${RESET}"
  mv $HOME/.zshrc $HOME/.zshrc.old
fi

# If old dotfiles exist, back them up
if [ -d $dotdir ]; then
  # If really old dotfiles exist, nuke them
  if [ -d $oldDotDir ]
  then
    echo -e "${BOLD}Nuking old dotfile backups. Nothing is sacred.${RESET}"
    rm -rf $oldDotDir
  fi
  mv $dotdir $oldDotDir
  rm -rf $dotdir
fi

# create dotfiles directory in homedir
mkdir -p $dotdir

# Move zshrc in place
cp ./zshrc ~/.zshrc

# Move tmux config into place
cp ./tmux.conf $HOME/.tmux.conf

# Put dotfiles in their place in the dotdir
for file in "${files[@]}"
do
  cp $file $dotdir
done

echo $installDir >> $dotdir/.dotinstalldir

# If we're not on kali, install metasploit to the user's home directory
if [[ ! -d "/usr/share/metasploit-framework" ]]; then
  install_metasploit
fi

sqlmapFolder

# move files into place
cp -r $installDir/files $dotdir/files

# If janus is installed, move our .vimrc.after into place
if [[ -d $HOME/.vim/janus ]]; then
    cp $dotdir/files/.vimrc.after $HOME/.vimrc.after
fi

# Move .gitconfig into place
cp $dotdir/files/.gitconfig $HOME/.gitconfig

cloneDockerProjects
