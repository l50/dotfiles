#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export RUNNING_BATS_TEST=1

setup() {
	# Create a temp file with some JSON for testing
	TEST_JSON_FILE=$(mktemp)
	echo '{"key1":"value1","key2":"value2","arrayKey":["value3","value4"]}' >"$TEST_JSON_FILE"

	# Mock the environment variables
	export AUTHOR="cli"
	export REPO_NAME="cli"
	export INSTALL="false"
}

teardown() {
	# Delete the temp file
	rm "$TEST_JSON_FILE"
	# Clean up the environment variables
	unset AUTHOR
	unset REPO_NAME
	unset INSTALL
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

@test "fetchFromGithub with install=false" {
	source "${BATS_TEST_DIRNAME}/../bashutils"
	run fetchFromGithub "$AUTHOR" "$REPO_NAME" "$INSTALL"
	[ "$status" -eq 0 ]
	[[ $output == *"$REPO_NAME release from GitHub has been downloaded."* ]]
	[[ $output == *"Execute the binary by using the following path:"* ]]
}

@test "fetchFromGithub with install=true" {
	export INSTALL="true"
	source "${BATS_TEST_DIRNAME}/../bashutils"
	run fetchFromGithub "$AUTHOR" "$REPO_NAME" "$INSTALL"
	[ "$status" -eq 0 ]
	[[ $output == *"Installation of $REPO_NAME release from GitHub is complete."* ]]
	unset INSTALL
}
