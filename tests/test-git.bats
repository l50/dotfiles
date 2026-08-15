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
	unset STUB_BRANCH_PUSH_REMOTE STUB_PUSH_DEFAULT
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

# pull_repos tests

@test "pull_repos fails when fd is not installed" {
	# Mock command to simulate fd not being installed
	# shellcheck disable=SC2317,SC2329
	command() {
		# shellcheck disable=SC2317
		if [[ "$2" == "fd" ]]; then
			return 1
		fi
		# shellcheck disable=SC2317
		builtin command "$@"
	}
	export -f command

	run pull_repos

	assert_failure
	assert_output --partial "error: fd is not installed"
	assert_output --partial "https://github.com/sharkdp/fd"
}

@test "pull_repos updates repositories successfully" {
	# Use isolated git config to avoid polluting user's ~/.gitconfig
	export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/.gitconfig"
	git config --global user.email "action@github.com"
	git config --global user.name "GitHub Action"

	# Setup test repository
	mkdir -p "$BATS_TEST_TMPDIR/testrepo_origin/.git/info"

	# Initialize test repository
	pushd "$BATS_TEST_TMPDIR/testrepo_origin" >/dev/null
	git init
	touch .git/info/exclude
	echo "initial content" >testfile
	git add testfile
	git commit -m "Initial commit"
	popd >/dev/null

	# Clone test repository twice
	git clone "$BATS_TEST_TMPDIR/testrepo_origin" "$BATS_TEST_TMPDIR/testrepo_clone1"
	git clone "$BATS_TEST_TMPDIR/testrepo_origin" "$BATS_TEST_TMPDIR/testrepo_clone2"

	# Make changes in first clone
	pushd "$BATS_TEST_TMPDIR/testrepo_clone1" >/dev/null
	git checkout -b testbranch
	echo "new content" >>testfile
	git add testfile
	git commit -m "New commit"
	git push origin testbranch
	popd >/dev/null

	# Test pull_repos on second clone
	pushd "$BATS_TEST_TMPDIR/testrepo_clone2" >/dev/null
	git fetch
	git checkout testbranch

	# Mock fd to simulate finding .git directories and running git pull
	# fd -H -t d '^\.git$' DIR -x git -C '{//}' pull --ff-only
	# shellcheck disable=SC2317,SC2329
	fd() {
		# shellcheck disable=SC2317
		local search_dir
		# Parse args: -H -t d '^\.git$' DIR -x git -C '{//}' pull --ff-only
		# The directory is the 4th argument (after -H -t d pattern)
		# shellcheck disable=SC2317
		search_dir="$4"
		# Run git pull in the search directory
		# shellcheck disable=SC2317
		git -C "$search_dir" pull --ff-only
	}
	export -f fd

	run pull_repos "$PWD"

	assert_success
	assert_output --partial "All repositories successfully updated."
	assert [ "$(git log -1 --pretty=%B)" = "New commit" ]
	popd >/dev/null
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

# check_squad tests

@test "check_squad succeeds when squad is installed" {
	# Mock command function
	# shellcheck disable=SC2317,SC2329
	command() {
		# shellcheck disable=SC2317
		if [[ "$2" == "squad" ]]; then
			# shellcheck disable=SC2317
			return 0
		fi
		# shellcheck disable=SC2317
		builtin command "$@"
	}
	export -f command

	run check_squad

	assert_success
}

@test "check_squad fails when squad is not installed" {
	# Mock command function
	# shellcheck disable=SC2317,SC2329
	command() {
		# shellcheck disable=SC2317
		if [[ "$2" == "squad" ]]; then
			# shellcheck disable=SC2317
			return 1
		fi
		# shellcheck disable=SC2317
		builtin command "$@"
	}
	export -f command

	run check_squad

	assert_failure
	assert_output --partial "error: squad is not installed"
	assert_output --partial "install it from: https://github.com/CowDogMoo/squad"
}

@test "squad_gen fails for unknown pattern" {
	run squad_gen no-such-pattern < /dev/null

	assert_failure
	assert_output --partial "error: pattern not found"
}

# fabric_commit tests

# Stubs a fabric pattern filter under a throwaway HOME and mocks every command the
# fabric_* helpers shell out to, so they can run without touching the real repo or
# GitHub. $1 is the pattern directory (commit or pr), $2 the text fabric should emit.
# Each git and gh invocation is appended to $GIT_LOG / $GH_LOG so tests can assert on
# what was (and was not) run.
stub_fabric() {
	export FABRIC_MSG="$2"
	export HOME="$BATS_TEST_TMPDIR/home"
	export GIT_LOG="$BATS_TEST_TMPDIR/git.log"
	export GH_LOG="$BATS_TEST_TMPDIR/gh.log"

	mkdir -p "$HOME/.config/fabric/patterns/$1"
	printf '#!/usr/bin/env bash\ncat\n' > "$HOME/.config/fabric/patterns/$1/filter.sh"
	chmod +x "$HOME/.config/fabric/patterns/$1/filter.sh"
	: > "$GIT_LOG"
	: > "$GH_LOG"

	check_fabric() { return 0; }
	fabric() {
		cat > /dev/null
		printf '%s' "$FABRIC_MSG"
	}
	gh() {
		echo "gh $*" >> "$GH_LOG"
		case "$*" in
			"repo view"*) printf '%s\n' "l50/dotfiles" ;;
			"pr view"*baseRefName*) printf '%s\n' "main" ;;
			# No existing PR, so fabric_pr takes the create path.
			"pr view"*) return 1 ;;
			"pr create"*) printf '%s\n' "https://github.com/l50/dotfiles/pull/1" ;;
		esac
		return 0
	}
	git() {
		echo "git $*" >> "$GIT_LOG"
		local entry
		case "$1" in
			# STUB_BIG_DIFF stands in for a diff too large to pipe into fabric, so the
			# raw form has to outgrow the byte cap while --stat stays small.
			ds | diff)
				if [[ -n "${STUB_BIG_DIFF:-}" && "$*" != *--stat* ]]; then
					head -c 500000 /dev/zero | tr '\0' 'x'
				else
					printf 'diff --git a/x b/x\n'
				fi
				;;
			log) printf '%s\n' "abc1234 feat: a commit" ;;
			commit) cat > /dev/null ;;
			branch) printf '%s\n' "topic" ;;
			# STUB_REMOTES is a space-separated list of <name>=<url> pairs, so a test can
			# describe a fork layout without creating real remotes.
			remote)
				if [[ "$2" == "get-url" ]]; then
					for entry in ${STUB_REMOTES:-}; do
						if [[ "${entry%%=*}" == "$3" ]]; then
							printf '%s\n' "${entry#*=}"
							return 0
						fi
					done
					return 1
				fi
				for entry in ${STUB_REMOTES:-}; do
					printf '%s\n' "${entry%%=*}"
				done
				;;
			# git rev-parse --verify --quiet <ref>, so the ref is $4. Refs named in
			# STUB_MISSING_REFS stand in for a remote branch that was never fetched.
			rev-parse)
				case " ${STUB_MISSING_REFS:-} " in
					*" $4 "*) return 1 ;;
				esac
				;;
			config)
				case "$*" in
					*pushRemote) printf '%s' "${STUB_BRANCH_PUSH_REMOTE:-}" ;;
					*remote.pushDefault) printf '%s' "${STUB_PUSH_DEFAULT:-}" ;;
				esac
				;;
			# A failing fetch stands in for an offline run, where the base cannot be
			# refreshed but the stale copy is still diffable.
			fetch) return "${STUB_FETCH_STATUS:-0}" ;;
		esac
		return 0
	}
	export -f check_fabric fabric gh git
}

stub_fabric_commit() { stub_fabric commit "$1"; }

stub_fabric_pr() { stub_fabric pr "$1"; }

# Point the mocked git config at a branch pushRemote / remote.pushDefault of $1, so
# git_push_remote resolves to it. Wrapped in functions because a bare export inside a
# @test reads as a subshell-local modification to shellcheck.
stub_branch_push_remote() { export STUB_BRANCH_PUSH_REMOTE="$1"; }

stub_big_diff() { export STUB_BIG_DIFF=1; }

stub_push_default() { export STUB_PUSH_DEFAULT="$1"; }

# Describe the repo's remotes as "<name>=<url>" pairs, so git_remote_for_repo can map
# gh's base repo onto one of them.
stub_remotes() { export STUB_REMOTES="$*"; }

# Mark remote-tracking refs as never fetched, so rev-parse --verify fails on them.
stub_missing_refs() { export STUB_MISSING_REFS="$*"; }

# Make "git fetch" fail, so the base branch cannot be refreshed.
stub_failing_fetch() { export STUB_FETCH_STATUS=1; }

@test "fabric_commit aborts without committing when fabric returns an empty message" {
	stub_fabric_commit "   "

	run fabric_commit

	assert_failure
	assert_output --partial "commit message is empty"
	refute grep -q "git commit" "$GIT_LOG"
	refute grep -q "git push" "$GIT_LOG"
}

@test "fabric_commit pushes with an explicit refspec so a renamed upstream still works" {
	stub_fabric_commit "fix: correct the thing"

	run fabric_commit

	assert_success
	assert grep -q "git commit --cleanup=verbatim -F -" "$GIT_LOG"
	# A bare "git push" breaks when the local branch tracks a differently-named
	# upstream, so the refspec must be explicit.
	assert grep -q "git push -u origin HEAD" "$GIT_LOG"
}

@test "fabric_commit pushes to the branch's pushRemote instead of origin" {
	stub_fabric_commit "fix: correct the thing"
	# In a fork, origin is the read-only upstream and pushing there 403s.
	stub_branch_push_remote fork

	run fabric_commit

	assert_success
	assert grep -q "git push -u fork HEAD" "$GIT_LOG"
	refute grep -q "git push -u origin HEAD" "$GIT_LOG"
}

@test "fabric_commit falls back to remote.pushDefault when no branch pushRemote" {
	stub_fabric_commit "fix: correct the thing"
	stub_push_default fork

	run fabric_commit

	assert_success
	assert grep -q "git push -u fork HEAD" "$GIT_LOG"
}

@test "fabric_pr diffs against origin's base branch even when pushing elsewhere" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	stub_branch_push_remote fork

	run fabric_pr

	assert_success
	# The PR is opened against origin and baseRefName names a branch there, so the diff
	# base stays origin/<base>. A fork's own copy is usually stale and often unfetched,
	# which would pad the diff or abort on an unknown revision.
	assert grep -q "git diff origin/main\.\.\.HEAD" "$GIT_LOG"
	refute grep -q "git diff fork/main" "$GIT_LOG"
	# The push still honours the configured remote.
	assert grep -q "git push -u fork HEAD" "$GIT_LOG"
}

@test "fabric_pr diffs against the fork when gh opens PRs there" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	stub_branch_push_remote fork
	# "gh repo set-default" can aim PRs at the fork, which is what the stubbed
	# "gh repo view" reports. Then origin is the stale copy, and diffing it would pad
	# the PR body with commits the PR does not contain.
	stub_remotes "origin=https://github.com/upstream/dotfiles.git" \
		"fork=https://github.com/l50/dotfiles.git"

	run fabric_pr

	assert_success
	assert grep -q "git diff fork/main\.\.\.HEAD" "$GIT_LOG"
	refute grep -q "git diff origin/main" "$GIT_LOG"
}

@test "fabric_pr summarises with log and diffstat when the raw diff is too large to send" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	# A fork sync carries thousands of commits, and piping that diff whole overruns
	# fabric's context, so the body degrades to the commit list plus a diffstat rather
	# than failing or truncating mid-hunk.
	stub_big_diff

	run fabric_pr

	assert_success
	assert grep -q "git log --oneline origin/main\.\.HEAD" "$GIT_LOG"
	assert grep -q "git diff --stat origin/main\.\.\.HEAD" "$GIT_LOG"
}

@test "fabric_pr falls back to origin when the base repo's remote branch is unfetched" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	stub_remotes "origin=https://github.com/upstream/dotfiles.git" \
		"fork=https://github.com/l50/dotfiles.git"
	# A missing revision aborts the diff outright, so a never-fetched fork branch has to
	# degrade to origin rather than take the whole PR down.
	stub_missing_refs "fork/main"

	run fabric_pr

	assert_success
	assert grep -q "git diff origin/main\.\.\.HEAD" "$GIT_LOG"
	refute grep -q "git diff fork/main" "$GIT_LOG"
}

@test "fabric_pr refreshes the base branch it diffs against" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	stub_remotes "origin=https://github.com/upstream/dotfiles.git" \
		"fork=https://github.com/l50/dotfiles.git"

	run fabric_pr

	assert_success
	# Pushing a feature branch never moves the base's remote-tracking ref, so without
	# this fetch the diff replays commits already merged upstream. It has to target the
	# same remote the diff uses, or the refresh lands on a ref nothing reads.
	assert grep -q "git fetch --quiet fork main" "$GIT_LOG"
	assert grep -q "git diff fork/main\.\.\.HEAD" "$GIT_LOG"
}

@test "fabric_pr warns but still opens the PR when the base cannot be refreshed" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	# Offline, the stale base is still diffable, so a failed refresh degrades to a
	# warning instead of taking the PR down.
	stub_failing_fetch

	run fabric_pr

	assert_success
	assert_output --partial "could not refresh origin/main"
	assert grep -q "git diff origin/main\.\.\.HEAD" "$GIT_LOG"
	assert grep -q "gh pr create" "$GH_LOG"
}

@test "git_remote_for_repo falls back to origin when no remote matches" {
	stub_fabric_pr "unused"
	stub_remotes "origin=https://github.com/upstream/dotfiles.git"

	run git_remote_for_repo "l50/dotfiles"

	assert_success
	assert_output "origin"
}

@test "git_remote_for_repo matches an ssh remote URL" {
	stub_fabric_pr "unused"
	stub_remotes "origin=https://github.com/upstream/dotfiles.git" \
		"fork=git@github.com:l50/dotfiles.git"

	run git_remote_for_repo "l50/dotfiles"

	assert_success
	assert_output "fork"
}
