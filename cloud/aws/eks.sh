#!/bin/bash

# Deletes an EKS cluster and its associated node groups
#
# This function deletes an Amazon EKS cluster and all of its associated node groups.
# The name of the EKS cluster to delete is provided as an input string to the function.
#
# Usage:
#   delete_eks_cluster_and_node_groups "cluster-name"
#   where "cluster-name" is the name of the EKS cluster you want to delete.
#
# Output:
#   Outputs the progress of deleting the node groups and the EKS cluster, including
#   waiting for each deletion to complete.
#
# Example(s):
#   delete_eks_cluster_and_node_groups "test-tt-test-wndq2t"
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

    # Get node groups and handle potential empty result
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups[*]' --output text)

    if [[ "$NODE_GROUPS" != "None" && -n "$NODE_GROUPS" ]]; then
        echo "Found nodegroups: $NODE_GROUPS"
        for NODE_GROUP in $NODE_GROUPS; do
            echo "Deleting node group $NODE_GROUP from cluster $CLUSTER_NAME..."

            # Delete without waiting first
            if ! aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP" 2> /dev/null; then
                echo "Failed to delete nodegroup $NODE_GROUP. Attempting manual cleanup..."

                # Get all nodegroups with more detailed information
                ALL_NODEGROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --output json)

                # If the delete failed, try to get the actual nodegroup name from the ARN
                ACTUAL_NODEGROUP_NAME=$(echo "$ALL_NODEGROUPS" | jq -r ".nodegroups[] | select(contains(\"$NODE_GROUP\"))")

                if [[ -n "$ACTUAL_NODEGROUP_NAME" ]]; then
                    echo "Attempting to delete nodegroup with extracted name: $ACTUAL_NODEGROUP_NAME"
                    aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ACTUAL_NODEGROUP_NAME"
                    aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ACTUAL_NODEGROUP_NAME"
                fi
            else
                echo "Waiting for node group $NODE_GROUP to be deleted..."
                aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP"
            fi
        done
    else
        echo "No nodegroups found for cluster $CLUSTER_NAME"
    fi

    echo "Deleting EKS cluster $CLUSTER_NAME..."
    if ! aws eks delete-cluster --name "$CLUSTER_NAME"; then
        echo "Failed to delete cluster. Please check if all nodegroups are properly deleted."
        return 1
    fi

    echo "Waiting for EKS cluster $CLUSTER_NAME to be deleted..."
    if ! aws eks wait cluster-deleted --name "$CLUSTER_NAME"; then
        echo "Failed to wait for cluster deletion. Please check the cluster status manually."
        return 1
    fi

    echo "EKS cluster $CLUSTER_NAME and its node groups have been successfully deleted."
}
