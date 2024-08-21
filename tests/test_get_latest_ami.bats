#!/usr/bin/env bats

# Load dependencies
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../cloud/aws/ec2.sh'

@test "get_latest_ami function with valid input for Ubuntu 22.04 amd64" {
    echo "Running test for Ubuntu 22.04 amd64..." >&2
    run get_latest_ami "ubuntu" "22.04" "amd64"
    echo "Output: $output" >&2  # Debug output
    assert_success
    assert_output --partial "ami-"
}

@test "get_latest_ami function with valid input for Debian 12 amd64" {
    echo "Running test for Debian 12 amd64..." >&2
    run get_latest_ami "debian" "12" "amd64"
    echo "Output: $output" >&2  # Debug output
    assert_success
    assert_output --partial "ami-"
}

@test "get_latest_ami function with unsupported distro" {
    run get_latest_ami "unsupported_distro" "12" "amd64" "test"
    assert_output "Unsupported distribution: unsupported_distro"
    assert_failure
}

@test "get_latest_ami function with unsupported version for Ubuntu" {
    run get_latest_ami "ubuntu" "24.04" "amd64" "test"
    assert_output "Unsupported version: 24.04 for Ubuntu"
    assert_failure
}

@test "get_latest_ami function with unsupported architecture for Ubuntu 22.04" {
    run get_latest_ami "ubuntu" "22.04" "unsupported_arch" "test"
    assert_output "Unsupported architecture: unsupported_arch for Ubuntu"
    assert_failure
}

@test "get_latest_ami function with missing parameters" {
    run get_latest_ami
    assert_output --partial "Usage: get_latest_ami <distro> <version> <architecture>"
    assert_output --partial "Example: get_latest_ami debian 12 amd64"
    assert_failure
}
