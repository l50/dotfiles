#!/bin/bash
# -----------------------------------------------------------------------------
# installDotFiles.sh
#
# Install dot files
#
# Usage: bash installDotFiles.sh
#
# Jayson Grace, jayson.e.grace@gmail.com, 2/9/2017
#
# Last update 4/3/2017 by Jayson Grace, jayson.e.grace@gmail.com
# ----------------------------------------------------------------------------

dotdir=~/.dotfiles
oldDotDir="${dotdir}.old"
installDir=$(pwd)
declare -a files=("bashutils" "docker" "osx" "aws" "python")

# Used by the docker msfconsole and msfvenom containers
installMetasploit(){
    if [ ! -d "$HOME/metasploit-framework" ]; then
        git clone git://github.com/rapid7/metasploit-framework.git $HOME/metasploit-framework
    fi
}

# Backup old zshrc (if one exists)
if [ -f ~/.zshrc ]
then
  mv ~/.zshrc ~/.zshrc.old
fi

# If old dotfiles exist, back them up
if [ -d $dotdir ]
then
  # If really old dotfiles exist, nuke them
  if [ -d $oldDotDir ]
  then
    echo "NUKE!"
    rm -rf $oldDotDir
  fi
  mv $dotdir $oldDotDir
  rm -rf $dotdir
fi

# create dotfiles directory in homedir
mkdir -p $dotdir

# Move zshrc in place
cp ./zshrc ~/.zshrc

# Put dotfiles in their place in the dotdir
for file in "${files[@]}"
do
  cp $file $dotdir
done

echo $installDir >> $dotdir/.dotinstalldir

installMetasploit
