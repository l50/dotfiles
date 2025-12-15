#!/usr/bin/env bash

# check_fabric() verifies that the fabric tool is installed and available.
#
# Usage:
#   check_fabric
#
# Output:
#   Returns 0 if fabric is installed, exits with error message if not.
#
# Example:
#   check_fabric
check_fabric() {
    if ! command -v fabric &> /dev/null; then
        echo "error: fabric is not installed"
        echo "install it from: https://github.com/danielmiessler/fabric"
        return 1
    fi
}

# fabric_commit() generates a commit message using fabric AI and commits
# the staged changes, then pushes to remote.
#
# Usage:
#   fabric_commit
#
# Output:
#   Commits staged changes with an AI-generated commit message and pushes to remote.
#
# Example:
#   fabric_commit
#
# Note:
#   Requires git alias 'ds' and the fabric tool to be installed.
fabric_commit() {
    check_fabric || return 1
    git ds | fabric --pattern commit | ~/.config/fabric/patterns/commit/filter.sh | git commit -F - && git push
}
