#!/bin/bash

# Prompts the user for confirmation with a custom message
#
# This function displays a custom confirmation message and waits for the user's
# input. If the user confirms with 'y' or 'Y', the function returns 0 (success).
# Otherwise, it prints "Operation cancelled." and returns 1 (failure).
#
# Usage:
#   ru_sure "Custom confirmation message"
#
# Parameters:
#   $1 - Custom confirmation message to display
#
# Returns:
#   0 if the user confirms, 1 otherwise
#
# Example(s):
#   if ! ru_sure "Are you sure you want to proceed?"; then
#       return
#   fi
ru_sure() {
    local message=$1
    echo "$message (y/N):"
    read -r confirm
    if [[ $confirm != [yY] ]]; then
        echo "Operation cancelled."
        return 1
    fi
    return 0
}
