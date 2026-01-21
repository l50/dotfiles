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

# Updates and cleans the Kali package system.
#
# Usage:
#   update_kali
#
# Output:
#   Runs apt-get update/full-upgrade/autoremove/clean.
#
# Example(s):
#   update_kali
update_kali() {
    apt-get update
    apt-get full-upgrade -y
    apt-get autoremove -y
    apt-get clean -y
}

# Installs the base Kali packages for the container.
#
# Usage:
#   install_packages
#
# Output:
#   Installs exploitdb, kali-linux-default, man-db, and vim.
#
# Example(s):
#   install_packages
install_packages() {
    apt-get install -y exploitdb \
        kali-linux-default \
        man-db \
        vim
}

update_kali
install_packages
