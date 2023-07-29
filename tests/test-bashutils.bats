#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

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

@test "getJSONKeys function" {
	source "${BATS_TEST_DIRNAME}/../bashutils"
	run getJSONKeys "$TEST_JSON_FILE"
	[ "$status" -eq 0 ]
	[[ $output == *"key1"* ]]
	[[ $output == *"key2"* ]]
	[[ $output == *"arrayKey"* ]]
}

@test "getJSONValues function" {
	source "${BATS_TEST_DIRNAME}/../bashutils"
	run getJSONValues "$TEST_JSON_FILE"
	[ "$status" -eq 0 ]
	[[ $output == *"value1"* ]]
	[[ $output == *"value2"* ]]
	[[ $output == *"value3"* ]]
	[[ $output == *"value4"* ]]
}

# @test "fetchFromGithub with install=false" {
# 	source "${BATS_TEST_DIRNAME}/../bashutils"
# 	run fetchFromGithub "CowDogMoo" "guacinator" "v1.0.0"
# 	[ "$status" -eq 0 ]
# 	[[ $output == *"Download of guacinator release v1.0.0 from GitHub is complete."* ]]
# }

# @test "fetchFromGithub with install=true" {
# 	export INSTALL="true"
# 	source "${BATS_TEST_DIRNAME}/../bashutils"
# 	run fetchFromGithub "cowdogmoo" "guacinator" "v1.0.0"
# 	[ "$status" -eq 0 ]
# 	[[ $output == *"Copied"*"$HOME/.local/bin/"* ]]
# 	unset INSTALL
# }

# @test "extract function with optional directory parameter and different formats" {
# 	source "${BATS_TEST_DIRNAME}/../bashutils"

# 	# Create a test directory for extraction
# 	TEST_DIR=$(mktemp -d)

# 	# Create a text file for compression and testing
# 	echo "test content" > testfile.txt

# 	# Create various compressed file formats
# 	tar -czvf testfile.tar.gz testfile.txt
# 	tar -cjvf testfile.tar.bz2 testfile.txt
# 	gzip -c testfile.txt > testfile.gz
# 	bzip2 -c testfile.txt > testfile.bz2
# 	zip testfile.zip testfile.txt

# 	# Array of test files
# 	TEST_FILES=("testfile.tar.gz" "testfile.tar.bz2" "testfile.gz" "testfile.bz2" "testfile.zip")

# 	for TEST_FILE in "${TEST_FILES[@]}"; do
# 		run extract "$TEST_FILE" "$TEST_DIR"

# 		# Assert
# 		[ "$status" -eq 0 ]
# 		[ -f "$TEST_DIR/testfile.txt" ]
# 		[[ $(cat "$TEST_DIR/testfile.txt") == "test content" ]]

# 		# Cleanup
# 		rm -f "$TEST_DIR/testfile.txt"
# 	done

# 	# Cleanup
# 	rm -r "$TEST_DIR"
# 	rm -f testfile.txt
# 	rm -f testfile.tar.gz
# 	rm -f testfile.tar.bz2
# 	rm -f testfile.gz
# 	rm -f testfile.bz2
# 	rm -f testfile.zip
# }

# Helper function to create a non-empty test file
create_non_empty_file() {
	local file_name=$1
	echo "This is some content" >"$file_name"
}

@test "extract function for zip format with optional directory parameter" {
	source "${BATS_TEST_DIRNAME}/../bashutils"

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
	source "${BATS_TEST_DIRNAME}/../bashutils"

	# Create a sample tar.gz file for testing
	TEST_TAR_GZ=$(mktemp "testfile-XXXXX.tar.gz")
	create_non_empty_file "${TEST_TAR_GZ%%.tar.gz}"
	tar -czvf "$TEST_TAR_GZ" "${TEST_TAR_GZ%%.tar.gz}"

	run extract "$TEST_TAR_GZ"
	[ "$status" -eq 0 ]

	# Assert
	[ -f "./${TEST_TAR_GZ%%.tar.gz}" ]

	# Cleanup
	rm "$TEST_TAR_GZ"
	rm "${TEST_TAR_GZ%%.tar.gz}"
}
