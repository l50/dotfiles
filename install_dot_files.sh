#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_dot_files.sh
#
# Bootstraps the workstation by cloning ansible-collection-workstation and
# running its workstation playbook against this host. The ansible roles own
# ~/.zshrc, ~/.tmux.conf, ~/.gitconfig, ~/.ansible.cfg, the vault-pass helper,
# and the deployment of shell-function libraries into ~/.dotfiles.
#
# Usage: bash install_dot_files.sh [options]
#
# Options:
#   --skip-ansible     Skip the entire Ansible setup.
#   --install-alloy    Install and configure Grafana Alloy (requires Node).
#   --install-mise     Install and configure Mise tool manager.
#   --install-go-task  Install and configure Go Task.
#   --install-claude   Install and configure Claude Code CLI (requires Node).
#
# Jayson Grace <jayson.e.grace at gmail.com>
# -----------------------------------------------------------------------------
set -eou pipefail

RUN_ANSIBLE=true
INSTALL_ALLOY=false
INSTALL_MISE=false
INSTALL_GO_TASK=false
INSTALL_CLAUDE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-ansible) RUN_ANSIBLE=false ;;
        --install-alloy) INSTALL_ALLOY=true ;;
        --install-mise) INSTALL_MISE=true ;;
        --install-go-task) INSTALL_GO_TASK=true ;;
        --install-claude) INSTALL_CLAUDE=true ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-ansible] [--install-alloy] [--install-mise] [--install-go-task] [--install-claude]"
            exit 1
            ;;
    esac
    shift
done

INSTALL_DIR="$(pwd)"
ANSIBLE_DIR="$HOME/cowdogmoo/ansible-collection-workstation"

BLUE="\033[01;34m"
RESET="\033[00m"
YELLOW="\033[01;33m"

# Sets up the Ansible workstation environment and runs the playbook.
setup_ansible() {
    echo "Setting up Ansible environment..."

    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    if ! command -v ansible-galaxy &> /dev/null; then
        echo "Ansible is not installed. Please install it first."
        exit 1
    fi

    if [[ ! -d "${ANSIBLE_DIR}" ]]; then
        echo -e "${YELLOW}Cloning ansible workstation repo...${RESET}"
        mkdir -p "$(dirname "${ANSIBLE_DIR}")"
        git clone https://github.com/CowDogMoo/ansible-collection-workstation.git "${ANSIBLE_DIR}"
    else
        echo -e "${YELLOW}Using existing ansible workstation repo...${RESET}"
    fi

    echo "Installing CowDogMoo workstation collection and dependencies..."
    local install_ok=true
    ansible-galaxy collection install git+https://github.com/CowDogMoo/ansible-collection-workstation.git,main --upgrade || install_ok=false
    # The playbook statically imports grafana.grafana.alloy, so its collection
    # must be present for the play to parse even when the role is skipped.
    if [[ -f "${ANSIBLE_DIR}/requirements.yml" ]]; then
        ansible-galaxy collection install -r "${ANSIBLE_DIR}/requirements.yml" --upgrade || install_ok=false
    fi

    if [[ "${install_ok}" == false ]]; then
        # Tolerate upgrade failures (e.g. offline) when the collections exist.
        local installed
        installed=$(ansible-galaxy collection list 2> /dev/null)
        if ! grep -q "cowdogmoo.workstation" <<< "${installed}" \
            || ! grep -q "grafana.grafana" <<< "${installed}"; then
            echo "Failed to install required Ansible collections." >&2
            exit 1
        fi
        echo -e "${YELLOW}Collection upgrade failed; using existing installed collections.${RESET}"
    fi

    local hostname
    hostname=$(hostname -s)
    local inventory_file="${ANSIBLE_DIR}/playbooks/workstation/inventory"
    cat > "${inventory_file}" << EOF
[workstation]
${hostname} ansible_connection=local
EOF

    # Opt-in roles: skip each playbook tag unless its --install-* flag was set.
    local skip_tags=()
    local entry
    for entry in "alloy:${INSTALL_ALLOY}" "mise:${INSTALL_MISE}" \
        "go_task:${INSTALL_GO_TASK}" "claude:${INSTALL_CLAUDE}"; do
        if [[ "${entry#*:}" == false ]]; then
            skip_tags+=("${entry%%:*}")
        fi
    done

    local extra_args=()
    if [[ ${#skip_tags[@]} -gt 0 ]]; then
        local joined_tags
        joined_tags=$(
            IFS=,
            echo "${skip_tags[*]}"
        )
        extra_args+=("--skip-tags" "${joined_tags}")
    fi

    # ${arr[@]+...} keeps the empty-array expansion safe under set -u on bash 3.2.
    ansible-playbook "${ANSIBLE_DIR}/playbooks/workstation/workstation.yml" \
        -i "${inventory_file}" \
        -e "shell_functions_source_path=${INSTALL_DIR}" \
        ${extra_args[@]+"${extra_args[@]}"}
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
