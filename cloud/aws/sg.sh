# Authorize Security Group Ingress
#
# Authorizes inbound traffic for the specified security group if the rule doesn't already exist.
# Creates the security group if it doesn't already exist.
#
# Usage:
#   authorize_security_group_ingress [group_name] [group_description] [vpc_id] [protocol] [port] [cidr]
#
# Output:
#   Returns the id of the security group, but configures the security group to allow inbound traffic if the rule is added.
#   If the security group or rule already exists, outputs a message indicating the existing group or rule.
#
# Example(s):
#   SECURITY_GROUP_ID=$(authorize_security_group_ingress "my_security_group" "Description of my security group" "vpc-0abcd1234efgh5678" "tcp" "22" "0.0.0.0/0")
authorize_security_group_ingress() {
    local group_name=$1
    local group_description=$2
    local vpc_id=$3
    local protocol=$4
    local port=$5
    local cidr=$6
    
    # Check if the security group already exists
    local security_group_id
    security_group_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$group_name" --query 'SecurityGroups[0].GroupId' --output text)
    
    # If the security group doesn't exist or the command fails, create it
    if [ -z "$security_group_id" ] || [ "$security_group_id" == "None" ]; then
        if ! security_group_id=$(aws ec2 create-security-group --group-name "$group_name" --description "$group_description" --vpc-id "$vpc_id" --query 'GroupId' --output text); then
            echo "Failed to create security group: $group_name"
            return 1
        fi
        echo "Created security group $group_name with ID: $security_group_id"
    else
        echo "Security group $group_name already exists with ID: $security_group_id"
    fi

    # Check if the ingress rule already exists 
    local existing_rule
    existing_rule=$(aws ec2 describe-security-groups \
        --group-ids "$security_group_id" \
        --query "SecurityGroups[0].IpPermissions[?IpProtocol=='$protocol' && FromPort=='$port' && contains(IpRanges[].CidrIp, '$cidr')]")
    if [ -n "$existing_rule" ]; then
        echo "Ingress rule already exists for: $protocol port $port from $cidr"
        echo "$security_group_id"
    else
        if aws ec2 authorize-security-group-ingress \
            --group-id "$security_group_id" \
            --protocol "$protocol" \
            --port "$port" \
            --cidr "$cidr"; then
            echo "Added ingress rule to security group $group_name"
            echo "$security_group_id"
        else
            echo "Failed to add ingress rule to security group $group_name"
            return 1
        fi
    fi
}

# Delete Security Groups
#
# Deletes specified security groups by name or ID, including detaching network interfaces
# and removing rules.
#
# Usage:
#   delete_security_groups security_group_identifiers
#
# Output:
#   Deletes the specified security groups, handling dependencies.
#
# Example(s):
#   delete_security_groups "sg-0cec4d85ba446428c"
#   delete_security_groups "my-security-group"
#   delete_security_groups "arn:aws:ec2:us-east-1:123445667:security-group/sg-0123456789abcdef0"
delete_security_groups() {
    local search_pattern=$1

    # Get the security group IDs matching the pattern
    sg_ids=$(aws ec2 describe-security-groups \
        --filters Name=group-name,Values="$search_pattern" \
        --query "SecurityGroups[*].GroupId" \
        --output text)

    if [ -z "$sg_ids" ]; then
        echo "No security groups found for pattern $search_pattern."
        return
    fi

    # Iterate over each security group ID in parallel
    echo "$sg_ids" | tr '\t' '\n' | while IFS= read -r sg_id; do
        {
            sg_id=$(echo "$sg_id" | xargs)  # Trim any whitespace
            echo "Processing security group with ID $sg_id."

            # Remove all inbound rules
            inbound_rules=$(aws ec2 describe-security-groups \
                --group-ids "$sg_id" \
                --query 'SecurityGroups[0].IpPermissions' \
                --output json)
            if [ "$inbound_rules" != "[]" ]; then
                echo "Revoking inbound rules for security group $sg_id"
                aws ec2 revoke-security-group-ingress \
                    --group-id "$sg_id" \
                    --ip-permissions "$inbound_rules"
            fi

            # Remove all outbound rules
            outbound_rules=$(aws ec2 describe-security-groups \
                --group-ids "$sg_id" \
                --query 'SecurityGroups[0].IpPermissionsEgress' \
                --output json)
            if [ "$outbound_rules" != "[]" ]; then
                echo "Revoking outbound rules for security group $sg_id"
                aws ec2 revoke-security-group-egress \
                    --group-id "$sg_id" \
                    --ip-permissions "$outbound_rules"
            fi

            # Detach network interfaces
            network_interfaces=$(aws ec2 describe-network-interfaces \
                --filters Name=group-id,Values="$sg_id" \
                --query 'NetworkInterfaces[*].NetworkInterfaceId' \
                --output text)
            if [ -n "$network_interfaces" ]; then
                for ni in $network_interfaces; do
                    ni=$(echo "$ni" | xargs)  # Trim whitespace
                    echo "Detaching network interface $ni from security group $sg_id."
                    attachment_id=$(aws ec2 describe-network-interfaces \
                        --network-interface-ids "$ni" \
                        --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
                        --output text)
                    if [ -n "$attachment_id" ]; then
                        aws ec2 detach-network-interface --attachment-id "$attachment_id"
                        aws ec2 delete-network-interface --network-interface-id "$ni"
                    fi
                done
            fi

            # Attempt to delete the security group with retries
            for attempt in {1..3}; do
                echo "Attempting to delete security group with ID $sg_id (Attempt $attempt)"
                if aws ec2 delete-security-group --group-id "$sg_id"; then
                    echo "Deleted security group with ID $sg_id on attempt $attempt."
                    break
                else
                    echo "Failed to delete security group with ID $sg_id on attempt $attempt. Retrying..."
                    sleep 5
                fi
            done
        } &
    done

    # Wait for all background processes to complete
    wait

    echo "Security groups processing completed."
}

# List Security Groups
#
# Lists security groups based on optional filters.
#
# Usage:
#   list_security_groups
#
# Output:
#   Lists the names of the security groups that match the specified filters, if any.
#   If no filters are specified, all security group names are listed, one per line.
#
# Example(s):
#   list_security_groups
#   list_security_groups "test-tt-test-*"
list_security_groups() {
    local filter="$1"
    local query_args=()

    # Check if a filter is provided and construct the query argument
    if [[ -n "$filter" ]]; then
        query_args=(--filters "Name=group-name,Values=$filter")
    fi

    # Attempt to list security groups with the given filter
    local group_names
    if group_names=$(aws ec2 describe-security-groups "${query_args[@]}" --query 'SecurityGroups[*].GroupName' --output text); then
        echo "$group_names" | tr '\t' '\n'
    fi
}
