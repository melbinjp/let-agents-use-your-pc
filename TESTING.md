# Manual Testing Guide

Thank you for helping test the Jules Endpoint Agent! Due to the nature of this project, which involves installing system services and interacting with the Cloudflare network, automated testing is challenging. Therefore, we rely on this manual testing checklist to ensure that changes work as expected and don't introduce regressions.

Please perform these tests on a clean virtual machine for the operating system you are testing.

## Prerequisites for All Platforms

- A clean virtual machine (VM) of the target OS (Windows, Linux, macOS).
- A Cloudflare account.
- An API client like `curl` (available on Linux/macOS/WSL) or Postman to make HTTP requests to the endpoint.

## Test Case 1: Successful Command Execution

The goal of this test is to ensure the agent can be installed correctly and can successfully clone a public repository and run a simple command.

We will use the following parameters for our test request:
- **Repository:** `https://github.com/jules-ai/pypackage-example.git`
- **Branch:** `main`
- **Command:** `ls -l` (for Linux/macOS) or `dir` (for Windows)

---

### ✅ Windows Native Test Plan

1.  **Run the Installer:**
    - Open PowerShell as an Administrator.
    - Run the installation command from the `README.md`.
    - Follow the on-screen prompts for username, password, and Cloudflare login.
    - **Expected:** The script completes without errors and displays a public URL and username.

2.  **Verify Services:**
    - Open the "Services" application on Windows.
    - **Expected:** Find two services, "Jules Endpoint Agent (shell2http)" and "cloudflared", and verify they are both "Running".

3.  **Make API Request:**
    - Using your API client, make a `POST` request to the `/run` path of the public URL you received.
    - Use Basic Authentication with the username and password you configured.
    - Send the following form data: `repo=https://github.com/jules-ai/pypackage-example.git`, `branch=main`, `test_cmd=dir`.
    - **Expected:** You should receive an `HTTP 200 OK` response. The body of the response should contain the output of the `dir` command, showing files like `README.md` and `setup.py`.

---

### ✅ Linux Test Plan

1.  **Run the Installer:**
    - Open a terminal.
    - Run the `install.sh` command from the `README.md`.
    - Follow the on-screen prompts.
    - **Expected:** The script completes without errors and displays a public URL and username.

2.  **Verify Services:**
    - In the terminal, run `sudo systemctl status jules-endpoint` and `sudo systemctl status cloudflared`.
    - **Expected:** Both services should be "active (running)".

3.  **Make API Request:**
    - Using `curl`, make a `POST` request to the `/run` path of your public URL.
    - Use the `-u "user:pass"` flag for authentication.
    - Send the following data: `-d "repo=https://github.com/jules-ai/pypackage-example.git" -d "branch=main" -d "test_cmd=ls -l"`.
    - **Expected:** You should receive an `HTTP 200 OK` response. The body should contain the output of `ls -l`, showing files like `README.md` and `setup.py`.

---

### ✅ macOS Test Plan

1.  **Run the Installer:**
    - Open the Terminal app.
    - Run the `install.sh` command from the `README.md`.
    - Follow the on-screen prompts.
    - **Expected:** The script completes without errors and displays a public URL and username.

2.  **Verify Services:**
    - In the terminal, run `sudo launchctl list | grep jules` and `sudo launchctl list | grep cloudflare`.
    - **Expected:** Both commands should return a result showing that the services are loaded.

3.  **Make API Request:**
    - Same as the Linux test plan, using `curl`.
    - **Expected:** Same as the Linux test plan.

## Test Case 2: Failed Command Execution

The goal of this test is to ensure the agent correctly reports a failure if the user-provided command fails.

1.  **Make API Request:**
    - Follow the same steps as in Test Case 1 for your platform, but change the `test_cmd` to a command that is guaranteed to fail, such as `exit 1`.
2.  **Verify Response:**
    - **Expected:** You should receive an `HTTP 500 Internal Server Error` response. The body of the response will still contain the logs from the script, which is useful for debugging.
