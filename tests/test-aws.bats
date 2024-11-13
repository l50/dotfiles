#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../aws'

export RUNNING_BATS_TEST=1

@test "list_running_instances function" {
	run list_running_instances
	if [[ "${status}" -ne 0 ]]; then
		echo "Error: $output"
	fi
}

@test "list_instance_profiles function" {
	run list_instance_profiles
	if [[ "${status}" -ne 0 ]]; then
		echo "Error: $output"
	fi
}

@test "delete_security_groups function" {
	# Mocking aws CLI responses
	aws_mock() {
		case "$*" in
		"ec2 describe-security-groups --filters Name=group-name,Values=test-sg --query SecurityGroups[*].GroupId --output text")
			echo "sg-12345678"
			;;
		"ec2 describe-security-groups --group-ids sg-12345678 --query SecurityGroups[0].IpPermissions --output json")
			echo "[]"
			;;
		"ec2 describe-security-groups --group-ids sg-12345678 --query SecurityGroups[0].IpPermissionsEgress --output json")
			echo "[]"
			;;
		"ec2 describe-network-interfaces --filters Name=group-id,Values=sg-12345678 --query NetworkInterfaces[*].NetworkInterfaceId --output text")
			echo ""
			;;
		"ec2 delete-security-group --group-id sg-12345678")
			return 0
			;;
		*)
			echo "Unexpected aws command: $*" >&2
			return 1
			;;
		esac
	}

	# Override aws command
	function aws() {
		aws_mock "$@"
	}

	run delete_security_groups "test-sg"
	assert_success
	assert_output --partial "Deleted security group with ID sg-12345678 on attempt 1."
}
