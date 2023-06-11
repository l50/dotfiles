#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "pull_repos function" {
  result="$(pull_repos "$PWD")"
  [[ $? -eq 0 ]]
  echo "Success: $result"
}

@test "get_exported_go_funcs function" {
  result="$(get_exported_go_funcs "$PWD")"
  [[ $? -eq 0 ]]
  echo "Success: $result"
}

@test "get_missing_tests function" {
  result="$(get_missing_tests "$PWD")"
  [[ $? -eq 0 ]]
  echo "Success: $result"
}

@test "add_cobra_init function" {
  result="$(add_cobra_init)"
  [[ $? -eq 0 ]]
  echo "Success: $result"
}

@test "import_path function" {
  result="$(import_path "$PWD")"
  [[ $? -eq 0 ]]
  echo "Success: $result"
}
