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
# Last update 10/20/2020 by Jayson Grace, jayson.e.grace@gmail.com
# ----------------------------------------------------------------------------

# Stop execution of script if an error occurs
set -e

dotdir="$HOME/.dotfiles"
oldDotDir="${dotdir}.old"
installDir=$(pwd)
declare -a files=("bashutils" "containers" "osx" "aws" "python" "android")

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
sqlmap_folder()
{
  if [ ! -d "$HOME/.sqlmap" ]; then
    echo -e "${BLUE}Creating sqlmap folder at $HOME/.sqlmap, please wait...${RESET}"
    mkdir $HOME/.sqlmap
  fi
}

# Creates kali folder if it doesn't already exist
kali_folder()
{
  if [ ! -d "$HOME/.kali" ]; then
    echo -e "${BLUE}Creating kali folder at $HOME/.kali, please wait...${RESET}"
    mkdir $HOME/.kali
  fi
}

# Creates android security tools folder if it doesn't already exist
android_sec_tools_folder()
{
  if [ ! -d "$HOME/.android_sec_tools" ]; then
    echo -e "${BLUE}Creating android_sec_tools folder at $HOME/.android_sec_tools, please wait...${RESET}"
    mkdir $HOME/.android_sec_tools
  fi
}

### MAIN ###

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
#if [[ ! -d "/usr/share/metasploit-framework" ]]; then
#  install_metasploit
#fi

sqlmap_folder
kali_folder
android_sec_tools_folder

# move files into place
cp -r $installDir/files $dotdir/files

# Move .gitconfig into place
cp $dotdir/files/.gitconfig $HOME/.gitconfig
echo -e "${YELLOW}Be sure to populate ~/.gitconfig/userparams!${RESET}"
