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
			# STUB_DEFAULT_BRANCH stands in for a repo that does not name its default
			# branch main, which is the base a PR gets when no open PR pins one.
			"repo view"*defaultBranchRef*) printf '%s\n' "${STUB_DEFAULT_BRANCH:-main}" ;;
			"repo view"*) printf '%s\n' "l50/dotfiles" ;;
			# Only an open PR reports a base; otherwise gh exits 0 with no output and
			# the caller has to resolve the default branch itself.
			"pr view"*baseRefName*)
				if [[ "${STUB_PR_STATE:-}" == "OPEN" ]]; then
					printf '%s\n' "main"
				fi
				;;
			# gh pr view resolves closed/merged PRs too, but the OPEN filter in
			# the --jq expression drops them: gh still exits 0, just with empty
			# output. STUB_PR_STATE picks the scenario; unset means no PR.
			"pr view"*url*)
				[[ -n "${STUB_PR_STATE:-}" ]] || return 1
				if [[ "$STUB_PR_STATE" == "OPEN" ]]; then
					printf '%s\n' "https://github.com/l50/dotfiles/pull/1"
				fi
				;;
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

# State of the branch's existing PR as gh pr view reports it (OPEN, CLOSED,
# MERGED). Leave unset for a branch with no PR at all.
stub_pr_state() { export STUB_PR_STATE="$1"; }

# Name the default branch of the repo gh opens PRs against, for repos that do
# not call it main.
stub_default_branch() { export STUB_DEFAULT_BRANCH="$1"; }

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

@test "fabric_pr targets the default branch when the repo does not call it main" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	# With no open PR to pin a base, the base is the repo's default branch. Assuming
	# main names a revision that does not exist on forks like mealie-next, and the
	# diff aborts before the PR is ever written.
	stub_default_branch "mealie-next"

	run fabric_pr

	assert_success
	assert grep -q "git diff origin/mealie-next\.\.\.HEAD" "$GIT_LOG"
	refute grep -q "git diff origin/main" "$GIT_LOG"
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

@test "fabric_pr aborts before pushing when the model omits the title line" {
	# Opening with the body means the first heading lands in the title slot, which would
	# ship a PR titled "## What this PR does" and leave the body a heading short.
	stub_fabric_pr "## What this PR does / why we need it:

Body of the PR."

	run fabric_pr

	assert_failure
	assert_output --partial "PR title is a markdown heading"
	refute grep -q "git push" "$GIT_LOG"
	refute grep -q "pr create" "$GH_LOG"
}

@test "fabric_pr updates the PR in place when the branch has an open PR" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	stub_pr_state OPEN

	run fabric_pr

	assert_success
	assert_output --partial "Updated existing pull request"
	assert grep -q "gh pr edit" "$GH_LOG"
	refute grep -q "gh pr create" "$GH_LOG"
}

@test "fabric_pr opens a new PR when the branch's previous PR was closed" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	# gh pr view resolves the branch to its most relevant PR even after that PR
	# was closed unmerged (e.g. by a branch deletion). Taking the edit path then
	# rewrites the dead PR forever and the branch never gets a new one.
	stub_pr_state CLOSED

	run fabric_pr

	assert_success
	assert grep -q "gh pr create" "$GH_LOG"
	refute grep -q "gh pr edit" "$GH_LOG"
}

@test "fabric_pr does not edit an already-merged PR" {
	stub_fabric_pr "feat: add a thing

Body of the PR."
	stub_pr_state MERGED

	run fabric_pr

	assert_success
	assert grep -q "gh pr create" "$GH_LOG"
	refute grep -q "gh pr edit" "$GH_LOG"
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

# squad integration tests

# Layers the squad-side pieces on top of stub_fabric's git/gh mocks: a
# throwaway patterns hub, a text-transform agent dir, and a squad function
# that emits $2. $1 is the pattern directory (commit or pr). The result
# exercises the real squad_gen pipeline (pattern lookup, filter, sentinel
# guard) end to end without the squad CLI.
stub_squad() {
	stub_fabric "$1" ""
	export SQUAD_MSG="$2"
	export FABRIC_PATTERNS_HUB="$BATS_TEST_TMPDIR/hub"
	export SQUAD_AGENTS_REPO="$BATS_TEST_TMPDIR/agents"

	mkdir -p "$FABRIC_PATTERNS_HUB/patterns/$1" "$SQUAD_AGENTS_REPO/text-transform"
	echo "transform prompt" > "$FABRIC_PATTERNS_HUB/patterns/$1/system.md"
	printf '#!/usr/bin/env bash\ncat\n' > "$FABRIC_PATTERNS_HUB/patterns/$1/filter.sh"
	chmod +x "$FABRIC_PATTERNS_HUB/patterns/$1/filter.sh"

	check_squad() { return 0; }
	squad() {
		cat > /dev/null
		printf '%s\n' "$SQUAD_MSG"
	}
	export -f check_squad squad
}

# git_required_pr_headings tests

# Build a real repo (not the mocked git the fabric_* tests use) with a PR template,
# since the parser reads a file off the worktree root.
stub_pr_template() {
	cd "$BATS_TEST_TMPDIR" || return 1
	git init --quiet . 2> /dev/null
	mkdir -p .github
	cat > .github/pull_request_template.md
}

@test "git_required_pr_headings lists only the headings marked required" {
	stub_pr_template << 'EOF'
## What this PR does / why we need it:

_(REQUIRED)_

## Testing

_(fill-in or delete this section)_

## AI / LLM Assistance

_(REQUIRED)_
EOF

	run git_required_pr_headings

	assert_success
	# Order matters: the generated body has to present them the way the template does.
	assert_equal "$output" "## What this PR does / why we need it:
## AI / LLM Assistance"
}

@test "git_required_pr_headings ignores a required marker with no heading above it" {
	# A marker under an already-claimed heading belongs to no heading, and emitting a
	# stray blank would make squad_pr export an empty required heading.
	stub_pr_template << 'EOF'
## What this PR does / why we need it:

_(REQUIRED)_

_(REQUIRED)_
EOF

	run git_required_pr_headings

	assert_success
	assert_equal "$output" "## What this PR does / why we need it:"
}

@test "git_required_pr_headings is silent when the repo ships no template" {
	cd "$BATS_TEST_TMPDIR" || return 1
	git init --quiet . 2> /dev/null

	run git_required_pr_headings

	assert_success
	assert_output ""
}

@test "squad_gen rejects the NO INPUT sentinel" {
	stub_squad commit "NO INPUT"

	run squad_gen commit <<< "diff --git a/foo b/foo"

	assert_failure
	assert_output --partial "error: squad returned the NO INPUT sentinel"
}

@test "squad_gen rejects the sentinel even when wrapped in prose" {
	# Live runs showed the model padding the sentinel with an explanation, which
	# slipped past an exact whole-output match.
	stub_squad commit "I need the git diff to work from — the input was empty.

NO INPUT"

	run squad_gen commit <<< "diff --git a/foo b/foo"

	assert_failure
	assert_output --partial "error: squad returned the NO INPUT sentinel"
}

@test "squad_gen passes through normal output" {
	stub_squad commit "feat: add foo"

	run squad_gen commit <<< "diff --git a/foo b/foo"

	assert_success
	assert_output "feat: add foo"
}

@test "squad_gen keeps a message that merely mentions NO INPUT" {
	stub_squad commit "fix: reject a literal NO INPUT commit message"

	run squad_gen commit <<< "diff --git a/foo b/foo"

	assert_success
	assert_output "fix: reject a literal NO INPUT commit message"
}

@test "squad_commit aborts without committing when squad returns the sentinel" {
	stub_squad commit "NO INPUT"

	run squad_commit

	assert_failure
	assert_output --partial "error: squad returned the NO INPUT sentinel"
	assert_output --partial "commit message is empty"
	refute grep -q "git commit" "$GIT_LOG"
	refute grep -q "git push" "$GIT_LOG"
}

@test "squad_commit commits and pushes the generated message" {
	stub_squad commit "fix: correct the thing"

	run squad_commit

	assert_success
	assert grep -q "git commit --cleanup=verbatim -F -" "$GIT_LOG"
	assert grep -q "git push -u origin HEAD" "$GIT_LOG"
}

@test "squad_pr aborts before pushing when squad returns the sentinel" {
	stub_squad pr "NO INPUT"

	run squad_pr

	assert_failure
	assert_output --partial "error: PR text is empty"
	refute grep -q "git push" "$GIT_LOG"
	refute grep -q "gh pr create" "$GH_LOG"
}

@test "squad_pr aborts before pushing when the model omits the title line" {
	stub_squad pr "## What this PR does / why we need it:

Body of the PR."

	run squad_pr

	assert_failure
	assert_output --partial "PR title is a markdown heading"
	refute grep -q "git push" "$GIT_LOG"
}

@test "squad_pr opens a PR with the generated title and body" {
	stub_squad pr "feat: add a thing

Body of the PR."

	run squad_pr

	assert_success
	assert grep -q "gh pr create" "$GH_LOG"
}
