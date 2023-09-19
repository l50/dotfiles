#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export RUNNING_BATS_TEST=1

@test "pull_repos function" {
    # Cleanup any existing repository
    rm -rf /tmp/testrepo*

    # Setup test repository
    mkdir -p /tmp/testrepo_origin

    # Create empty exclude file for test
    mkdir -p /tmp/testrepo_origin/.git/info && touch /tmp/testrepo_origin/.git/info/exclude

    # Populate exclude file
    cat > /tmp/testrepo_origin/.git/info/exclude << EOF
# git ls-files --others --exclude-from=.git/info/exclude
# Lines that start with '#' are comments.
# For a project mostly in C, the following would be a good set of
# exclude patterns (uncomment them if you want to use them):
# *.[oa]
# *~
EOF

    # Initialize test repository
    pushd /tmp/testrepo_origin || return 1
    git init
    echo "initial content" > testfile
    git add testfile
    git commit -m "Initial commit"
    popd || return 1

    # Clone test repository twice
    git clone /tmp/testrepo_origin /tmp/testrepo_clone1
    git clone /tmp/testrepo_origin /tmp/testrepo_clone2

    # Make a change in the first clone
    pushd /tmp/testrepo_clone1 || return 1
    git checkout -b testbranch
    echo "new content" >> testfile
    git add testfile
    git commit -m "New commit"
    git push origin testbranch
    popd || return 1

    # Run function on the second clone
    pushd /tmp/testrepo_clone2 || return 1
    source "${BATS_TEST_DIRNAME}/../go"
    git fetch # Fetch branches from remote
    git checkout testbranch
    run pull_repos "$PWD"
    [[ "${status}" -eq 0 ]] || echo "Error: $output"
    [[ "$output" == *"All repositories successfully updated."* ]]
    [[ "$(git log -1 --pretty=%B)" == "New commit" ]]
    popd || return 1

    # Cleanup
    rm -rf /tmp/testrepo_origin /tmp/testrepo_clone1 /tmp/testrepo_clone2
}

@test "get_exported_go_funcs function" {
    source "${BATS_TEST_DIRNAME}/../go"
    run get_exported_go_funcs "$PWD"
    [ "$status" -eq 0 ]
}

@test "get_missing_tests function identifies exported Go functions without tests" {
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    go install github.com/dolmen-go/goeval@latest

    # Create a Go file with some exported and unexported functions
    cat > "${TEMP_DIR}/testfile.go" << EOF
  package test

  // Exported function without test
  func ExportedFunc1() {}

  // Unexported function
  func unexportedFunc() {}

  // Exported function with test
  func ExportedFunc2() {}
EOF

    # Create a test file for one of the functions
    cat > "${TEMP_DIR}/testfile_test.go" << EOF
  package test

  import "testing"

  // Test for ExportedFunc2
  func TestExportedFunc2(t *testing.T) {}
EOF

    # Source the script containing the function under test
    source "${BATS_TEST_DIRNAME}/../go"

    # Run the function under test
    run get_missing_tests "${TEMP_DIR}"

    # The function should complete successfully
    assert_success

    # The function should identify the exported function without a test
    assert_output --partial "ExportedFunc1"

    # The function should not identify the unexported function
    refute_output --partial "unexportedFunc"

    # The function should not identify the exported function with a test
    refute_output --partial "ExportedFunc2"

    # Clean up the temporary directory
    rm -rf "${TEMP_DIR}"
}

@test "add_cobra_init function" {
    source "${BATS_TEST_DIRNAME}/../go"
    run add_cobra_init "$PWD"
    [ "$status" -eq 0 ]
}

@test "import_path function" {
    source "${BATS_TEST_DIRNAME}/../go"
    skip
    run import_path "$PWD"
    [ "$status" -eq 0 ]
}
