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
# Last update 2/9/2017 by Jayson Grace, jayson.e.grace@gmail.com
# ----------------------------------------------------------------------------

dotdir=~/.dotfiles
oldDotDir="${dotdir}.old"
declare -a files=("bashutils" "docker" "osx")

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
