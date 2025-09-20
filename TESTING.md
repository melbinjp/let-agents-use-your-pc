# Testing Guide

This project uses a combination of automated unit tests for the core logic and static analysis for the installers.

---

## Automated Tests (Linux/macOS)

The core execution logic of the agent, found in `common/runner.sh`, is tested using the **Bats (Bash Automated Testing System)**. These tests mock external dependencies like `git` and do not require a network connection or a virtual machine.

### Prerequisites

You must have `bats` installed. On Debian/Ubuntu, you can install it with:

```bash
sudo apt-get update
sudo apt-get install bats
```

On macOS with Homebrew:
```bash
brew install bats-core
```

### Running the Tests

To run the tests for the `runner.sh` script, execute the following command from the root of the repository:

```bash
bats tests/test_runner.sh
```

The output will show the status of each test case. All tests should pass.

---

## Installer Sanity Checks

The installer scripts (`linux/install.sh`, `macos/install.sh`, `windows/install.ps1`) are checked with a static analysis script located at `tests/test_installers.sh`. This script scans the installers for outdated or insecure patterns.

### Running the Checks

To run the installer checks, execute the script from the root of the repository:

```bash
bash tests/test_installers.sh
```

The script will report `[PASS]` or `[FAIL]` for each check.

---

## Manual Integration Testing

While the automated tests cover the runner script's logic, full integration testing is still recommended, especially when making changes to the installers or the `cloudflared` configuration.

For manual testing, follow these general steps on a clean virtual machine:

1.  **Run the Installer**: Execute the `install.sh` (Linux/macOS) or `install.ps1` (Windows) script.
2.  **Verify Services**: Ensure the `cloudflared` service is running correctly.
3.  **Perform a Test Run**: Use the SSH command structure from `API_USAGE.md` to execute a test command, such as `ls -l`, against a public repository. Verify that you get the expected output and a `0` exit code.
4.  **Perform a Failing Test**: Execute a command that is guaranteed to fail (e.g., `exit 1`) and verify that you get a non-zero exit code.
