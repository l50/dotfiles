update_kali(){
  apt-get update
  apt-get full-upgrade -y
  apt-get autoremove -y
  apt-get clean -y
}

install_packages(){
  apt-get install -y exploitdb \
    kali-linux-default \
    man-db \
    vim
}

update_kali
install_packages
