#!/bin/bash
set -ex

# Find the project root
root_dir=$(git rev-parse --show-toplevel)

# Run bats tests
output=$(bats "${root_dir}/tests/test-go.bats" 2>&1)
exit_code=$?

echo "${output}"
exit ${exit_code}
