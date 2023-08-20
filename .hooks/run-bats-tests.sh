#!/bin/bash
set -e

# Check if GITHUB_TOKEN is not set
if [[ -z $GITHUB_TOKEN ]]; then
    echo "Warning: GITHUB_TOKEN is not set. Some tests may fail."
fi

# Run all bats tests in the tests directory
output=$(bats --tap "tests/"*.bats)
exit_code=$?

echo "${output}"
exit ${exit_code}
