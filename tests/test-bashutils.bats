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
    run fetchFromGithub "CowDogMoo" "guacinator" "v1.0.0"
    [ "$status" -eq 0 ]
    [[ $output == *"Download of guacinator release v1.0.0 from GitHub is complete."* ]]
}

@test "fetchFromGithub with install=true" {
    export INSTALL="true"
    source "${BATS_TEST_DIRNAME}/../bashutils"
    run fetchFromGithub "cowdogmoo" "guacinator" "v1.0.0"
    [ "$status" -eq 0 ]
    [[ $output == *"Copied"*"$HOME/.local/bin/"* ]]
    unset INSTALL
}

