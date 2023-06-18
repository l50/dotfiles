#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export RUNNING_BATS_TEST=1

# Source zshrc for the setup_language function
# shellcheck source=/dev/null
source "${HOME}/.zshrc"

@test "pull_repos function" {
	source "${BATS_TEST_DIRNAME}/../go"
	run pull_repos "$PWD"
	if [[ "${status}" -ne 0 ]]; then
		echo "Error: $output"
	fi
}

@test "get_exported_go_funcs function" {
	source "${BATS_TEST_DIRNAME}/../go"
	run get_exported_go_funcs "$PWD"
	[ "$status" -eq 0 ]
}

@test "get_missing_tests function" {
	source "${BATS_TEST_DIRNAME}/../go"
	run get_missing_tests "$PWD"
	[ "$status" -eq 0 ]
}

@test "add_cobra_init function" {
	source "${BATS_TEST_DIRNAME}/../go"
	run add_cobra_init "$PWD"
	[ "$status" -eq 0 ]
}

@test "import_path function" {
	source "${BATS_TEST_DIRNAME}/../go"
	run import_path "$PWD"
	[ "$status" -eq 0 ]
}
