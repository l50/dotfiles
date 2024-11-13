# shellcheck shell=bash

# Cleans up IAM resources based on input criteria
#
# This function processes IAM resources that match specified criteria. It reads
# resource names (roles and policies) from standard input (stdin) and performs
# the following actions:
# - For roles:
#   - Removes the role from any instance profiles it's associated with.
#   - Detaches all managed policies attached to the role.
#   - Deletes all inline policies attached to the role.
#   - Attempts to delete the role itself.
# - For policies:
#   - Detaches the policy from any roles it's attached to.
#   - Deletes the policy.
#
# Usage:
#   Pipe the output of a command that lists IAM roles and policies into this function
#   to clean them up. Ensure each line of the input contains the ARN of one IAM resource.
#   Example: find_iam_resources_with_keyword 'terratest-' | clean_up_iam_resources
#
# Input:
#   Resource ARNs are expected to be read from stdin, one per line. Each
#   resource ARN should meet the criteria for processing
#   (e.g., prefixed with "terratest-" or belonging to a specific AWS account).
#
# Output:
#   Outputs the actions taken for each resource, including detaching and deleting
#   policies, removing roles from instance profiles, and deleting roles. If any
#   errors occur, they are also output.
#
# Example(s):
#   echo "arn:aws:iam::123456789012:role/terratest-example-role" | clean_up_iam_resources
#   This example processes a single role named "terratest-example-role", removing
#   it from any instance profiles, detaching and deleting policies, and then deleting the role.
#
#   echo "arn:aws:iam::123456789012:policy/terratest-example-policy" | clean_up_iam_resources
#   This example processes a single policy named "terratest-example-policy", detaching it
#   from any roles and then deleting the policy.
clean_up_iam_resources() {
    while IFS= read -r line; do
        resource_arn=$(echo "$line" | awk '{print $1}')

        if [[ "$resource_arn" =~ ^arn:aws:iam::[0-9]+:policy/.+ ]]; then
            policy_arn=$resource_arn
            roles=$(aws iam list-entities-for-policy --policy-arn "$policy_arn" --query 'PolicyRoles[].RoleName' --output text)
            for role in $roles; do
                echo "Detaching policy $policy_arn from $role"
                aws iam detach-role-policy --role-name "$role" --policy-arn "$policy_arn"
            done
            echo "Deleting policy: $policy_arn"
            aws iam delete-policy --policy-arn "$policy_arn"
        elif [[ "$resource_arn" =~ ^arn:aws:iam::[0-9]+:role/.+ ]]; then
            role_name=$(echo "$resource_arn" | awk -F'/' '{print $2}')
            instance_profiles=$(aws iam list-instance-profiles-for-role --role-name "$role_name" --query 'InstanceProfiles[].InstanceProfileName' --output text)
            for profile in $instance_profiles; do
                echo "Removing role $role_name from instance profile $profile"
                aws iam remove-role-from-instance-profile --instance-profile-name "$profile" --role-name "$role_name"
            done
            policies=$(aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text)
            for policy_arn in $policies; do
                echo "Detaching policy $policy_arn from $role_name"
                aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"
            done
            inline_policies=$(aws iam list-role-policies --role-name "$role_name" --query 'PolicyNames' --output text)
            for policy_name in $inline_policies; do
                echo "Deleting inline policy $policy_name from $role_name"
                aws iam delete-role-policy --role-name "$role_name" --policy-name "$policy_name"
            done
            echo "Attempting to delete role: $role_name"
            if aws iam delete-role --role-name "$role_name"; then
                echo "Successfully deleted role: $role_name"
            else
                echo "Failed to delete role: $role_name. Check for any remaining dependencies."
            fi
        else
            echo "Invalid resource ARN: $resource_arn"
        fi
    done
}

# Detach an IAM policy from all entities and delete it
#
# Detaches the specified IAM policy from all roles it's attached to and then deletes the policy.
#
# Usage:
#   detach_delete_iam_policy "arn:aws:iam::accountID:policy/policy-name"
#   where "arn:aws:iam::accountID:policy/policy-name" is the ARN of the IAM policy you want to detach and delete.
#
# Output:
#   Detaches the policy from all roles and deletes it.
#
# Example(s):
#
#   AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
#   detach_delete_iam_policy "arn:aws:iam::$AWS_ACCOUNT_ID:policy/test-eks-...."
detach_delete_iam_policy() {
    local policy_arn=$1

    if [[ -z "$policy_arn" ]]; then
        echo "No policy ARN provided. Usage: detach_delete_iam_policy <policy-arn>"
        return 1
    fi

    # List roles attached to the policy
    local attached_roles
    attached_roles=$(aws iam list-entities-for-policy --policy-arn "$policy_arn" --query 'PolicyRoles[].RoleName' --output text)

    # Detach policy from each role
    for role_name in $attached_roles; do
        echo "Detaching policy from role: $role_name"
        aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"
    done

    # Delete the policy
    echo "Deleting policy: $policy_arn"
    aws iam delete-policy --policy-arn "$policy_arn"
}

# Find IAM resources with a specific keyword in their name or tag
#
# Searches for IAM users, roles, policies, and groups that have a specific
# keyword in their name or tag. The keyword is provided as an input string to the function
# and is case-insensitive.
#
# Usage:
#   find_iam_resources_with_keyword "keyword"
#   where "keyword" is the string you want to search for in the name or tag of IAM resources.
#
# Output:
#   Lists the IAM resources that match the keyword in their name or tag.
#
# Example(s):
#   find_iam_resources_with_keyword "terratest-"
find_iam_resources_with_keyword() {
    input_string=$1
    if [[ -z "$input_string" ]]; then
        echo "No input string provided. Usage: find_iam_resources_with_keyword <keyword>"
        return 1
    fi

    input_string=$(echo "$1" | tr '[:upper:]' '[:lower:]')  # Convert input string to lowercase using tr

    local resource_types=("user" "role" "policy" "group")

    echo "Searching for IAM resources with '$input_string' in the name or tag..."

    for resource_type in "${resource_types[@]}"; do
        echo "Checking IAM $resource_type(s)..."
        case $resource_type in
            "user")
                # List IAM users with keyword in the name
                aws iam list-users --query "Users[].[UserName, UserId, CreateDate, Path]" --output text | grep -i "$input_string"
                ;;
            "role")
                # List IAM roles with keyword in the name
                aws iam list-roles --query "Roles[].[RoleName, Arn, CreateDate, Description, MaxSessionDuration, Path, RoleId, RoleName]" --output text | grep -i "$input_string"
                ;;
            "policy")
                # List IAM policies with keyword in the name
                aws iam list-policies --query "Policies[].[PolicyName, Arn, CreateDate, DefaultVersionId, Path, PolicyId]" --output text | grep -i "$input_string"
                ;;
            "group")
                # List IAM groups with keyword in the name
                aws iam list-groups --query "Groups[].[GroupName, Arn, CreateDate, Path]" --output text | grep -i "$input_string"
                ;;
        esac
    done

    echo "Finished searching for IAM resources."
}

# List IAM Policies and Group Policies for an IAM User
#
# Lists directly attached IAM policies and group policies for a specified IAM user.
# It fetches the attached policies directly linked to the user and policies
# attached to groups the user is part of.
#
# Usage:
#   list_iam_user_policies "user-name"
#   where "user-name" is the name of the IAM user you want to check.
#
# Output:
#   Outputs the policies directly attached to the user and the policies
#   attached to the groups the user is part of.
#
# Example(s):
#   list_iam_user_policies "my-iam-user"
list_iam_user_policies() {
    local user_name=$1

    # Prevent aws cli from using a pager for output
    export AWS_PAGER=""

    if [[ -z "$user_name" ]]; then
        echo "No IAM User name provided. Usage: list_iam_user_policies <user-name>"
        return 1
    fi

    echo "Getting policies attached directly to the IAM User: $user_name"
    aws iam list-attached-user-policies --user-name "$user_name" --output json

    echo "Getting IAM Groups the user is a member of:"
    local groups
    groups=$(aws iam list-groups-for-user --user-name "$user_name" --query 'Groups[].GroupName' --output json)

    # Parse the group names and fetch policies for each group
    local group_names
    group_names=$(echo "$groups" | jq -r '.[]')

    for group_name in $group_names; do
        echo "Getting policies attached to the group: $group_name"
        aws iam list-attached-group-policies --group-name "$group_name" --output json
    done
}
