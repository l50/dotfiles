#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_dot_files.sh
#
# Install dot files and configure workstation using Ansible
#
# Usage: bash install_dot_files.sh [--skip-ansible]
#
# Jayson Grace <jayson.e.grace at gmail.com>
# -----------------------------------------------------------------------------
# Stop execution of script if an error occurs
set -eou pipefail

# Parse command line arguments
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

DOT_DIR="${HOME}/.dotfiles"
OLD_DOT_DIR="${DOT_DIR}.old"
INSTALL_DIR="$(pwd)"
ANSIBLE_DIR="$HOME/cowdogmoo/ansible-collection-workstation"

declare -a files=(
    'android.sh'
    'bashutils.sh'
    'common.sh'
    'config'
    'containers.sh'
    'docker.sh'
    'git.sh'
    'go.sh'
    'k8s.sh'
    'python.sh'
    'macos.sh'
    'terraform.sh'
    'ssh-agent.sh'
    'cloud'
)

##### Color output
BLUE="\033[01;34m"
RESET="\033[00m"
YELLOW="\033[01;33m"

# Identify OS type
OS_TYPE="$(uname)"

# Creates a launchd job to update the dotfiles every day at 10AM
setup_auto_update() {
    file_name='dotfile-update'
    launchd_path="${HOME}/Library/LaunchAgents"
    plist_name="net.techvomit.$(whoami).${file_name}"

    # Only run this if we haven't already created the job
    if [[ ! -f "${launchd_path}/${plist_name}.plist" ]]; then
        working_dir=$(cat "${DOT_DIR}/.dotinstalldir")
        plist_command="install_dot_files.sh"

        cp "templates/${file_name}.tmpl" "${launchd_path}/${plist_name}.plist"

        sed -i '' "s|WORKINGDIR|${working_dir}|" "${launchd_path}/${plist_name}.plist"
        sed -i '' "s|DOTUPDATECOMMAND|${plist_command}|" "${launchd_path}/${plist_name}.plist"

        launchctl load "${launchd_path}/${plist_name}.plist"
    fi
}

# Sets up the Ansible workstation environment and runs the playbook.
#
# Usage:
#   setup_ansible
#
# Output:
#   Clones the workstation repo, installs collections, and runs the playbook.
#
# Example(s):
#   setup_ansible
setup_ansible() {
    echo "Setting up Ansible environment..."

    # Ensure Ansible is installed
    if ! command -v ansible-galaxy &> /dev/null; then
        echo "Ansible is not installed. Please install it first."
        exit 1
    fi

    # Clone ansible-collection-workstation if not present
    if [[ ! -d "${ANSIBLE_DIR}" ]]; then
        echo -e "${YELLOW}Cloning ansible workstation repo...${RESET}"
        mkdir -p "$(dirname "${ANSIBLE_DIR}")"
        git clone https://github.com/CowDogMoo/ansible-collection-workstation.git "${ANSIBLE_DIR}"
    fi

    # Install required Ansible collections
    if command -v ansible-galaxy &> /dev/null; then
        if ! ansible-galaxy collection list | grep -q "cowdogmoo.workstation"; then
            echo "Installing CowDogMoo workstation collection..."
            ansible-galaxy collection install git+https://github.com/CowDogMoo/ansible-collection-workstation.git,main
        fi
    fi

    # Create dynamic inventory with actual hostname
    local hostname
    hostname=$(hostname -s)
    local inventory_file="${ANSIBLE_DIR}/playbooks/workstation/inventory"
    cat > "${inventory_file}" << EOF
[workstation]
${hostname} ansible_connection=local
EOF

    # Run the workstation playbook
    ansible-playbook "${ANSIBLE_DIR}/playbooks/workstation/workstation.yml" \
        -i "${inventory_file}"
}

### MAIN ###
# Update from git if we're in a repo and not in CI
if [[ -z "${CI:-}" ]] && git rev-parse --git-dir > /dev/null 2>&1; then
    if ! git pull origin main &> /dev/null; then
        echo "Failed to pull latest changes"
    fi
fi

# Backup existing configurations
if [[ -f "${HOME}/.zshrc" ]]; then
    echo -e "${YELLOW}Backing up existing zshrc...${RESET}"
    mv "${HOME}/.zshrc" "${HOME}/.zshrc.old"
fi

if [[ -d "${DOT_DIR}" ]]; then
    [[ -d "${OLD_DOT_DIR}" ]] && rm -rf "${OLD_DOT_DIR}"
    mv "${DOT_DIR}" "${OLD_DOT_DIR}"
fi

# Create and populate dotfiles directory
mkdir -p "${DOT_DIR}"

# Copy base configuration files
# Only copy if source and destination are different
if [[ ! -f "${HOME}/.zshrc" ]] || ! cmp -s ./zshrc "${HOME}/.zshrc"; then
    cp ./zshrc "${HOME}/.zshrc"
fi

if [[ ! -f "${HOME}/.tmux.conf" ]] || ! cmp -s ./tmux.conf "${HOME}/.tmux.conf"; then
    cp ./tmux.conf "${HOME}/.tmux.conf"
fi

# Copy dotfiles
for file in "${files[@]}"; do
    case "$file" in
        "cloud")
            mkdir -p "${DOT_DIR}/cloud"
            cp -r "${file}"/* "${DOT_DIR}/cloud"
            ;;
        "config")
            mkdir -p "${DOT_DIR}/config"
            cp -r "${file}"/* "${DOT_DIR}/config"
            ;;
        *)
            cp "${file}" "${DOT_DIR}"
            ;;
    esac
done

echo "${INSTALL_DIR}" > "${DOT_DIR}/.dotinstalldir"

# Copy additional files
cp -r "${INSTALL_DIR}/files" "${DOT_DIR}/files"
cp "${DOT_DIR}/files/.gitconfig" "${HOME}/.gitconfig"
echo -e "${YELLOW}Remember to configure ${HOME}/.gitconfig.userparams${RESET}"

# macOS specific setup
if [[ "$OS_TYPE" == 'Darwin' ]]; then
    setup_auto_update
fi

# Only run Ansible setup if RUN_ANSIBLE is true. The workstation playbook owns
# ~/.ansible.cfg, ~/.ansible/* state dirs, oh-my-zsh, the Brewfile, and the
# mise default-package list files — they used to be created here.
if [[ "${RUN_ANSIBLE}" == true ]]; then
    echo -e "${BLUE}Running Ansible setup...${RESET}"
    setup_ansible
else
    echo -e "${YELLOW}Skipping Ansible setup (--skip-ansible flag was used)${RESET}"
fi

echo -e "${BLUE}Dotfiles installation complete!${RESET}"
