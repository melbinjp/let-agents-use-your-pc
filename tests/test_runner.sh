#!/usr/bin/env bats

# tests/test_runner.sh
#
# Automated tests for the core runner script.

# --- Test Setup ---

setup() {
  # Find the absolute path of the script under test.
  SCRIPT_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  RUNNER_SCRIPT="$SCRIPT_DIR/../common/runner.sh"
  chmod +x "$RUNNER_SCRIPT"

  # Create a mock for the 'git' command to avoid network dependency.
  MOCK_GIT_DIR="$BATS_TMPDIR/mock_git"
  mkdir -p "$MOCK_GIT_DIR"

  # This is the mock git script.
  cat > "$MOCK_GIT_DIR/git" <<'EOF'
#!/bin/bash
# Mock git command

# Log arguments for verification
echo "$@" >> "$BATS_TMPDIR/git_args.log"

# Simulate a successful 'git clone'
if [ "$1" = "clone" ]; then
  # The last argument to 'git clone' is the target directory.
  TARGET_DIR="${@: -1}"

  # Create the target directory ('repo' based on runner.sh)
  mkdir -p "$TARGET_DIR"
  # Create a dummy file inside it to simulate a real repo
  touch "$TARGET_DIR/README.md"
  touch "$TARGET_DIR/setup.py"
fi
EOF

  chmod +x "$MOCK_GIT_DIR/git"

  # Prepend the mock git directory to the PATH.
  export PATH="$MOCK_GIT_DIR:$PATH"

  # Clean up log file before each test
  rm -f "$BATS_TMPDIR/git_args.log"
}

@test "displays error and exits when 'v_repo' is missing" {
  run bash -c "v_branch=main v_test_cmd=ls $RUNNER_SCRIPT 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "[ERROR] Missing required environment variables." ]]
}

@test "displays error and exits when 'v_branch' is missing" {
  run bash -c "v_repo=some/repo v_test_cmd=ls $RUNNER_SCRIPT 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "[ERROR] Missing required environment variables." ]]
}

@test "displays error and exits when 'v_test_cmd' is missing" {
  run bash -c "v_repo=some/repo v_branch=main $RUNNER_SCRIPT 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "[ERROR] Missing required environment variables." ]]
}

@test "exits with non-zero status when command fails" {
  COMMAND="exit 123"
  run bash -c "v_repo=any/repo v_branch=main v_test_cmd='$COMMAND' $RUNNER_SCRIPT"
  [ "$status" -eq 123 ]
  TMP_DIR=$(echo "$output" | grep "Created temporary directory" | sed 's/.*: //')
  [ -n "$TMP_DIR" ]
  [ ! -d "$TMP_DIR" ]
}

@test "exits with non-zero status when git clone fails" {
  # Configure the mock git to fail
  echo 'exit 1' > "$MOCK_GIT_DIR/git"

  run bash -c "v_repo=any/repo v_branch=main v_test_cmd=ls $RUNNER_SCRIPT"
  [ "$status" -ne 0 ]
  TMP_DIR=$(echo "$output" | grep "Created temporary directory" | sed 's/.*: //')
  [ -n "$TMP_DIR" ]
  [ ! -d "$TMP_DIR" ]
}

# --- Test Cases ---

@test "successfully clones repo and executes command" {
  REPO_URL="https://mock.repo/pypackage-example.git"
  BRANCH="main"
  COMMAND="ls -F"

  run bash -c "v_repo=$REPO_URL v_branch=$BRANCH v_test_cmd='$COMMAND' $RUNNER_SCRIPT"
  [ "$status" -eq 0 ]
  GIT_LOG="$BATS_TMPDIR/git_args.log"
  [ -f "$GIT_LOG" ]
  read -r line < "$GIT_LOG"
  [ "$line" = "clone --depth 1 -b $BRANCH $REPO_URL repo" ]
  echo "$output" | grep "README.md"
  echo "$output" | grep "setup.py"
  TMP_DIR=$(echo "$output" | grep "Created temporary directory" | sed 's/.*: //')
  [ -n "$TMP_DIR" ]
  [ ! -d "$TMP_DIR" ]
}
