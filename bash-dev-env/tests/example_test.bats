#!/usr/bin/env bats
# Example Bats tests — run: bats tests/

setup() {
  BATS_LIB="$(dirname "$BATS_TEST_FILENAME")/../lib"
}

@test "lib common.sh sources without error" {
  source "${BATS_LIB}/common.sh"
  run log_info "test"
  [[ $status -eq 0 ]]
  [[ $output == *"[INFO]"* ]]
}

@test "hello example runs" {
  run bash "${BATS_TEST_DIRNAME}/../examples/hello.sh"
  [[ $status -eq 0 ]]
  [[ $output == *"Hello, bash dev environment!"* ]]
}
