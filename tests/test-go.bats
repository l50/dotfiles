#!/usr/bin/env bats
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load '../go.sh'

export RUNNING_BATS_TEST=1

setup_file() {
    TEST_TEMP_DIR=$(mktemp -d)
    export TEST_TEMP_DIR
    export HOME="${TEST_TEMP_DIR}"
    export FILES="${TEST_TEMP_DIR}/files"

    # Create necessary test directories and files
    mkdir -p "${FILES}"
    cat > "${FILES}/cobra.yaml" << 'EOF'
author: test <test@example.com>
license: MIT
useViper: true
EOF
}

teardown_file() {
    rm -rf "${TEST_TEMP_DIR}"
}

setup() {
    git config --global user.email "action@github.com"
    git config --global user.name "GitHub Action"
    # Create temp test directory for each test
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR" || exit 1
}

teardown() {
    cd "$OLDPWD" || exit 1
    rm -rf "$TEST_DIR"
}

@test "pull_repos updates repositories successfully" {
    # Setup test repository
    mkdir -p "${TEST_TEMP_DIR}/testrepo_origin/.git/info"

    # Initialize test repository
    pushd "${TEST_TEMP_DIR}/testrepo_origin"
    git init
    touch .git/info/exclude
    echo "initial content" > testfile
    git add testfile
    git commit -m "Initial commit"
    popd

    # Clone test repository twice
    git clone "${TEST_TEMP_DIR}/testrepo_origin" "${TEST_TEMP_DIR}/testrepo_clone1"
    git clone "${TEST_TEMP_DIR}/testrepo_origin" "${TEST_TEMP_DIR}/testrepo_clone2"

    # Make changes in first clone
    pushd "${TEST_TEMP_DIR}/testrepo_clone1"
    git checkout -b testbranch
    echo "new content" >> testfile
    git add testfile
    git commit -m "New commit"
    git push origin testbranch
    popd

    # Test pull_repos on second clone
    pushd "${TEST_TEMP_DIR}/testrepo_clone2"
    git fetch
    git checkout testbranch

    run pull_repos "$PWD"

    assert_success
    assert_output --partial "All repositories successfully updated."
    assert [ "$(git log -1 --pretty=%B)" = "New commit" ]
    popd
}

@test "get_exported_go_funcs_function" {
	run get_exported_go_funcs "$PWD"
	[ "$status" -eq 0 ]
}


@test "add_cobra_init creates cobra files" {
    # Create test FILES directory and cobra.yaml template
    mkdir -p "${TEST_TEMP_DIR}/files"
    cat > "${TEST_TEMP_DIR}/files/cobra.yaml" << 'EOF'
author: Your Name <you@example.com>
license: MIT
useViper: true
EOF

    # Set up test environment
    export HOME="${TEST_TEMP_DIR}"
    export FILES="${TEST_TEMP_DIR}/files"

    # Run add_cobra_init
    run add_cobra_init

    # Assert success
    assert_success

    # Check if .cobra.yaml exists in the correct location
    test -f "${TEST_TEMP_DIR}/.cobra.yaml"

    # Verify content was copied correctly
    run cat "${TEST_TEMP_DIR}/.cobra.yaml"
    assert_output --partial "author: Your Name"
}

@test "import_path returns go import path" {
    skip "Test needs to be implemented"
    mkdir -p "${TEST_TEMP_DIR}/gotest"
    run import_path "${TEST_TEMP_DIR}/gotest"
    assert_success
}
