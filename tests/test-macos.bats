#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export RUNNING_BATS_TEST=1

@test "largest_files function" {
	source "${BATS_TEST_DIRNAME}/../macos"
	run largest_files "$PWD"
	if [[ "${status}" -ne 0 ]]; then
		echo "Error: $output"
	fi
}

@test "gw" {
	source "${BATS_TEST_DIRNAME}/../macos"
	run gw
	if [[ "${status}" -ne 0 ]]; then
		echo "Error: $output"
	fi
}
