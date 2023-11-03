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

@test "trace_write function" {
    # Create an indefinitely running dummy process to trace
    tail -f /dev/null &
    local dummy_pid=$!

    # Give it a moment to start
    sleep 1

    # Call trace_write with the dummy process PID
    run trace_write "${dummy_pid}"

    # Kill the dummy process to clean up
    kill "${dummy_pid}"

    # Check if the function was executed without errors
    if [[ "${status}" -ne 0 ]]; then
        echo "Error: $output"
    fi

    # Check the output
    assert_output --partial "Breakpoint 1 set"
    assert_output --partial "Process running"
}
