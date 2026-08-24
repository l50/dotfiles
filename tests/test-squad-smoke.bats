#!/usr/bin/env bats
#
# Live smoke tests for the squad_gen pipeline. Each test makes a real
# claude-code call billed to the Claude subscription, so they are opt-in:
#
#   SQUAD_SMOKE=1 bats tests/test-squad-smoke.bats
#
# Without SQUAD_SMOKE they skip, keeping pre-commit and CI runs free and
# hermetic.

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../git.sh'

bats_require_minimum_version 1.5.0

setup() {
	[ -n "${SQUAD_SMOKE:-}" ] || skip "set SQUAD_SMOKE=1 to run live squad smoke tests"
	command -v squad > /dev/null 2>&1 || skip "squad is not installed"
	local hub="${FABRIC_PATTERNS_HUB:-$HOME/cowdogmoo/fabric-patterns-hub}"
	[ -d "$hub/patterns/commit" ] || skip "fabric-patterns-hub is not cloned"
}

@test "squad_gen commit generates a conventional commit message from a diff" {
	run squad_gen commit <<- 'EOF'
		diff --git a/greet.sh b/greet.sh
		new file mode 100755
		--- /dev/null
		+++ b/greet.sh
		@@ -0,0 +1,2 @@
		+#!/usr/bin/env bash
		+echo "hello"
	EOF

	assert_success
	assert_output --regexp '^(feat|fix|chore|docs|refactor|test|ci|build|perf|style)(\(.+\))?: .+'
	refute_output --partial "NO INPUT"
}

@test "squad_gen commit fails cleanly on empty input" {
	run squad_gen commit < /dev/null

	assert_failure
	assert_output --partial "NO INPUT sentinel"
}
