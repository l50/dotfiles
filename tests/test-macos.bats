#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../macos'

export RUNNING_BATS_TEST=1

@test "largest_files function" {
    run largest_files "$PWD"
    if [[ "${status}" -ne 0 ]]; then
        echo "Error: $output"
  fi
}

@test "gw" {
    run gw
    if [[ "${status}" -ne 0 ]]; then
        echo "Error: $output"
  fi
}
