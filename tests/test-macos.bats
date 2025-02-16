#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../macos.sh'

export RUNNING_BATS_TEST=1

setup() {
    TEST_TEMP_DIR=$(mktemp -d)
	export TEST_TEMP_DIR
}

teardown() {
    rm -rf "${TEST_TEMP_DIR}"
}

@test "largest_files returns expected output" {
    # Create a test directory with files
    local test_dir="${TEST_TEMP_DIR}/files"
    mkdir -p "${test_dir}"

    # Create test files with specific sizes
    dd if=/dev/zero of="${test_dir}/large_file.dat" bs=1M count=200 2>/dev/null
    dd if=/dev/zero of="${test_dir}/medium_file.dat" bs=1M count=150 2>/dev/null

    # Add some delay to ensure files are written
    sync
    sleep 1

    # Debug directory contents
    echo "Test directory contents:"
    ls -lh "${test_dir}"

    # Run the command and capture output
    run largest_files "${test_dir}"

    # Debug output
    echo "Command output: $output"

    # Assert command succeeded
    assert_success

    # Check if output contains the expected filename and size format
    [[ "$output" == *"large_file.dat: "* ]] || {
        echo "Expected output to contain 'large_file.dat: ' followed by size"
        echo "Actual output: $output"
        return 1
    }
}

@test "gw command executes successfully" {
    run gw
    assert_success
    # Add specific assertions for expected output if needed
}

@test "trace_write function executes successfully" {
    # Create an indefinitely running dummy process to trace
    tail -f /dev/null &
    local dummy_pid=$!

    # Give it a moment to start
    sleep 1

    # Call trace_write with the dummy process PID
    run trace_write "${dummy_pid}"

    # Kill the dummy process to clean up
    kill "${dummy_pid}" || true
    wait "${dummy_pid}" 2>/dev/null || true

    # Check execution and output
    assert_success
    assert_output --partial "Breakpoint 1 set"
    assert_output --partial "Process running"
}
