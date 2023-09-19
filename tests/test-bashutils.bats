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
    echo "GITHUB_TOKEN: $GITHUB_TOKEN"
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
