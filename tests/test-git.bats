#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../git.sh'

bats_require_minimum_version 1.5.0

export RUNNING_BATS_TEST=1

setup() {
	# Mock git and gh commands will be defined per test
	export TEST_BRANCH="feature-branch"
	export TEST_REPO="dreadnode/warpgate-templates"
	export TEST_RUN_ID="20865803201"
	export TEST_WORKFLOW="Build and Push Templates"
}

teardown() {
	# Clean up any mock functions
	unset -f gh git 2>/dev/null
	unset TEST_BRANCH TEST_REPO TEST_RUN_ID TEST_WORKFLOW
}

# gh_cancel tests

@test "gh_cancel with run ID calls gh run cancel with ID" {
	# Mock gh command
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		echo "$@" >"$BATS_TEST_TMPDIR/gh_output"
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	run gh_cancel "$TEST_RUN_ID"

	assert_success
	assert [ -f "$BATS_TEST_TMPDIR/gh_output" ]
	assert [ "$(cat "$BATS_TEST_TMPDIR/gh_output")" = "run cancel $TEST_RUN_ID" ]
}

@test "gh_cancel without run ID cancels most recent run" {
	# Mock gh command
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		if [[ "$1" == "run" && "$2" == "list" ]]; then
			# When --jq is present, gh processes the JSON and returns the value
			# shellcheck disable=SC2317
			if [[ "$*" == *"--jq"* ]]; then
				# shellcheck disable=SC2317
				echo "12345"
			else
				# shellcheck disable=SC2317
				echo "[{\"databaseId\": 12345}]"
			fi
		elif [[ "$1" == "run" && "$2" == "cancel" ]]; then
			# shellcheck disable=SC2317
			echo "run cancel $3" >"$BATS_TEST_TMPDIR/gh_output"
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	run gh_cancel

	assert_success
	assert_output --partial "Canceling most recent run: 12345"
	assert [ -f "$BATS_TEST_TMPDIR/gh_output" ]
	assert [ "$(cat "$BATS_TEST_TMPDIR/gh_output")" = "run cancel 12345" ]
}

@test "gh_cancel without run ID fails when no runs found" {
	# Mock gh command that returns empty list
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		if [[ "$1" == "run" && "$2" == "list" ]]; then
			# When --jq is present and list is empty, return empty string
			# shellcheck disable=SC2317
			if [[ "$*" == *"--jq"* ]]; then
				# shellcheck disable=SC2317
				echo ""
			else
				# shellcheck disable=SC2317
				echo "[]"
			fi
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	run gh_cancel

	assert_failure
	assert_output --partial "No runs found"
}

# gh_trigger tests

@test "gh_trigger without workflow name shows usage" {
	run gh_trigger

	assert_failure
	assert_output "Usage: gh_trigger WORKFLOW_NAME"
}

@test "gh_trigger with workflow name triggers workflow on current branch" {
	# Mock git command
	# shellcheck disable=SC2317,SC2329
	git() {
		# shellcheck disable=SC2317
		if [[ "$1" == "branch" && "$2" == "--show-current" ]]; then
			# shellcheck disable=SC2317
			echo "$TEST_BRANCH"
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f git

	# Mock gh command
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		if [[ "$1" == "repo" && "$2" == "view" ]]; then
			# When --jq is present, return just the value
			# shellcheck disable=SC2317
			if [[ "$*" == *"--jq"* ]]; then
				# shellcheck disable=SC2317
				echo "$TEST_REPO"
			else
				# shellcheck disable=SC2317
				echo "{\"nameWithOwner\": \"$TEST_REPO\"}"
			fi
		elif [[ "$1" == "workflow" && "$2" == "run" ]]; then
			# shellcheck disable=SC2317
			echo "$@" >"$BATS_TEST_TMPDIR/gh_output"
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	run gh_trigger "$TEST_WORKFLOW"

	assert_success
	assert_output --partial "Triggering workflow '$TEST_WORKFLOW' on branch '$TEST_BRANCH' in repo '$TEST_REPO'"
	assert [ -f "$BATS_TEST_TMPDIR/gh_output" ]
	local output
	output=$(cat "$BATS_TEST_TMPDIR/gh_output")
	[[ "$output" == *"workflow run"* ]]
	[[ "$output" == *"$TEST_WORKFLOW"* ]]
	[[ "$output" == *"--repo"* ]]
	[[ "$output" == *"$TEST_REPO"* ]]
	[[ "$output" == *"--ref"* ]]
	[[ "$output" == *"$TEST_BRANCH"* ]]
}

# gh_runs tests

@test "gh_runs without workflow name lists all runs" {
	# Mock gh command
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		echo "$@" >"$BATS_TEST_TMPDIR/gh_output"
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	run gh_runs

	assert_success
	assert [ -f "$BATS_TEST_TMPDIR/gh_output" ]
	assert [ "$(cat "$BATS_TEST_TMPDIR/gh_output")" = "run list" ]
}

@test "gh_runs with workflow name filters by workflow" {
	# Mock gh command
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		echo "$@" >"$BATS_TEST_TMPDIR/gh_output"
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	run gh_runs "$TEST_WORKFLOW"

	assert_success
	assert [ -f "$BATS_TEST_TMPDIR/gh_output" ]
	assert [ "$(cat "$BATS_TEST_TMPDIR/gh_output")" = "run list --workflow=$TEST_WORKFLOW" ]
}

# gh_restart tests

@test "gh_restart without workflow name shows usage" {
	run gh_restart

	assert_failure
	assert_output "Usage: gh_restart WORKFLOW_NAME"
}

@test "gh_restart cancels most recent run and triggers new one" {
	# Mock git command
	# shellcheck disable=SC2317,SC2329
	git() {
		# shellcheck disable=SC2317
		if [[ "$1" == "branch" && "$2" == "--show-current" ]]; then
			# shellcheck disable=SC2317
			echo "$TEST_BRANCH"
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f git

	# Mock gh command
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		if [[ "$1" == "run" && "$2" == "list" ]]; then
			# When --jq is present, return just the value
			# shellcheck disable=SC2317
			if [[ "$*" == *"--jq"* ]]; then
				# shellcheck disable=SC2317
				echo "12345"
			else
				# shellcheck disable=SC2317
				echo "[{\"databaseId\": 12345}]"
			fi
		elif [[ "$1" == "run" && "$2" == "cancel" ]]; then
			# shellcheck disable=SC2317
			echo "Canceling: $3"
		elif [[ "$1" == "repo" && "$2" == "view" ]]; then
			# When --jq is present, return just the value
			# shellcheck disable=SC2317
			if [[ "$*" == *"--jq"* ]]; then
				# shellcheck disable=SC2317
				echo "$TEST_REPO"
			else
				# shellcheck disable=SC2317
				echo "{\"nameWithOwner\": \"$TEST_REPO\"}"
			fi
		elif [[ "$1" == "workflow" && "$2" == "run" ]]; then
			# shellcheck disable=SC2317
			echo "Triggering workflow"
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	# Mock sleep to avoid delays in tests
	# shellcheck disable=SC2317,SC2329
	sleep() {
		# shellcheck disable=SC2317
		return 0
	}
	export -f sleep

	run gh_restart "$TEST_WORKFLOW"

	assert_success
	assert_output --partial "Looking for most recent run"
	assert_output --partial "Canceling run: 12345"
	assert_output --partial "Triggering workflow '$TEST_WORKFLOW'"
}

@test "gh_restart triggers workflow when no previous run exists" {
	# Mock git command
	# shellcheck disable=SC2317,SC2329
	git() {
		# shellcheck disable=SC2317
		if [[ "$1" == "branch" && "$2" == "--show-current" ]]; then
			# shellcheck disable=SC2317
			echo "$TEST_BRANCH"
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f git

	# Mock gh command
	# shellcheck disable=SC2317,SC2329
	gh() {
		# shellcheck disable=SC2317
		if [[ "$1" == "run" && "$2" == "list" ]]; then
			# When --jq is present and list is empty, return empty string
			# shellcheck disable=SC2317
			if [[ "$*" == *"--jq"* ]]; then
				# shellcheck disable=SC2317
				echo ""
			else
				# shellcheck disable=SC2317
				echo "[]"
			fi
		elif [[ "$1" == "repo" && "$2" == "view" ]]; then
			# When --jq is present, return just the value
			# shellcheck disable=SC2317
			if [[ "$*" == *"--jq"* ]]; then
				# shellcheck disable=SC2317
				echo "$TEST_REPO"
			else
				# shellcheck disable=SC2317
				echo "{\"nameWithOwner\": \"$TEST_REPO\"}"
			fi
		elif [[ "$1" == "workflow" && "$2" == "run" ]]; then
			# shellcheck disable=SC2317
			echo "Triggering workflow"
		fi
		# shellcheck disable=SC2317
		return 0
	}
	export -f gh

	run gh_restart "$TEST_WORKFLOW"

	assert_success
	assert_output --partial "Looking for most recent run"
	refute_output --partial "Canceling run"
	assert_output --partial "Triggering workflow '$TEST_WORKFLOW'"
}

# check_fabric tests

@test "check_fabric succeeds when fabric is installed" {
	# Mock command function
	# shellcheck disable=SC2317,SC2329
	command() {
		# shellcheck disable=SC2317
		if [[ "$2" == "fabric" ]]; then
			# shellcheck disable=SC2317
			return 0
		fi
		# shellcheck disable=SC2317
		builtin command "$@"
	}
	export -f command

	run check_fabric

	assert_success
}

@test "check_fabric fails when fabric is not installed" {
	# Mock command function
	# shellcheck disable=SC2317,SC2329
	command() {
		# shellcheck disable=SC2317
		if [[ "$2" == "fabric" ]]; then
			# shellcheck disable=SC2317
			return 1
		fi
		# shellcheck disable=SC2317
		builtin command "$@"
	}
	export -f command

	run check_fabric

	assert_failure
	assert_output --partial "error: fabric is not installed"
	assert_output --partial "install it from: https://github.com/danielmiessler/fabric"
}
