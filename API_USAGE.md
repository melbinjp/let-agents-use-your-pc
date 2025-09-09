# Agent Usage Guide

This document provides the technical specification for interacting with a Jules Endpoint Agent.

---

## Endpoint URL

The user who set up the agent will provide you with a unique public URL. This is the base URL for all requests. It will look something like this:

`https://your-tunnel-name.trycloudflare.com`

All API paths are relative to this base URL.

---

## Authentication

The endpoint is protected by **HTTP Basic Authentication**. You must include the username and password provided by the user in every request.

In `curl`, you can do this with the `-u` or `--user` flag:

```bash
curl -u "your_username:your_password" ...
```

Failure to provide correct credentials will result in a `401 Unauthorized` response.

---

## API: Execute Command

This is the primary endpoint for executing a command in a fresh clone of a Git repository.

- **Path:** `/run`
- **Method:** `POST`
- **Content-Type:** `application/x-www-form-urlencoded`

### Request Parameters

The following parameters must be sent in the POST body:

| Parameter  | Type   | Required | Description                                                              |
|------------|--------|----------|--------------------------------------------------------------------------|
| `repo`     | string | Yes      | The full HTTPS URL of the Git repository to clone.                       |
| `branch`   | string | Yes      | The branch, tag, or commit hash to check out.                            |
| `test_cmd` | string | Yes      | The shell command to be executed in the root of the cloned repository.   |

### Example Request

Here is a complete example using `curl` to clone the official Git repository and run `make test`.

```bash
curl -X POST "https://your-tunnel-name.trycloudflare.com/run" \
  -u "jules:p@ssw0rd123" \
  --data-urlencode "repo=https://github.com/git/git.git" \
  --data-urlencode "branch=master" \
  --data-urlencode "test_cmd=make test"
```
*(Note: `--data-urlencode` is recommended over `-d` to ensure all characters are safely transmitted.)*

---

## Response

### On Success (Command Execution Started)

If the request is valid, the endpoint will stream the raw output of the `runner.sh` script.

- **HTTP Status Code:** `200 OK`
- **Content-Type:** `text/plain`
- **Body:** The combined `stdout` and `stderr` from the `runner.sh` script and the `test_cmd` you provided. This will include `[INFO]` logs from the runner itself.

```
[INFO] Created temporary directory at: /tmp/jules-run-aBcDeF
[INFO] Cloning repository: https://github.com/git/git.git (branch: master)
... (git clone output) ...
[INFO] Repository cloned. Current working directory: /tmp/jules-run-aBcDeF/repo
[INFO] ---
[INFO] Executing command: make test
[INFO] ---
... (output of 'make test') ...
[INFO] ---
[INFO] Command finished with exit code 0.
[INFO] Cleaning up temporary directory...
```

### On Script Failure (Non-Zero Exit Code)

The `shell2http` service is configured to return an HTTP 500 error if the `runner.sh` script (or your `test_cmd`) exits with a non-zero status code. This is the primary way to programmatically detect a failure.

- **HTTP Status Code:** `500 Internal Server Error`
- **Body:** The same `text/plain` output as a successful run, allowing you to inspect the logs to find the cause of the failure.

### On Request Error

If you provide invalid parameters (e.g., missing `repo`), the script will exit early and you will receive a `500 Internal Server Error` with a descriptive error message in the body.

```
[ERROR] Missing required environment variables.
[ERROR] Please provide 'repo', 'branch', and 'test_cmd' in the POST data.
```
