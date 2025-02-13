#!/bin/bash

# Wait for Command
#
# Waits for a previously run command to complete.
#
# Usage:
#   wait_for_command [command_id]
#
# Output:
#   No output, but pauses script execution until the specified command has finished running.
#
# Example(s):
#   wait_for_command "0abcd1234efgh5678"
wait_for_command() {
    local command_id=$1
    local command_status

    while true; do
        command_status=$(aws ssm list-command-invocations --command-id "$command_id" --details --query 'CommandInvocations[0].Status' --output text)

        if [ -z "$command_status" ]; then
            echo "Failed to fetch command status."
            exit 1
        elif [ "$command_status" = "Success" ]; then
            break
        elif [ "$command_status" = "Failed" ]; then
            echo "Command execution failed."
            exit 1
        fi

        echo "Waiting for command to finish..."
        sleep 5
    done
}
