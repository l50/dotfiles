#!/bin/bash

# Deletes KMS keys with a specific string in their alias
#
# This function searches for AWS KMS keys with a specific string in their alias name
# and deletes them. The search string is provided as an input to the function.
# The function lists aliases containing the search string, retrieves the associated key IDs,
# schedules the keys for deletion, and deletes the aliases.
#
# Usage:
#   delete_kms_keys_with_string "search-string"
#   where "search-string" is the string you want to search for in the KMS alias names.
#
# Output:
#   Outputs the progress of deleting each KMS key and its associated alias, including
#   scheduling the deletion of keys and deleting the aliases.
#
# Example(s):
#   Search for and delete KMS keys with "tt-test" in their alias:
#   delete_kms_keys_with_string "tt-test"
#
#   Delete all KMS keys with an empty string in their alias:
#   delete_kms_keys_with_string ' '
delete_eks_cluster_and_node_groups() {
    CLUSTER_NAME=$1
    if [[ -z "$CLUSTER_NAME" ]]; then
        echo "No cluster name provided. Usage: delete_eks_cluster_and_node_groups <cluster-name>"
        return 1
    fi

    # Check if cluster exists first
    if ! aws eks describe-cluster --name "$CLUSTER_NAME" > /dev/null 2>&1; then
        echo "Cluster $CLUSTER_NAME does not exist"
        return 0
    fi

    # Get node groups using JSON format and process with jq
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --output json | jq -r '.nodegroups[]')

    if [[ -n "$NODE_GROUPS" ]]; then
        echo "Found nodegroups:"
        echo "$NODE_GROUPS"

        # Read each line of NODE_GROUPS
        echo "$NODE_GROUPS" | while IFS= read -r NODE_GROUP; do
            echo "Deleting node group '$NODE_GROUP' from cluster $CLUSTER_NAME..."

            # Delete nodegroup
            if aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP"; then
                echo "Waiting for node group '$NODE_GROUP' to be deleted..."
                aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP"
            else
                echo "Failed to delete nodegroup '$NODE_GROUP'. Cluster deletion may fail."
            fi
        done
    else
        echo "No nodegroups found for cluster $CLUSTER_NAME"
    fi

    # Sleep to allow AWS to properly register the nodegroup deletions
    echo "Waiting 30 seconds for AWS to process nodegroup deletions..."
    sleep 30

    echo "Deleting EKS cluster $CLUSTER_NAME..."
    if ! aws eks delete-cluster --name "$CLUSTER_NAME"; then
        echo "Failed to delete cluster. Waiting additional time and trying again..."
        sleep 30
        if ! aws eks delete-cluster --name "$CLUSTER_NAME"; then
            echo "Failed to delete cluster after second attempt. Please check if all nodegroups are properly deleted."
            return 1
        fi
    fi

    echo "Waiting for EKS cluster $CLUSTER_NAME to be deleted..."
    if ! aws eks wait cluster-deleted --name "$CLUSTER_NAME"; then
        echo "Failed to wait for cluster deletion. Please check the cluster status manually."
        return 1
    fi

    echo "EKS cluster $CLUSTER_NAME and its node groups have been successfully deleted."
}
