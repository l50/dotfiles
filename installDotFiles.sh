#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# installDotFiles.sh
#
# Install dot files
#
# Usage: bash installDotFiles.sh
#
# Jayson Grace, jayson.e.grace@gmail.com
# ----------------------------------------------------------------------------
# Stop execution of script if an error occurs
set -e

DOT_DIR="$HOME/.dotfiles"
OLD_DOT_DIR="${DOT_DIR}.old"
INSTALL_DIR=$(pwd)
declare -a files=(
  "android"
  "aws"
  "bashutils"
  "containers"
  "go"
  "python"
  "macos"
)

##### (Cosmetic) Color output
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

# Creates sqlmap folder if it doesn't already exist
sqlmap_folder() {
  if [ ! -d "$HOME/.sqlmap" ]; then
    echo -e "${BLUE}Creating sqlmap folder at $HOME/.sqlmap, please wait...${RESET}"
    mkdir $HOME/.sqlmap
  fi
}

# Creates kali folder if it doesn't already exist
kali_folder() {
  if [ ! -d "$HOME/.kali" ]; then
    echo -e "${BLUE}Creating kali folder at $HOME/.kali, please wait...${RESET}"
    mkdir $HOME/.kali
  fi
}

# Creates android security tools folder if it doesn't already exist
android_sec_tools_folder() {
  if [ ! -d "$HOME/.android_sec_tools" ]; then
    echo -e "${BLUE}Creating android_sec_tools folder at $HOME/.android_sec_tools, please wait...${RESET}"
    mkdir $HOME/.android_sec_tools
  fi
}

# Creates a launchd job to update the dotfiles every day at 10AM
setup_auto_update() {
  if [[ `uname` == 'Darwin' ]]; then
    file_name='dotfile-update'
    launchd_path="${HOME}/Library/LaunchAgents"
    plist_name="net.techvomit.$(whoami).${file_name}"

    # Only run this if we haven't already created the job
    if [[ ! -f "${launchd_path}/${plist_name}.plist" ]]; then 
      # vars to populate template
      working_dir=$(cat "${DOT_DIR}/.dotinstalldir")
      plist_command="installDotFiles.sh"

      cp templates/${file_name}.tmpl "${launchd_path}/${plist_name}.plist"

      # WORKINGDIR
      sed -i '' "s|WORKINGDIR|${working_dir}|" "${launchd_path}/${plist_name}.plist"

      # DOTUPDATECOMMAND
      sed -i '' "s|DOTUPDATECOMMAND|${plist_command}|" "${launchd_path}/${plist_name}.plist"

      # Enable it
      launchctl load "${launchd_path}/${plist_name}.plist"
    fi
  fi
}

### MAIN ###
# Start by getting the latest and greatest
git pull origin master &> /dev/null

# Backup old zshrc (if one exists)
if [[ -f $HOME/.zshrc ]]; then
  echo -e "${YELLOW}Backup up old zshrc, please wait...${RESET}"
  mv $HOME/.zshrc $HOME/.zshrc.old
fi

# If old dotfiles exist, back them up
if [ -d $DOT_DIR ]; then
  # If really old dotfiles exist, nuke them
  if [ -d $OLD_DOT_DIR ]
  then
    echo -e "${BOLD}Nuking old dotfile backups. Nothing is sacred.${RESET}"
    rm -rf $OLD_DOT_DIR
  fi
  mv $DOT_DIR $OLD_DOT_DIR
  rm -rf $DOT_DIR
fi

# create dotfiles directory in homedir
mkdir -p $DOT_DIR

# Move zshrc in place
cp ./zshrc $HOME/.zshrc

# Move tmux config into place
cp ./tmux.conf $HOME/.tmux.conf

# Put dotfiles in their place in the DOT_DIR
for file in "${files[@]}"
do
  cp $file $DOT_DIR
done

echo $INSTALL_DIR >> $DOT_DIR/.dotinstalldir

sqlmap_folder
kali_folder
android_sec_tools_folder

# move files into place
cp -r $INSTALL_DIR/files $DOT_DIR/files

# Move .gitconfig into place
cp $DOT_DIR/files/.gitconfig $HOME/.gitconfig
echo -e "${YELLOW}Be sure to populate $HOME/.gitconfig/userparams!${RESET}"

setup_auto_update
