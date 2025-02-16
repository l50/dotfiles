#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../bashutils.sh'

bats_require_minimum_version 1.5.0

export RUNNING_BATS_TEST=1

setup() {
	# Create a temp file with some JSON for testing
	TEST_JSON_FILE=$(mktemp)
	echo '{"key1":"value1","key2":"value2","arrayKey":["value3","value4"]}' >"$TEST_JSON_FILE"

	# Mock the environment variables
	export AUTHOR="cli"
	export REPO_NAME="cli"
	export INSTALL="false"
}

teardown() {
	# Delete the temp file
	rm "$TEST_JSON_FILE"
	# Clean up the environment variables
	unset AUTHOR
	unset REPO_NAME
	unset INSTALL
}

@test "check_disk_space_with_no_arguments" {
    run check_disk_space
    assert_failure
    assert_output "Error: Required space in MB must be provided"
}

@test "check_disk_space_with_invalid_argument" {
    run check_disk_space "abc"
    assert_failure
    assert_output "Error: Required space must be a positive integer"
}

@test "check_disk_space_with_negative_number" {
    run check_disk_space "-100"
    assert_failure
    assert_output "Error: Required space must be a positive integer"
}

@test "check_disk_space_with_zero" {
    run check_disk_space "0"
    assert_success
}

@test "check_disk_space_with_small_required_space" {
    run check_disk_space "1"
    assert_success
}

@test "check_disk_space_with_available_space" {
    # Mock df command to return a fixed amount of space (10GB)
    # shellcheck disable=SC2317
    df() {
        # shellcheck disable=SC2317
        echo "Filesystem     1K-blocks      Used Available Use% Mounted on"
        # shellcheck disable=SC2317
        echo "/dev/sda1      41943040  31457280  10485760  75% /"
    }
    export -f df

    run check_disk_space "1000"  # Request 1GB
    assert_success
}

@test "check_disk_space_with_insufficient_space" {
    # Mock df command to return a small amount of space (100MB)
    # shellcheck disable=SC2317
    df() {
        # shellcheck disable=SC2317
        echo "Filesystem     1K-blocks      Used Available Use% Mounted on"
        # shellcheck disable=SC2317
        echo "/dev/sda1      41943040  41841664    102400  98% /"
    }
    export -f df

    run check_disk_space "1000"  # Request 1GB
    assert_failure
    assert_output "Error: Not enough disk space. Required: 1000MB, Available: 100MB"
}

@test "getJSONKeys_function_returns_expected_keys" {
	# Setup - create test JSON file
	local test_json_file
	test_json_file=$(mktemp)
	echo '{"key1":"value1","key2":"value2","arrayKey":["value3","value4"]}' >"$test_json_file"

	# Run the function
	run getJSONKeys "$test_json_file"

	# Check for success
	assert_success

	# Expected formatted output from jq
	local expected_output=$'[\n  "arrayKey",\n  "key1",\n  "key2"\n]'
	assert_output "$expected_output"

	# Cleanup
	rm -f "$test_json_file"
}

@test "getJSONValues_function_returns_expected_values" {
	# Setup - create test JSON with nested values
	local test_json_file
	test_json_file=$(mktemp)
	echo '[{"key1":"value1"},{"key2":"value2"},{"arrayKey":["value3","value4"]}]' >"$test_json_file"

	# Run the function
	run getJSONValues "$test_json_file"

	# Check for success
	assert_success

	# Expected formatted output from jq
	local expected_output=$'{\n  "key1": "value1"\n}\n{\n  "key2": "value2"\n}\n{\n  "arrayKey": [\n    "value3",\n    "value4"\n  ]\n}'
	assert_output "$expected_output"

	# Cleanup
	rm -f "$test_json_file"
}

@test "is_filepath_with_a_valid_filepath" {
	# Setup - create a temporary file
	TEMP_FILE=$(mktemp)

	# Call is_filepath and pass the file path, capturing output and status
	output=$(echo "$TEMP_FILE" | is_filepath)
	status=$?

	# Assertions
	[ "$status" -eq 0 ]
	[[ $output == "Input is a file path." ]]

	# Cleanup
	rm -f "$TEMP_FILE"
}

@test "is_filepath_with_an_invalid_filepath" {
	# Use a non-existing file path
	INVALID_PATH="/tmp/non-existing-file-$RANDOM"

	# Call is_filepath and pass the invalid path, capturing output and status
	output=$(echo "$INVALID_PATH" | is_filepath)
	status=$?

	# Assertions
	[ "$status" -eq 0 ]
	[[ $output == "Input is not a file path." ]]
}

@test "process_files_from_config_with_specific_patterns" {
    # Setup for CI environment
    if [[ -n "${CI}" ]]; then
        # Create a mock xclip that doesn't need X display
        xclip() {
            case "$1" in
                -selection)
                    shift  # consume the -selection argument
                    shift  # consume the clipboard/primary argument
                    cat > /dev/null  # consume input without using X
                    ;;
                -o|-out)
                    echo "mocked clipboard content"
                    ;;
                *)
                    cat > /dev/null  # default behavior - consume input
                    ;;
            esac
            return 0
        }
        export -f xclip
    fi

    # Setup - create a temporary working directory
    local temp_working_dir
    temp_working_dir=$(mktemp -d)

    # Create a temporary config file with patterns
    local temp_config
    temp_config=$(mktemp)

    # Change to the temporary directory
    cd "$temp_working_dir" || exit 1

    # Add file patterns to the config file
    cat <<EOF >"$temp_config"
./.git/*
./.hooks/*
./.github/*
./magefiles/*
./changelogs/*
./.vscode/*
./go.*
./LICENSE
./.mdlrc
./.pre-commit-config.yaml
./*.md
EOF

    # Create dummy files and directories to match the patterns
    mkdir -p .git .hooks .github magefiles changelogs .vscode
    touch .git/dummy .hooks/dummy .github/dummy magefiles/dummy changelogs/dummy .vscode/dummy
    touch go.mod go.sum LICENSE .mdlrc .pre-commit-config.yaml README.md

    # Call process_files_from_config with the config file
    run process_files_from_config "$temp_config"

    # Assert success
    assert_success

    # Verify that the files exist
    assert [ -f "go.mod" ]
    assert [ -f "go.sum" ]
    assert [ -f "LICENSE" ]
    assert [ -f ".mdlrc" ]
    assert [ -f ".pre-commit-config.yaml" ]
    assert [ -f "README.md" ]
    assert [ -d ".git" ]
    assert [ -d ".hooks" ]
    assert [ -d ".github" ]
    assert [ -d "magefiles" ]
    assert [ -d "changelogs" ]
    assert [ -d ".vscode" ]

    # Cleanup
    cd - || exit 1
    rm -rf "$temp_working_dir"
    rm -f "$temp_config"
}

@test "process_files_from_config_with_invalid_config_file" {
	# Use a non-existing config file path
	local non_existing_config="/tmp/non-existing-config-$RANDOM"

	# Call process_files_from_config with the non-existing config file
	run process_files_from_config "$non_existing_config"

	# Assertions
	[ "$status" -eq 1 ]
	[[ $output == *"Config file not found: $non_existing_config"* ]]
}

@test "create_zip_with_extension_with_specific_extension" {
	# Setup - create a temporary working directory
	local temp_working_dir
	temp_working_dir=$(mktemp -d)

	# Change to the temporary directory
	pushd "$temp_working_dir" || exit 1

	# Create a temporary directory with files
	local test_dir
	test_dir=$(mktemp -d)

	# Create files with different extensions
	touch "$test_dir/file1.go"
	touch "$test_dir/file2.go"
	touch "$test_dir/file1.txt"
	touch "$test_dir/file2.txt"

	# Call create_zip_with_extension with the directory, zip file name, and extension
	local zipfile="test.zip"
	local extension="go"
	run create_zip_with_extension "$test_dir" "$zipfile" "$extension"

	# Assertions for successful creation
	assert_success
	assert [ -f "$zipfile" ]

	# Check for presence of .go files
	run unzip -l "$zipfile"
	assert_success
	assert_output --partial "file1.go"
	assert_output --partial "file2.go"

	# Check for absence of .txt files
	refute_output --partial "file1.txt"
	refute_output --partial "file2.txt"

	# Cleanup - return to the original directory and remove the temporary directory
	popd || return 1
	rm -rf "$temp_working_dir"
}
