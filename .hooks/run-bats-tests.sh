#!/bin/bash
set -e

# Find the project root
repo_root=$(git rev-parse --show-toplevel)

# Run all bats tests in the tests directory
output=$(bats --tap "${repo_root}/tests/"*.bats)
exit_code=$?

echo "${output}"
exit ${exit_code}
