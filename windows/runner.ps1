# jules-endpoint-agent: runner.ps1
#
# This PowerShell script is executed via SSH. It clones a Git repository
# and runs a command inside it on a Windows environment.
#
# WARNING: This script uses Invoke-Expression to execute the command provided as the
# third argument. This is powerful but dangerous if the source is untrusted.
# The endpoint should only be run in a sandboxed environment.
#
# Usage:
#   ./runner.ps1 <repo_url> <branch_name> <command_to_run>

# --- Script Configuration ---

# Stop script on any error. Equivalent to 'set -e' in Bash.
$ErrorActionPreference = 'Stop'

# --- Pre-flight Checks ---

# Check that all required arguments are provided.
if ($args.Count -ne 3) {
    Write-Error "[ERROR] Invalid number of arguments. Usage: runner.ps1 <repo_url> <branch_name> <command_to_run>"
    exit 1
}

$repoUrl = $args[0]
$branchName = $args[1]
$testCmd = $args[2]

# --- Execution ---

# Create a temporary directory for the test run.
$tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "jules-run-$(Get-Random)")

# Use a try...finally block to ensure cleanup, even if errors occur.
try {
    Write-Host "[INFO] Created temporary directory at: $($tempDir.FullName)"
    Set-Location -Path $tempDir.FullName

    Write-Host "[INFO] Cloning repository: $repoUrl (branch: $branchName)"
    # Clone a specific branch with a depth of 1 for efficiency.
    git clone --depth 1 -b $branchName $repoUrl "repo"
    Set-Location -Path (Join-Path $tempDir.FullName "repo")

    Write-Host "[INFO] Repository cloned. Current working directory: $(Get-Location)"
    Write-Host "[INFO] ---"
    Write-Host "[INFO] Executing command: $testCmd"
    Write-Host "[INFO] ---"

    # Execute the provided command.
    # The output of this command will be the main body of the response.
    try {
        Invoke-Expression -Command $testCmd
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
