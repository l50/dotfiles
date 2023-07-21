#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export RUNNING_BATS_TEST=1

setup() {
	# Create a temp file with some JSON for testing
	TEST_JSON_FILE=$(mktemp)
	echo '{"key1":"value1","key2":"value2","arrayKey":["value3","value4"]}' >"$TEST_JSON_FILE"
}

teardown() {
	# Delete the temp file
	rm "$TEST_JSON_FILE"
}

@test "getJSONKeys function" {
	source "${BATS_TEST_DIRNAME}/../bashutils"
	run getJSONKeys "$TEST_JSON_FILE"
	[ "$status" -eq 0 ]
	[[ $output == *"key1"* ]]
	[[ $output == *"key2"* ]]
	[[ $output == *"arrayKey"* ]]
}

@test "getJSONValues function" {
	source "${BATS_TEST_DIRNAME}/../bashutils"
	run getJSONValues "$TEST_JSON_FILE"
	[ "$status" -eq 0 ]
	[[ $output == *"value1"* ]]
	[[ $output == *"value2"* ]]
	[[ $output == *"value3"* ]]
	[[ $output == *"value4"* ]]
}
