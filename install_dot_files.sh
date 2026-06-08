#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_dot_files.sh
#
# Bootstraps the workstation by cloning ansible-collection-workstation and
# running its workstation playbook against this host. The ansible roles own
# ~/.zshrc, ~/.tmux.conf, ~/.gitconfig, ~/.ansible.cfg, the vault-pass helper,
# and the deployment of shell-function libraries into ~/.dotfiles.
#
# Usage: bash install_dot_files.sh [--skip-ansible]
#
# Jayson Grace <jayson.e.grace at gmail.com>
# -----------------------------------------------------------------------------
set -eou pipefail

RUN_ANSIBLE=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-ansible)
            RUN_ANSIBLE=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-ansible]"
            exit 1
            ;;
    esac
done

INSTALL_DIR="$(pwd)"
ANSIBLE_DIR="$HOME/cowdogmoo/ansible-collection-workstation"

BLUE="\033[01;34m"
RESET="\033[00m"
YELLOW="\033[01;33m"

# Sets up the Ansible workstation environment and runs the playbook.
setup_ansible() {
    echo "Setting up Ansible environment..."

    if ! command -v ansible-galaxy &> /dev/null; then
        echo "Ansible is not installed. Please install it first."
        exit 1
    fi

    if [[ ! -d "${ANSIBLE_DIR}" ]]; then
        echo -e "${YELLOW}Cloning ansible workstation repo...${RESET}"
        mkdir -p "$(dirname "${ANSIBLE_DIR}")"
        git clone https://github.com/CowDogMoo/ansible-collection-workstation.git "${ANSIBLE_DIR}"
    fi

    if ! ansible-galaxy collection list 2> /dev/null | grep -q "cowdogmoo.workstation"; then
        echo "Installing CowDogMoo workstation collection..."
        ansible-galaxy collection install git+https://github.com/CowDogMoo/ansible-collection-workstation.git,main
    fi

    local hostname
    hostname=$(hostname -s)
    local inventory_file="${ANSIBLE_DIR}/playbooks/workstation/inventory"
    cat > "${inventory_file}" << EOF
[workstation]
${hostname} ansible_connection=local
EOF

    ansible-playbook "${ANSIBLE_DIR}/playbooks/workstation/workstation.yml" \
        -i "${inventory_file}" \
        -e "shell_functions_source_path=${INSTALL_DIR}"
}

### MAIN ###
if [[ -z "${CI:-}" ]] && git rev-parse --git-dir > /dev/null 2>&1; then
    if ! git pull origin main &> /dev/null; then
        echo "Failed to pull latest changes"
    fi
fi

if [[ "${RUN_ANSIBLE}" == true ]]; then
    echo -e "${BLUE}Running Ansible setup...${RESET}"
    setup_ansible
else
    echo -e "${YELLOW}Skipping Ansible setup (--skip-ansible flag was used)${RESET}"
fi

echo -e "${BLUE}Dotfiles installation complete!${RESET}"
