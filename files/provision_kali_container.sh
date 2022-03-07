#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# provision_kali_container.sh
#
# Provision Kali Container
#
# Usage: bash provision_kali_container.sh
#
# Jayson Grace, jayson.e.grace@gmail.com
# ----------------------------------------------------------------------------
# Stop execution of script if an error occurs
set -e

update_kali() {
	apt-get update
	apt-get full-upgrade -y
	apt-get autoremove -y
	apt-get clean -y
}

install_packages() {
	apt-get install -y exploitdb \
		kali-linux-default \
		man-db \
		vim
}

update_kali
install_packages
