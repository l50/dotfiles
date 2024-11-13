# shellcheck shell=bash

# Create EC2 Instance
#
# Creates an EC2 instance with the specified AMI, instance type, and security group.
#
# Usage:
#   create_ec2_instance
#
# Output:
#   Outputs the ID of the created EC2 instance.
#
# Example(s):
#   create_ec2_instance
create_ec2_instance() {
    AMI_ID="$1"
    INSTANCE_TYPE="${2:-t3.micro}"
    IAM_INSTANCE_PROFILE="${3:-AmazonSSMInstanceProfileForInstances}"
    INSTANCE_NAME="${4:-My-EC2-Instance}"
    SECURITY_GROUP_NAME="${5:-default-sg}"
    SECURITY_GROUP_DESC="${6:-Default Security Group}"
    VPC_ID="$7"
    DEFAULT_SUBNET_ID="$8"
    SECURITY_GROUP_ID=$(authorize_security_group_ingress "$SECURITY_GROUP_NAME" "$SECURITY_GROUP_DESC" "${VPC_ID}" "tcp" 22 "0.0.0.0/0" | tail -n 1)
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type "$INSTANCE_TYPE" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --subnet-id "$DEFAULT_SUBNET_ID" \
        --iam-instance-profile "Name=$IAM_INSTANCE_PROFILE" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    wait_for_initialization
    if [ -z "$INSTANCE_ID" ]; then
        echo "Failed to create EC2 instance"
        return 1
    fi

    echo "Created EC2 instance: $INSTANCE_ID" >&2
    echo "${INSTANCE_ID}"
}

# Delete Instance Profiles
#
# Deletes instance profiles based on input criteria. It reads instance profile names
# from standard input (stdin) and performs the following actions:
# - Removes the role from the instance profile.
# - Deletes the instance profile itself.
#
# Usage:
#   Pipe the output of list_instance_profiles into this function to delete them.
#   Or provide a specific instance profile name as an argument to delete it.
#
# Input:
#   Instance profile names are expected to be read from stdin, one per line.
#   If a specific instance profile name is provided as an argument, it will be deleted.
#
# Output:
#   Outputs the actions taken for each instance profile, including removing roles
#   and deleting the instance profile. If any errors occur, they are also output.
#
# Example(s):
#   list_instance_profiles | delete_instance_profile
#   delete_instance_profile example-instance-profile
delete_instance_profile() {
    if [[ -n "$1" ]]; then
        echo "$1" | delete_instance_profile_from_input
    else
        delete_instance_profile_from_input
    fi
}

delete_instance_profile_from_input() {
    while IFS= read -r instance_profile_name; do
        # List the roles in the instance profile
        roles=$(aws iam get-instance-profile --instance-profile-name "$instance_profile_name" --query 'InstanceProfile.Roles[].RoleName' --output text)

        # Remove each role from the instance profile
        for role in $roles; do
            echo "Removing role $role from instance profile $instance_profile_name"
            aws iam remove-role-from-instance-profile --instance-profile-name "$instance_profile_name" --role-name "$role"
        done

        # Delete the instance profile
        echo "Deleting instance profile: $instance_profile_name"
        aws iam delete-instance-profile --instance-profile-name "$instance_profile_name"
    done
}

# Delete Unused Elastic IPs (EIPs)
#
# Deletes all Elastic IP addresses (EIPs) that are not associated with any running instances.
# This function uses AWS CLI to find and release any unassociated EIPs, helping to avoid unnecessary charges.
#
# Usage:
#   delete_unused_eips
#   No arguments are required. Simply run the function to check and release all unassociated EIPs.
#
# Output:
#   For each EIP released, it outputs a success message with the allocation ID of the released EIP.
#   If an EIP cannot be released, it outputs a failure message with the allocation ID.
#
# Example(s):
#   delete_unused_eips
delete_unused_eips() {
    echo "Deleting all unused EIPs..."

    # Get all unused EIPs, output in JSON, then parse with jq
    aws ec2 describe-addresses --query 'Addresses[?InstanceId==null].AllocationId' --output json | jq -r '.[]' | while IFS= read -r id; do
        if [ -n "$id" ]; then
            # Delete the EIP
            aws ec2 release-address --allocation-id "$id" && echo "Successfully deleted EIP with allocation ID: $id" || echo "Failed to delete EIP with allocation ID: $id"
        fi
    done

    echo "Finished deleting all unused EIPs."
}

# Get Instances by Specified Attribute
#
# Fetches the ID of the EC2 instances based on Name, ARN, or Tag Name.
#
# Usage:
#   find_instance "attribute-type" "attribute-value"
#   where attribute-type can be "name", "arn", or "tag"
#
# Output:
#   Outputs the ID of the EC2 instances based on the specified attribute type and value.
#
# Example(s):
#   INSTANCES=$(find_instance "tag" "prod")
#   INSTANCES=$(find_instance "name" "my-instance")
#   INSTANCES=$(find_instance "arn" "arn:aws:ec2:region:account-ID-without-hyphens:instance/instance-id")
find_instance() {
    ATTRIBUTE_TYPE="$1"
    ATTRIBUTE_VALUE="$2"

    JSON=$(aws ec2 describe-instances --output json)

    case $ATTRIBUTE_TYPE in
        "arn")
            echo "$JSON" | jq -r --arg arn "$ATTRIBUTE_VALUE" '.Reservations[].Instances[] | select(.InstanceArn == $arn) | select(.State.Name == "running") | .InstanceId'
            ;;
        "name")
            echo "$JSON" | jq -r --arg name "$ATTRIBUTE_VALUE" '.Reservations[].Instances[] | select(.Tags[]? | (.Key == "Name" and .Value == $name)) | select(.State.Name == "running") | .InstanceId'
            ;;
        "tag")
            echo "$JSON" | jq -r --arg tag "$ATTRIBUTE_VALUE" '.Reservations[].Instances[] | select(.Tags[]? | .Value == $tag) | select(.State.Name == "running") | .InstanceId'
            ;;
        *)
            echo "Invalid attribute type. Use arn, name, or tag."
            return 1
            ;;
    esac
}

# Get AWS Account ID
#
# Retrieves the AWS Account ID for the currently configured credentials.
#
# Usage:
#   get_aws_account_id
#
# Output:
#   Outputs the AWS Account ID as a string.
#
# Example(s):
#   ACCOUNT_ID=$(get_aws_account_id)
get_aws_account_id() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    if [ -z "$ACCOUNT_ID" ]; then
        echo "Failed to retrieve AWS Account ID" >&2
        return 1
    fi
    echo "$ACCOUNT_ID"
}

# Get Instance Role Credentials
#
# Retrieves the IAM role credentials from the specified EC2 instance.
#
# Usage:
#   get_instance_role_credentials "instance-id"
#   where "instance-id" is the ID of the EC2 instance from which you want to retrieve the IAM role credentials.
#
# Output:
#   Outputs the IAM role credentials.
#
# Example(s):
#   CREDENTIALS=$(get_instance_role_credentials "i-0c4d3a12d5efc5d4d")
get_instance_role_credentials() {
    local INSTANCE_ID=$1
    ROLE_NAME_COMMAND='curl http://169.254.169.254/latest/meta-data/iam/security-credentials/'
    COMMAND_ID=$(aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript --parameters "commands=[\"$ROLE_NAME_COMMAND\"]" --query "Command.CommandId" --output text)
    wait_for_command "$COMMAND_ID"
    ROLE_NAME=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --query 'StandardOutputContent' --output text)

    GET_CREDENTIALS_COMMAND="curl http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME"
    COMMAND_ID=$(aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript --parameters "commands=[\"$GET_CREDENTIALS_COMMAND\"]" --query "Command.CommandId" --output text)
    wait_for_command "$COMMAND_ID"
    CREDENTIALS=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --query 'StandardOutputContent' --output text)
    echo "$CREDENTIALS"
}

# Get Latest AMI
# Fetches the ID of the latest Amazon Machine Image (AMI) for the
# specified OS distribution, version, and architecture.
#
# Usage:
#   get_latest_ami [distro] [version] [architecture]
#
# Output:
#   Outputs the ID of the AMI.
#
# Example(s):
#   get_latest_ami "ubuntu" "22.04" "amd64"
get_latest_ami() {
    local distro=$1
    local version=$2
    local architecture=$3

    # Validate inputs
    if [[ -z "$distro" || -z "$version" || -z "$architecture" ]]; then
        echo "Usage: get_latest_ami <distro> <version> <architecture>"
        echo "Example: get_latest_ami debian 12 amd64"
        return 1
    fi

    case "$distro" in
        "ubuntu")
            case "$version" in
                "22.04")
                    case "$architecture" in
                        "amd64")
                            amiNamePattern="ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
                            ;;
                        "arm64")
                            amiNamePattern="ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for Ubuntu"
                            return 1
                            ;;
                    esac
                    ;;
                "20.04")
                    case "$architecture" in
                        "amd64")
                            amiNamePattern="ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
                            ;;
                        "arm64")
                            amiNamePattern="ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for Ubuntu"
                            return 1
                            ;;
                    esac
                    ;;
                "18.04")
                    case "$architecture" in
                        "amd64")
                            amiNamePattern="ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
                            ;;
                        "arm64")
                            amiNamePattern="ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-arm64-server-*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for Ubuntu"
                            return 1
                            ;;
                    esac
                    ;;
                *)
                    echo "Unsupported version: $version for Ubuntu"
                    return 1
                    ;;
            esac
            owner="099720109477"
            ;;
        "centos")
            case "$version" in
                "7")
                    case "$architecture" in
                        "x86_64")
                            amiNamePattern="CentOS Linux 7 x86_64 HVM EBS*"
                            ;;
                        "arm64")
                            amiNamePattern="CentOS Linux 7 arm64 HVM EBS*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for CentOS"
                            return 1
                            ;;
                    esac
                    ;;
                "8")
                    case "$architecture" in
                        "x86_64")
                            amiNamePattern="CentOS 8 x86_64 AMI*"
                            ;;
                        "arm64")
                            amiNamePattern="CentOS 8 arm64 AMI*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for CentOS"
                            return 1
                            ;;
                    esac
                    ;;
                *)
                    echo "Unsupported version: $version for CentOS"
                    return 1
                    ;;
            esac
            owner="679593333241"
            ;;
        "debian")
            case "$version" in
                "10")
                    case "$architecture" in
                        "amd64")
                            amiNamePattern="debian-10-amd64-*"
                            ;;
                        "arm64")
                            amiNamePattern="debian-10-arm64-*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for Debian"
                            return 1
                            ;;
                    esac
                    ;;
                "11")
                    case "$architecture" in
                        "amd64")
                            amiNamePattern="debian-11-amd64-*"
                            ;;
                        "arm64")
                            amiNamePattern="debian-11-arm64-*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for Debian"
                            return 1
                            ;;
                    esac
                    ;;
                "12")
                    case "$architecture" in
                        "amd64")
                            amiNamePattern="debian-12-amd64-*"
                            ;;
                        "arm64")
                            amiNamePattern="debian-12-arm64-*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for Debian"
                            return 1
                            ;;
                    esac
                    ;;
                *)
                    echo "Unsupported version: $version for Debian"
                    return 1
                    ;;
            esac
            owner="136693071363"
            ;;
        "kali")
            case "$version" in
                "2023.1")
                    case "$architecture" in
                        "amd64")
                            amiNamePattern="kali-linux-2023.1-amd64*"
                            ;;
                        "arm64")
                            amiNamePattern="kali-linux-2023.1-arm64*"
                            ;;
                        *)
                            echo "Unsupported architecture: $architecture for Kali"
                            return 1
                            ;;
                    esac
                    ;;
                *)
                    echo "Unsupported version: $version for Kali"
                    return 1
                    ;;
            esac
            owner="679593333241"
            ;;
        *)
            echo "Unsupported distribution: $distro"
            return 1
            ;;
    esac

    echo "Searching for AMIs with pattern: $amiNamePattern and owner: $owner"
    AMI_ID=$(aws ec2 describe-images \
        --filters "Name=name,Values=$amiNamePattern" \
        --owners "$owner" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --output text)
    if [ -z "$AMI_ID" ]; then
        echo "No images found for distro: $distro, version: $version, architecture: $architecture"
        return 1
    fi
    echo "$AMI_ID"
}

# List Instance Profiles
#
# Lists all instance profiles.
#
# Usage:
#   list_instance_profiles
#
# Output:
#   Outputs a list of instance profiles.
#
# Example(s):
#   list_instance_profiles
list_instance_profiles() {
    INSTANCE_PROFILE_NAMES=$(aws iam list-instance-profiles --query "InstanceProfiles[].InstanceProfileName" --output text | tr '\t' '\n')

    # For each instance profile, print the name
    for INSTANCE_PROFILE_NAME in $INSTANCE_PROFILE_NAMES; do
        echo "$INSTANCE_PROFILE_NAME"
    done
}

# List Running Instances
#
# Lists all running EC2 instances.
#
# Usage:
#   list_running_instances
#
# Output:
#   Outputs a table of running instances.
#
# Example(s):
#   list_running_instances
list_running_instances() {
    aws ec2 describe-instances \
        --query \
        "Reservations[*].Instances[*].{InstanceId:InstanceId, VPC:VpcId, Subnet:SubnetId, PublicIP:PublicIpAddress, PrivateIP:PrivateIpAddress, Name:Tags[?Key=='Name']|[0].Value}" \
        --filters Name=instance-state-name,Values=running --output json
}

# Terminate Instance
#
# Terminates a specified EC2 instance.
#
# Usage:
#   terminate_instance [instance_id]
#
# Output:
#   Terminates the instance if it's running. If it's already being terminated, the function skips it.
#   If the instance is in an unexpected state, it throws an error.
#
# Example(s):
#   terminate_instance "i-0abcd1234efgh5678"
terminate_instance() {
    local instance_id=$1
    while true; do
        instance_status=$(aws ec2 describe-instances --instance-ids "$instance_id" --output json | jq -r '.Reservations[0].Instances[0].State.Name')
        if [ "$instance_status" = "terminated" ] || [ "$instance_status" = "shutting-down" ]; then
            echo "Skipping instance $instance_id which is already $instance_status"
            break
        elif [ "$instance_status" = "running" ]; then
            echo "Terminating instance: $instance_id"
            aws ec2 terminate-instances --instance-ids "$instance_id"
            break
        else
            echo "Unexpected instance status: $instance_status"
            exit 1
        fi
    done
}

# Wait for Initialization
#
# Waits until the newly created EC2 instance changes its status
# from "initializing" to another state, signaling that initialization
# has completed.
#
# Usage:
#   wait_for_initialization
#
# Output:
#   No output, but pauses script execution until the EC2 instance has finished initializing.
#
# Example(s):
#   wait_for_initialization
wait_for_initialization() {
    instance_status="initializing"
    while [[ "$instance_status" == "initializing" || "$instance_status" == "null" ]]; do
        instance_status=$(aws ec2 describe-instance-status --instance-id "${INSTANCE_ID}" \
            | jq -r ".InstanceStatuses[0].InstanceStatus.Status")
        sleep 10
    done
}
