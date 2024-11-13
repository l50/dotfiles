#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../bashutils'

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

@test "getJSONKeys function returns expected keys" {
	# Setup - create test JSON file
	local test_json_file
	test_json_file=$(mktemp)
	echo '{"key1":"value1","key2":"value2","arrayKey":["value3","value4"]}' >"$test_json_file"

	# Run the function
	run getJSONKeys "$test_json_file"

	# Check for success
	assert_success

	# Verify output format and content
	# jq 'keys' returns an array of keys like: ["arrayKey","key1","key2"]
	assert_output '["arrayKey","key1","key2"]'

	# Cleanup
	rm -f "$test_json_file"
}

@test "getJSONValues function returns expected values" {
	# Setup - create test JSON with nested values
	local test_json_file
	test_json_file=$(mktemp)
	echo '[{"key1":"value1"},{"key2":"value2"},{"arrayKey":["value3","value4"]}]' >"$test_json_file"

	# Run the function
	run getJSONValues "$test_json_file"

	# Check for success
	assert_success

	# Verify each expected value appears in output
	# jq '.[] | values' returns each value on a new line
	assert_line '"value1"'
	assert_line '"value2"'
	assert_line '["value3","value4"]'

	# Cleanup
	rm -f "$test_json_file"
}

# @test "fetchFromGithub with binary name" {
#     run fetchFromGithub "CowDogMoo" "Guacinator" "v1.0.0" "guacinator"
#     [ "$status" -eq 0 ]
#     [[ $output == *"Copied guacinator to"* ]]
# }

# @test "fetchFromGithub with binary name and GitHub token" {
#     # Only set token if not in a github action
#     if [[ -z $GITHUB_ACTION ]]; then
#         GITHUB_TOKEN=$(gh auth token)
#         export GITHUB_TOKEN
#   fi

#     run fetchFromGithub "CowDogMoo" "Guacinator" "v1.0.0" "guacinator"
#     [ "$status" -eq 0 ]
#     [[ $output == *"Copied guacinator to"* ]]
# }

# @test "fetchFromGithub with custom destination directory" {
#     # Temporary destination directory for this test
#     DEST_DIR=$(mktemp -d)

#     # Only set token if not in a github action
#     if [[ -z $GITHUB_ACTION ]]; then
#         GITHUB_TOKEN=$(gh auth token)
#         export GITHUB_TOKEN
#   fi

#     run fetchFromGithub "facebookincubator" "TTPForge" "v1.0.3" "ttpforge" "$DEST_DIR"
#     [ "$status" -eq 0 ]
#     [[ $output == *"Copied ttpforge to $DEST_DIR/ as ttpforge"* ]]

#     # Cleanup temporary directory
#     rm -rf "$DEST_DIR"
# }

# @test "fetchFromGithub with non-existent release" {
#     # Only set token if not in a github action
#     if [[ -z $GITHUB_ACTION ]]; then
#         GITHUB_TOKEN=$(gh auth token)
#         export GITHUB_TOKEN
#   fi

#     run fetchFromGithub "l50" "test" "v0.0.1" "desiredbinname"
#     [ "$status" -eq 1 ] # expected to fail
#     [[ $output == *"No relevant release found for OS:"* ]]
# }

# # Helper function to create a non-empty test file
# create_non_empty_file() {
#     local file_name=$1
#     echo "This is some content" > "$file_name"
# }

# @test "extract function for zip format with optional directory parameter" {
#     # Create a test directory for extraction
#     TEST_DIR=$(mktemp -d)

#     # Create a sample zip file for testing
#     TEST_ZIP=$(mktemp "testfile-XXXXX")
#     create_non_empty_file "$TEST_ZIP"
#     zip "${TEST_ZIP}.zip" "$TEST_ZIP"

#     run extract "${TEST_ZIP}.zip" "$TEST_DIR"
#     [ "$status" -eq 0 ]

#     # Assert
#     [ -f "$TEST_DIR/$TEST_ZIP" ]

#     # Cleanup
#     rm -r "$TEST_DIR"
#     rm "${TEST_ZIP}.zip"
#     rm "$TEST_ZIP"
# }

# @test "extract function for tar.gz format without directory parameter" {
#     # Create a sample tar.gz file for testing
#     TEST_TAR_GZ=$(mktemp "testfile-XXXXX").tar.gz
#     create_non_empty_file "${TEST_TAR_GZ%%.tar.gz}"
#     tar -czvf "$TEST_TAR_GZ" "${TEST_TAR_GZ%%.tar.gz}"

#     run extract "$TEST_TAR_GZ"
#     [ "$status" -eq 0 ]

#     # Assert
#     [ -f "${TEST_TAR_GZ%%.tar.gz}" ]

#     # Cleanup
#     rm "$TEST_TAR_GZ"
#     rm "${TEST_TAR_GZ%%.tar.gz}"
# }

# @test "check_gh_token_perms with valid token" {
#   GITHUB_TOKEN="$(gh auth token)"
#   export GITHUB_TOKEN
#   run check_gh_token_perms
#   [ "$status" -eq 0 ]
#   [ "${lines[0]}" != "No repositories found. The token might not have the necessary permissions." ]
#   [ "${lines[0]}" != "Invalid GitHub token." ]
# }

# @test "check_gh_token_perms with invalid token" {
#   GITHUB_TOKEN="invalid-token"
#   export GITHUB_TOKEN
#   run check_gh_token_perms
#   [ "$status" -eq 1 ]
#   [[ $output == *"Invalid GitHub token."* ]]
# }

# @test "check_gh_token_perms with valid token but no repo access" {
#   # Set a valid token
#   GITHUB_TOKEN="$(gh auth token)"
#   export GITHUB_TOKEN
#   # Use an organization where the token's user is not a member
#   run check_gh_token_perms "some-org-with-no-access"
#   [ "$status" -eq 1 ]
#   [[ $output == *"No repositories found. The token might not have the necessary permissions."* ]]
# }

# # Helper function to create a test image file using dd
# create_image_file() {
#     local file_name=$1
#     echo -n "89504e470d0a1a0a" | xxd -r -p > "$file_name"
# }

# # Helper function to create a test binary file using dd
# create_binary_file() {
#     local file_name=$1
#     dd if=/dev/zero of="$file_name" bs=1 count=1 &> /dev/null
# }

# # Testing print_file_content function
# @test "print_file_content with text file" {
#     # Create a temporary file with '.txt' suffix
#     TEST_TEXT_FILE=$(mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX.txt")

#     echo "Hello, world!" > "$TEST_TEXT_FILE"
#     run print_file_content "$TEST_TEXT_FILE"

#     # Assertions
#     [ "$status" -eq 0 ]
#     [[ "$output" == *"$TEST_TEXT_FILE:"* ]]
#     [[ "$output" == *"Hello, world!"* ]]

#     # Cleanup
#     rm "$TEST_TEXT_FILE"
# }

# @test "print_file_content with image file" {
#     # Create a temporary file with '.png' suffix
#     TEST_IMAGE_FILE=$(mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX.png")

#     # Call the helper function to create an image file
#     create_image_file "$TEST_IMAGE_FILE"

#     run print_file_content "$TEST_IMAGE_FILE"

#     # Assertions
#     [ "$status" -eq 0 ]
#     [[ "$output" == *"$TEST_IMAGE_FILE: Image file"* ]]

#     # Cleanup
#     rm "$TEST_IMAGE_FILE"
# }

# @test "print_file_content with binary file" {
#     # Create a temporary file with '.bin' suffix
#     TEST_BINARY_FILE=$(mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX.bin")

#     # Call the helper function to create a binary file
#     create_binary_file "$TEST_BINARY_FILE"

#     run print_file_content "$TEST_BINARY_FILE"

#     # Assertions
#     [ "$status" -eq 0 ]
#     [[ "$output" == *"$TEST_BINARY_FILE: Binary or non-text file"* ]]

#     # Cleanup
#     rm "$TEST_BINARY_FILE"
# }

# @test "nocomment removes inline and end-of-line comments" {
#     # Create a temporary file for testing
#     local test_file=$(mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX.sh")

#     # Write a sample script with comments to the test file
#     cat << 'EOF' > "$test_file"
# # This is a full line comment
# echo "Code" # This is an end-of-line comment
# # Another full line comment
# echo "More code" // Another end-of-line comment
# /*
# This is a multi-line comment
# that spans multiple lines
# */
# echo "Even more code"
# EOF

#     # Run nocomment and capture the output
#     run nocomment "$test_file"

#     # Assertions
#     [ "$status" -eq 0 ]
#     [[ $output == *"echo \"Code\""* ]] # Verify presence of uncommented code
#     [[ $output == *"echo \"More code\""* ]] # Verify presence of uncommented code
#     [[ $output == *"echo \"Even more code\""* ]] # Verify presence of uncommented code
#     [[ $output != *"# This is a full line comment"* ]] # Verify full line comments are removed
#     [[ $output != *"# This is an end-of-line comment"* ]] # Verify end-of-line comments are removed
#     [[ $output != *"// Another end-of-line comment"* ]] # Verify end-of-line comments are removed
#     [[ $output != *"This is a multi-line comment"* ]] # Verify multi-line comments are removed

#     # Cleanup
#     rm "$test_file"
# }

# @test "process_files with valid path and exclusions" {
#     # Setup - create a test directory with nested structure and files
#     local test_dir
#     test_dir=$(mktemp -d)
#     mkdir -p "$test_dir/.git" "$test_dir/.hooks" "$test_dir/.github"
#     touch "$test_dir/.git/config" "$test_dir/.hooks/pre-commit" \
#           "$test_dir/.github/ISSUE_TEMPLATE" "$test_dir/README.md"

#     # Call process_files and direct output to a file
#     local output_file
#     output_file=$(mktemp)
#     process_files "$test_dir" "$test_dir/.git/*" "$test_dir/.hooks/*" \
#                   "$test_dir/.github/*" "$test_dir/*.md" > "$output_file"

#     # Check if output file contains any of the excluded files
#     local excluded_files
#     excluded_files=("$test_dir/.git/config" "$test_dir/.hooks/pre-commit" \
#                     "$test_dir/.github/ISSUE_TEMPLATE" "$test_dir/README.md")
#     local file_found=false
#     for file in "${excluded_files[@]}"; do
#         if grep -q "$file" "$output_file"; then
#             file_found=true
#             break
#         fi
#     done

#     # Assertions
#     [ "$?" -eq 0 ]
#     [ "$file_found" = false ]

#     # Cleanup
#     rm -rf "$test_dir"
#     rm "$output_file"
# }

# @test "process_files with invalid path" {
#     # Setup - create a non-existing path
#     local non_existing_path="/tmp/non-existing-path-$RANDOM"

#     # Call process_files on the non-existing path
#     run process_files "$non_existing_path"

#     # Assertions
#     [ "$status" -ne 0 ]
# }

# @test "process_files with no exclusions" {
#     # Setup - create a test directory with a file
#     local test_dir
#     test_dir=$(mktemp -d)
#     touch "$test_dir/file_to_find.txt"

#     # Call process_files without exclusions
#     run process_files "$test_dir"

#     # Assertions
#     [ "$status" -eq 0 ]
#     [[ $output == *"$test_dir/file_to_find.txt"* ]]
# }

# @test "process_files with multiple exclusions" {
#     # Setup - create a test directory with nested structure and files
#     local test_dir
#     test_dir=$(mktemp -d)
#     mkdir -p "$test_dir/dir1" "$test_dir/dir2"
#     touch "$test_dir/dir1/file1.txt" "$test_dir/dir2/file2.txt" "$test_dir/file3.txt"

#     # Call process_files with multiple exclusions
#     run process_files "$test_dir" "$test_dir/dir1/*" "$test_dir/dir2/*"

#     # Assertions
#     [ "$status" -eq 0 ]
#     [[ $output == *"$test_dir/file3.txt"* ]]
#     [[ $output != *"$test_dir/dir1/file1.txt"* ]]
#     [[ $output != *"$test_dir/dir2/file2.txt"* ]]

#     # Cleanup
#     rm -rf "$test_dir"
# }

# @test "process_files with a mix of existing and non-existing exclusions" {
#     # Setup - create a test directory with nested structure and files
#     local test_dir
#     test_dir=$(mktemp -d)
#     mkdir -p "$test_dir/dir1" "$test_dir/dir2"
#     touch "$test_dir/dir1/file1.txt" "$test_dir/dir2/file2.txt" "$test_dir/file3.txt"

#     # Call process_files with a mix of existing and non-existing exclusions
#     run process_files "$test_dir" "$test_dir/dir1/*" "/non_existing_path/*"

#     # Assertions
#     [ "$status" -eq 0 ] # Should still succeed even if some paths don't exist
#     [[ $output != *"$test_dir/dir1/file1.txt"* ]]
#     [[ $output == *"$test_dir/dir2/file2.txt"* ]]
#     [[ $output == *"$test_dir/file3.txt"* ]]

#     # Cleanup
#     rm -rf "$test_dir"
# }

@test "is_filepath with a valid file path" {
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

@test "is_filepath with an invalid file path" {
	# Use a non-existing file path
	INVALID_PATH="/tmp/non-existing-file-$RANDOM"

	# Call is_filepath and pass the invalid path, capturing output and status
	output=$(echo "$INVALID_PATH" | is_filepath)
	status=$?

	# Assertions
	[ "$status" -eq 0 ]
	[[ $output == "Input is not a file path." ]]
}

@test "process_files_from_config with specific patterns" {
	# Setup - create a temporary working directory
	local temp_working_dir
	temp_working_dir=$(mktemp -d)

	# Change to the temporary directory
	pushd "$temp_working_dir"

	# Create a temporary config file with patterns
	local temp_config
	temp_config=$(mktemp)

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

	# Assertions
	[ "$status" -eq 0 ]

	# Cleanup - return to the original directory and remove the temporary directory
	popd
	rm -rf "$temp_working_dir"
}

@test "process_files_from_config with invalid config file" {
	# Use a non-existing config file path
	local non_existing_config="/tmp/non-existing-config-$RANDOM"

	# Call process_files_from_config with the non-existing config file
	run process_files_from_config "$non_existing_config"

	# Assertions
	[ "$status" -eq 1 ]
	[[ $output == *"Config file not found: $non_existing_config"* ]]
}

@test "create_zip_with_extension with specific extension" {
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
