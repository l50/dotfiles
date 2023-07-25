#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export RUNNING_BATS_TEST=1

@test "pull_repos function" {
	# Cleanup any existing repository
	rm -rf /tmp/testrepo*

	# Setup test repository
	mkdir -p /tmp/testrepo_origin
	pushd /tmp/testrepo_origin || return 1
	git init
	echo "initial content" >testfile
	git add testfile
	git commit -m "Initial commit"
	popd || return 1

	# Clone test repository twice
	git clone /tmp/testrepo_origin /tmp/testrepo_clone1
	git clone /tmp/testrepo_origin /tmp/testrepo_clone2

	# Make a change in the first clone
	pushd /tmp/testrepo_clone1 || return 1
	git checkout -b testbranch
	echo "new content" >>testfile
	git add testfile
	git commit -m "New commit"
	git push origin testbranch
	popd || return 1

	# Run function on the second clone
	pushd /tmp/testrepo_clone2 || return 1
	source "${BATS_TEST_DIRNAME}/../go"
	git fetch # Fetch branches from remote
	git checkout testbranch
	run pull_repos "$PWD"
	[[ "${status}" -eq 0 ]] || echo "Error: $output"
	[[ "$output" == *"All repositories successfully updated."* ]]
	[[ "$(git log -1 --pretty=%B)" == "New commit" ]]
	popd || return 1

	# Cleanup
	rm -rf /tmp/testrepo_origin /tmp/testrepo_clone1 /tmp/testrepo_clone2
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
