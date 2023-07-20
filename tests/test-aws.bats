#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export RUNNING_BATS_TEST=1

@test "list_instances function" {
	source "${BATS_TEST_DIRNAME}/../aws"
	run list_instances
	if [[ "${status}" -ne 0 ]]; then
		echo "Error: $output"
	fi
}
