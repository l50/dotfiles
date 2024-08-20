# Find Default Subnet
#
# Finds the default subnet ID.
#
# Usage:
#   find_default_subnet
#
# Output:
#   Outputs the default subnet ID.
#
# Example(s):
#   find_default_subnet
function find_default_subnet() {
    aws ec2 describe-subnets \
        --filters "Name=default-for-az,Values=true" \
        --output text --query 'Subnets[0].SubnetId'
}

# Find Default VPC
#
# Finds the default VPC ID.
#
# Usage:
#   find_default_vpc
#
# Output:
#   Outputs the default VPC ID.
#
# Example(s):
#   find_default_vpc
find_default_vpc() {
  aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --output text --query 'Vpcs[0].VpcId'
}

# Get Subnet Route Table
#
# Retrieves the route table ID associated with a specific subnet.
# It requires the subnet ID as input and returns the route table ID.
#
# Usage:
#   get_subnet_route_table "subnet-id"
#   where "subnet-id" is the ID of the subnet for which you want to get the associated route table.
#
# Output:
#   Outputs the route table ID associated with the specified subnet.
#   If the subnet ID is not provided or the command fails, an error message is shown.
#
# Example(s):
#   get_subnet_route_table "subnet-1234abcd"
get_subnet_route_table() {
    local subnet_id=$1
    local route_table_id

    if [[ -z "$subnet_id" ]]; then
        echo "No subnet ID provided. Usage: get_subnet_route_table <subnet-id>"
        return 1
    fi

    route_table_id=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$subnet_id" \
        --query "RouteTables[].RouteTableId" \
        --output text)

    # Check if the AWS command was successful
    if [ $? -eq 0 ]; then
        echo "$route_table_id"
    else
        echo "Error fetching route table for subnet $subnet_id"
        return 1
    fi
}

# Is Subnet Public
#
# Determines whether a subnet is publicly routable based on the route table associated with it.
# It checks if there's a route to an Internet Gateway in the route table.
#
# Usage:
#   is_subnet_public "subnet-id"
#   where "subnet-id" is the ID of the subnet you want to check.
#
# Output:
#   Outputs "True" if the subnet has a route to an Internet Gateway, indicating it's public.
#   Outputs "False" if there's no such route, indicating the subnet is private.
#
# Example(s):
#   is_subnet_public "subnet-1234abcd"
is_subnet_public() {
    local subnet_id=$1
    local route_table_id
    local igw_route
    local result="False"

    if [[ -z "$subnet_id" ]]; then
        echo "No subnet ID provided. Usage: is_subnet_public <subnet-id>"
        return 1
    fi

    route_table_id=$(get_subnet_route_table "$subnet_id")
    if [[ -z "$route_table_id" || "$route_table_id" == "None" ]]; then
        echo "False"
        return
    fi

    igw_route=$(aws ec2 describe-route-tables --route-table-ids "$route_table_id" --query "RouteTables[*].Routes[?GatewayId && GatewayId!='local' && starts_with(GatewayId, 'igw-')]" --output text)

    if [[ ! -z "$igw_route" ]]; then
        result="True"
    fi

    echo "$result"
}

# List VPCs
#
# Lists all VPCs with their ID, Name (if tagged), and State.
#
# Usage:
#   list_vpcs
#
# Output:
#   Outputs a table of VPCs with their ID, Name, and State.
#
# Example(s):
#   list_vpcs
list_vpcs() {
    echo "Listing VPCs..."
    aws ec2 describe-vpcs --query "Vpcs[].{ID:VpcId, Name:Tags[?Key==`Name`]|[0].Value, State:State}" --output table
}

# List VPC Subnets
#
# Lists all subnets within a specified VPC and determines if each subnet is public or private.
# It requires the VPC ID as input and prints each subnet's ID along with its public/private status.
#
# Usage:
#   list_vpc_subnets "vpc-id"
#   where "vpc-id" is the ID of the VPC for which you want to list the subnets.
#
# Output:
#   Outputs a list of subnets with their IDs and whether they are public or private.
#
# Example(s):
#   list_vpc_subnets "vpc-1234abcd"
list_vpc_subnets() {
    local vpc_id=$1
    local subnets
    local is_public

    if [[ -z "$vpc_id" ]]; then
        echo "No VPC ID provided. Usage: list_vpc_subnets <vpc-id>"
        return 1
    fi

    echo "Getting subnets associated with $vpc_id..."
    subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[].SubnetId" --output text | tr '\t' '\n')

    # Split the subnets into an array manually
    local subnet_array=()
    while IFS= read -r line; do
        subnet_array+=("$line")
    done <<< "$subnets"

    for subnet_id in "${subnet_array[@]}"; do
        if [[ -n "$subnet_id" ]]; then  # Check if subnet_id is not empty
            is_public=$(is_subnet_public "$subnet_id")
            if [[ $is_public == "True" ]]; then
                echo "$subnet_id is Public"
            else
                echo "$subnet_id is Private"
            fi
        fi
    done
}
