#!/usr/bin/env bash

# venv
alias venv_activate="source .venv/bin/activate"
alias venv_deactivate="deactivate"
alias venv_create="virtualenv .venv"

# Utilities
alias str_len="python -c 'import sys; print(len(sys.argv[1]))'"
OS="$(uname | python3 -c 'print(open(0).read().lower().strip())')"
export OS
alias pc="pre-commit"
alias keeper_update='python3 -m pip install --upgrade keepercommander'

# Extracts only the comments from the contents of the specified file or from stdin.
# It supports extracting single-line comments that start with // or #, as
# well as multi-line comments that start with /* and end with */.
# The extracted comments are then printed to stdout, with each comment on a separate line.
#
# Usage:
#   onlycomments [file_path]
#   echo 'code with // comments' | onlycomments
#
# Output
#   Only the comments extracted from the file or stdin, with each comment on a separate line.
#
# Example(s):
#   onlycomments "file.go"
#   echo 'code with // comments' | onlycomments
onlycomments() {
    if [ $# -eq 0 ]; then
        grep -E '(//.*|/\*.*\*/|#.*)$'
    else
        file_path="$1"
        grep -E '(//.*|/\*.*\*/|#.*)$' "$file_path"
    fi
}

# Run an ansible playbook at the specified path with the (optional)
# specified inventory file.
#
# Usage:
#   run_playbook [playbook_path]
#
# Arguments:
#   playbook_path: The path to the playbook to run.
#   inventory_path: The path to the inventory file to use.
#
# Output:
#   The output of the ansible-playbook command.
#
# Example(s):
#   run_playbook "playbook.yml"
function run_playbook() {
    local playbook_path="$1"
    local inventory_path="$2"

    if [[ -z "$playbook_path" ]]; then
        echo "Error: Playbook path is required."
        return 1
    fi

    if [[ -z "$inventory_path" ]]; then
        ansible-playbook "$playbook_path"
    else
        ansible-playbook -i "$inventory_path" "$playbook_path"
    fi
}
