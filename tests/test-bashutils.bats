#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../bashutils'

export RUNNING_BATS_TEST=1

setup() {
    # Create a temp file with some JSON for testing
    TEST_JSON_FILE=$(mktemp)
    echo '{"key1":"value1","key2":"value2","arrayKey":["value3","value4"]}' > "$TEST_JSON_FILE"

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

@test "getJSONKeys function" {
    run getJSONKeys "$TEST_JSON_FILE"
    [ "$status" -eq 0 ]
    [[ $output == *"key1"* ]]
    [[ $output == *"key2"* ]]
    [[ $output == *"arrayKey"* ]]
}

@test "getJSONValues function" {
    run getJSONValues "$TEST_JSON_FILE"
    [ "$status" -eq 0 ]
    [[ $output == *"value1"* ]]
    [[ $output == *"value2"* ]]
    [[ $output == *"value3"* ]]
    [[ $output == *"value4"* ]]
}

@test "fetchFromGithub with binary name" {
    run fetchFromGithub "CowDogMoo" "Guacinator" "v1.0.0" "guacinator"
    [ "$status" -eq 0 ]
    [[ $output == *"Copied guacinator to"* ]]
}

@test "fetchFromGithub with binary name and GitHub token" {
    # Only set token if not in a github action
    if [[ -z $GITHUB_ACTION ]]; then
        GITHUB_TOKEN=$(gh auth token)
        export GITHUB_TOKEN
  fi

    run fetchFromGithub "CowDogMoo" "Guacinator" "v1.0.0" "guacinator"
    [ "$status" -eq 0 ]
    [[ $output == *"Copied guacinator to"* ]]
}

@test "fetchFromGithub with custom destination directory" {
    # Temporary destination directory for this test
    DEST_DIR=$(mktemp -d)

    # Only set token if not in a github action
    if [[ -z $GITHUB_ACTION ]]; then
        GITHUB_TOKEN=$(gh auth token)
        export GITHUB_TOKEN
  fi

    run fetchFromGithub "facebookincubator" "TTPForge" "v1.0.3" "ttpforge" "$DEST_DIR"
    [ "$status" -eq 0 ]
    [[ $output == *"Copied ttpforge to $DEST_DIR/ as ttpforge"* ]]

    # Cleanup temporary directory
    rm -rf "$DEST_DIR"
}

@test "fetchFromGithub with non-existent release" {
    # Only set token if not in a github action
    if [[ -z $GITHUB_ACTION ]]; then
        GITHUB_TOKEN=$(gh auth token)
        export GITHUB_TOKEN
  fi

    run fetchFromGithub "l50" "test" "v0.0.1" "desiredbinname"
    [ "$status" -eq 1 ] # expected to fail
    [[ $output == *"No relevant release found for OS:"* ]]
}

# Helper function to create a non-empty test file
create_non_empty_file() {
    local file_name=$1
    echo "This is some content" > "$file_name"
}

@test "extract function for zip format with optional directory parameter" {
    # Create a test directory for extraction
    TEST_DIR=$(mktemp -d)

    # Create a sample zip file for testing
    TEST_ZIP=$(mktemp "testfile-XXXXX")
    create_non_empty_file "$TEST_ZIP"
    zip "${TEST_ZIP}.zip" "$TEST_ZIP"

    run extract "${TEST_ZIP}.zip" "$TEST_DIR"
    [ "$status" -eq 0 ]

    # Assert
    [ -f "$TEST_DIR/$TEST_ZIP" ]

    # Cleanup
    rm -r "$TEST_DIR"
    rm "${TEST_ZIP}.zip"
    rm "$TEST_ZIP"
}

@test "extract function for tar.gz format without directory parameter" {
    # Create a sample tar.gz file for testing
    TEST_TAR_GZ=$(mktemp "testfile-XXXXX").tar.gz
    create_non_empty_file "${TEST_TAR_GZ%%.tar.gz}"
    tar -czvf "$TEST_TAR_GZ" "${TEST_TAR_GZ%%.tar.gz}"

    run extract "$TEST_TAR_GZ"
    [ "$status" -eq 0 ]

    # Assert
    [ -f "${TEST_TAR_GZ%%.tar.gz}" ]

    # Cleanup
    rm "$TEST_TAR_GZ"
    rm "${TEST_TAR_GZ%%.tar.gz}"
}

@test "check_gh_token_perms with valid token" {
  GITHUB_TOKEN="$(gh auth token)"
  export GITHUB_TOKEN
  run check_gh_token_perms
  [ "$status" -eq 0 ]
  [ "${lines[0]}" != "No repositories found. The token might not have the necessary permissions." ]
  [ "${lines[0]}" != "Invalid GitHub token." ]
}

@test "check_gh_token_perms with invalid token" {
  GITHUB_TOKEN="invalid-token"
  export GITHUB_TOKEN
  run check_gh_token_perms
  [ "$status" -eq 1 ]
  [[ $output == *"Invalid GitHub token."* ]]
}

@test "check_gh_token_perms with valid token but no repo access" {
  # Set a valid token
  GITHUB_TOKEN="$(gh auth token)"
  export GITHUB_TOKEN
  # Use an organization where the token's user is not a member
  run check_gh_token_perms "some-org-with-no-access"
  [ "$status" -eq 1 ]
  [[ $output == *"No repositories found. The token might not have the necessary permissions."* ]]
}

# Helper function to create a test image file using dd
create_image_file() {
    local file_name=$1
    echo -n "89504e470d0a1a0a" | xxd -r -p > "$file_name"
}

# Helper function to create a test binary file using dd
create_binary_file() {
    local file_name=$1
    dd if=/dev/zero of="$file_name" bs=1 count=1 &> /dev/null
}

# Testing print_file_content function
@test "print_file_content with text file" {
    # Create a temporary file with '.txt' suffix
    TEST_TEXT_FILE=$(mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX.txt")

    echo "Hello, world!" > "$TEST_TEXT_FILE"
    run print_file_content "$TEST_TEXT_FILE"

    # Assertions
    [ "$status" -eq 0 ]
    [[ "$output" == *"$TEST_TEXT_FILE:"* ]]
    [[ "$output" == *"Hello, world!"* ]]

    # Cleanup
    rm "$TEST_TEXT_FILE"
}

@test "print_file_content with image file" {
    # Create a temporary file with '.png' suffix
    TEST_IMAGE_FILE=$(mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX.png")

    # Call the helper function to create an image file
    create_image_file "$TEST_IMAGE_FILE"

    run print_file_content "$TEST_IMAGE_FILE"

    # Assertions
    [ "$status" -eq 0 ]
    echo $output
    [[ "$output" == *"$TEST_IMAGE_FILE: Image file"* ]]

    # Cleanup
    rm "$TEST_IMAGE_FILE"
}

@test "print_file_content with binary file" {
    # Create a temporary file with '.bin' suffix
    TEST_BINARY_FILE=$(mktemp "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX.bin")

    # Call the helper function to create a binary file
    create_binary_file "$TEST_BINARY_FILE"

    run print_file_content "$TEST_BINARY_FILE"

    # Assertions
    [ "$status" -eq 0 ]
    [[ "$output" == *"$TEST_BINARY_FILE: Binary or non-text file"* ]]

    # Cleanup
    rm "$TEST_BINARY_FILE"
}
