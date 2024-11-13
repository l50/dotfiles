#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../go'

export RUNNING_BATS_TEST=1

setup() {
	git config --global user.email "action@github.com"
	git config --global user.name "GitHub Action"
}

@test "pull_repos_function" {
	# Cleanup any existing repository
	rm -rf /tmp/testrepo*

	# Setup test repository
	mkdir -p /tmp/testrepo_origin

	# Create empty exclude file for test
	mkdir -p /tmp/testrepo_origin/.git/info && touch /tmp/testrepo_origin/.git/info/exclude

	# Populate exclude file
	cat >/tmp/testrepo_origin/.git/info/exclude <<EOF
# git ls-files --others --exclude-from=.git/info/exclude
# Lines that start with '#' are comments.
# For a project mostly in C, the following would be a good set of
# exclude patterns (uncomment them if you want to use them):
# *.[oa]
# *~
EOF

	# Initialize test repository
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

@test "get_exported_go_funcs_function" {
	run get_exported_go_funcs "$PWD"
	[ "$status" -eq 0 ]
}

@test "add_cobra_init_function" {
	source "${BATS_TEST_DIRNAME}/../go"
	run add_cobra_init "$PWD"
	[ "$status" -eq 0 ]
}

@test "import_path_function" {
	source "${BATS_TEST_DIRNAME}/../go"
	skip
	run import_path "$PWD"
	[ "$status" -eq 0 ]
}
