#!/bin/bash

# Taints all Terraform-managed resources in the current state
#
# This function taints all Terraform-managed resources in the current state,
# excluding data sources. Tainting a resource marks it for recreation during
# the next Terraform apply.
#
# Usage:
#   taint_terraform_resources
#
# Output:
#   Outputs the progress of tainting each resource, including any errors
#   encountered during the process.
#
# Example(s):
#   taint_terraform_resources
taint_terraform_resources() {
    # Get the list of resources from terraform state
    local resources
    resources=$(terraform state list)

    # Loop through each resource
    for resource in $resources; do
        # Check if the resource is not a data source
        if [[ ! $resource == data.* ]]; then
            # Taint the resource and check for errors
            if ! terraform taint "$resource"; then
                echo "Error: Unable to taint resource $resource"
            else
                echo "Tainted resource $resource"
            fi
        fi
    done
}

# Removes all resources from Terragrunt state after confirmation
#
# This function prompts the user for confirmation before removing all resources
# from the Terragrunt state. It lists all resources in the state and removes
# them one by one, displaying the progress.
#
# Usage:
#   nuke_terragrunt_state
#
# Output:
#   Displays the progress of removing each resource, including any errors
#   encountered during the process.
#
# Example(s):
#   nuke_terragrunt_state
nuke_terragrunt_state() {
    if [[ ! -f $HOME/.dotfiles/common ]]; then
        echo "Error: Unable to find common functions file"
        return 1
    fi

    # shellcheck disable=SC1091
    source "$HOME/.dotfiles/common"
    if ! ru_sure "Are you sure you want to remove all resources from Terragrunt state?"; then
        return
    fi

    # List all Terragrunt state resources and remove them
    terragrunt state list | while read -r resource; do
        echo "Removing $resource..."
        terragrunt state rm "$resource"
    done
}
