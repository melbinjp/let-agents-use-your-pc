# jules-endpoint-agent: runner.ps1
#
# This PowerShell script is executed by shell2http. It clones a Git repository
# and runs a command inside it on a Windows environment.
#
# WARNING: This script uses Invoke-Expression to execute the command provided in the
# 'test_cmd' variable. This is powerful but dangerous if the source is untrusted.
# The endpoint should only be run in a sandboxed environment.
#
# Environment Variables (from shell2http):
#   - repo: The full URL of the git repository to clone.
#   - branch: The branch of the repository to check out.
#   - test_cmd: The shell command to execute.

# --- Script Configuration ---

# Stop script on any error. Equivalent to 'set -e' in Bash.
$ErrorActionPreference = 'Stop'

# --- Pre-flight Checks ---

# Check for required environment variables.
if (-not $env:repo -or -not $env:branch -or -not $env:test_cmd) {
    Write-Error "[ERROR] Missing required environment variables. Please provide 'repo', 'branch', and 'test_cmd'."
    exit 1
}

# --- Execution ---

# Create a temporary directory for the test run.
$tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "jules-run-$(Get-Random)")

# Use a try...finally block to ensure cleanup, even if errors occur.
try {
    Write-Host "[INFO] Created temporary directory at: $($tempDir.FullName)"
    Set-Location -Path $tempDir.FullName

    Write-Host "[INFO] Cloning repository: $env:repo (branch: $env:branch)"
    # Clone a specific branch with a depth of 1 for efficiency.
    git clone --depth 1 -b $env:branch $env:repo "repo"
    Set-Location -Path (Join-Path $tempDir.FullName "repo")

    Write-Host "[INFO] Repository cloned. Current working directory: $(Get-Location)"
    Write-Host "[INFO] ---"
    Write-Host "[INFO] Executing command: $env:test_cmd"
    Write-Host "[INFO] ---"

    # Execute the provided command.
    # The output of this command will be the main body of the HTTP response.
    try {
        # Using "cmd /c" is a robust way to execute an arbitrary command string
        # and correctly capture its exit code.
        & cmd.exe /c $env:test_cmd
        $lastExitCode = $LASTEXITCODE
        Write-Host "[INFO] ---"
        Write-Host "[INFO] Command finished with exit code $lastExitCode."
        exit $lastExitCode
    }
    catch {
        Write-Error "[ERROR] A terminating error occurred: $_"
        exit 1
    }
}
finally {
    Write-Host "[INFO] Cleaning up temporary directory..."
    Remove-Item -Recurse -Force -Path $tempDir.FullName
}
