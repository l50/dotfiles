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
GREEN="\033[01;32m"
BLUE="\033[01;34m"
RESET="\033[00m"
YELLOW="\033[01;33m"

# Identify OS type
OS_TYPE="$(uname)"

# Create necessary directories
create_directories() {
    local dirs=(
        "${HOME}/.sqlmap"
        "${HOME}/.kali"
        "${HOME}/.android_sec_tools"
        "${HOME}/ansible-logs"
        "${HOME}/ansible-logs/hosts"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${BLUE}Creating directory at ${dir}, please wait...${RESET}"
            mkdir -p "$dir"
        fi
    done
}

# Adds a cron job to update dotfiles every day at 6PM
add_cron_job() {
    # Add the cron job if it doesn't already exist
    # This will prevent duplicate entries if the script is run multiple times
    crontab -l 2> /dev/null | grep -q "$(basename "$0")" || echo "0 18 * * * ${INSTALL_DIR}/$(basename "$0")" | crontab -
}

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

# Downloads and installs Brewfile to $HOME/.brewfile/Brewfile (macOS only)
setup_brewfile() {
    if [[ "$OS_TYPE" != 'Darwin' ]]; then
        return
    fi

    brewfile_path="${HOME}/.config/brewfile"
    brewfile_dl='https://raw.githubusercontent.com/l50/homebrew-brewfile/main/Brewfile'

    mkdir -p "${brewfile_path}"
    echo -e "${YELLOW}Downloading latest Brewfile...${RESET}"
    wget -q "${brewfile_dl}" -O "${brewfile_path}/Brewfile"
}

# Installs oh-my-zsh if it isn't already installed.
#
# Usage:
#   install_oh_my_zsh
#
# Output:
#   Prints status messages and installs oh-my-zsh if missing.
#
# Example(s):
#   install_oh_my_zsh
install_oh_my_zsh() {
    if [ ! -d "${HOME}/.oh-my-zsh" ]; then
        echo -e "${BLUE}Installing oh-my-zsh...${RESET}"
        KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
}

# Creates the local Ansible configuration and supporting directories.
#
# Usage:
#   setup_ansible_config
#
# Output:
#   Creates Ansible directories and writes ~/.ansible.cfg with status output.
#
# Example(s):
#   setup_ansible_config
setup_ansible_config() {
    echo -e "${BLUE}Setting up Ansible configuration...${RESET}"

    # Create ansible directories
    local ansible_dirs=(
        "${HOME}/.ansible"
        "${HOME}/.ansible/collections"
        "${HOME}/.ansible/roles"
        "${HOME}/.ansible/fact_cache"
        "${HOME}/ansible-logs"
        "${HOME}/ansible-logs/hosts"
        "/tmp/.ansible/tmp"
    )

    for dir in "${ansible_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo -e "${BLUE}Creating directory: ${dir}${RESET}"
            mkdir -p "$dir"
        fi
    done

    # Check if template exists
    local template_file="${INSTALL_DIR}/templates/ansible.cfg.tmpl"
    if [[ ! -f "${template_file}" ]]; then
        echo -e "${RED}Error: ansible.cfg.tmpl not found in ${INSTALL_DIR}/templates/${RESET}"
        return 1
    fi

    # Process the template - replace HOME_DIR with actual home directory
    echo -e "${BLUE}Processing ansible.cfg template...${RESET}"
    sed "s|HOME_DIR|${HOME}|g" "${template_file}" > "${HOME}/.ansible.cfg"

    # Set appropriate permissions
    chmod 644 "${HOME}/.ansible.cfg"

    echo -e "${GREEN}✓ Ansible configuration installed to ${HOME}/.ansible.cfg${RESET}"

    # Verify the configuration if ansible-config is available
    if command -v ansible-config &> /dev/null; then
        echo -e "${BLUE}Verifying Ansible configuration...${RESET}"
        if ansible-config dump --only-changed &> /dev/null 2>&1; then
            echo -e "${GREEN}✓ Ansible configuration is valid${RESET}"

            # Display key configuration paths
            echo -e "\n${GREEN}=== Ansible Configuration Summary ===${RESET}"
            echo -e "${BLUE}Per-host logs:${RESET} ${HOME}/ansible-logs/hosts/"
            echo -e "${BLUE}Fact cache:${RESET} ${HOME}/.ansible/fact_cache"
            echo -e "${BLUE}Collections:${RESET} ${HOME}/.ansible/collections"
            echo -e "${BLUE}Roles:${RESET} ${HOME}/.ansible/roles"
        else
            echo -e "${YELLOW}⚠ Warning: Could not verify Ansible configuration${RESET}"
        fi
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

    # Setup ansible configuration
    setup_ansible_config

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

# Create required directories
create_directories

# Copy additional files
cp -r "${INSTALL_DIR}/files" "${DOT_DIR}/files"
cp "${DOT_DIR}/files/.gitconfig" "${HOME}/.gitconfig"
echo -e "${YELLOW}Remember to configure ${HOME}/.gitconfig.userparams${RESET}"

# Copy asdf default package files
cp "${DOT_DIR}/config/default-golang-pkgs" "${HOME}/.default-golang-pkgs"
cp "${DOT_DIR}/config/default-python-packages" "${HOME}/.default-python-packages"
cp "${DOT_DIR}/config/default-ruby-gems" "${HOME}/.default-gems"

# macOS specific setup
if [[ "$OS_TYPE" == 'Darwin' ]]; then
    setup_auto_update
    setup_brewfile
fi

# Install oh-my-zsh
install_oh_my_zsh

# Only run Ansible setup if RUN_ANSIBLE is true
if [[ "${RUN_ANSIBLE}" == true ]]; then
    echo -e "${BLUE}Running Ansible setup...${RESET}"
    setup_ansible
else
    echo -e "${YELLOW}Skipping Ansible setup (--skip-ansible flag was used)${RESET}"
    # Still setup ansible config even if not running ansible
    setup_ansible_config
fi

echo -e "${BLUE}Dotfiles installation complete!${RESET}"
