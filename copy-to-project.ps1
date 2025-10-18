# Helper script to copy generated files to your project repo (Windows PowerShell)

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("docker", "native")]
    [string]$Mode = "docker"
)

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "  Jules Hardware Access - Copy Files to Project" -ForegroundColor Blue
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host ""

# Check if project path provided
if (-not $ProjectPath) {
    Write-Host "Usage: .\copy-to-project.ps1 -ProjectPath C:\path\to\your\project [-Mode docker|native]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\copy-to-project.ps1 -ProjectPath C:\projects\my-app"
    Write-Host "  .\copy-to-project.ps1 -ProjectPath C:\projects\my-app -Mode docker"
    Write-Host "  .\copy-to-project.ps1 -ProjectPath C:\projects\my-app -Mode native"
    Write-Host ""
    exit 1
}

# Validate project path
if (-not (Test-Path $ProjectPath)) {
    Write-Host "✗ Project directory not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Check if generated files exist
$SourceDir = "generated_files\$Mode"
if (-not (Test-Path $SourceDir)) {
    Write-Host "✗ Generated files not found: $SourceDir" -ForegroundColor Red
    Write-Host "Run setup first:" -ForegroundColor Yellow
    if ($Mode -eq "docker") {
        Write-Host "  cd docker; .\setup.ps1"
    } else {
        Write-Host "  python setup.py"
    }
    exit 1
}

Write-Host "ℹ Copying $Mode files to: $ProjectPath" -ForegroundColor Blue
Write-Host ""

# Copy .jules directory
$JulesSource = Join-Path $SourceDir ".jules"
if (Test-Path $JulesSource) {
    Write-Host "→ Copying .jules/ directory..." -ForegroundColor Blue
    $JulesDest = Join-Path $ProjectPath ".jules"
    Copy-Item -Path $JulesSource -Destination $JulesDest -Recurse -Force
    Write-Host "✓ Copied .jules/" -ForegroundColor Green
} else {
    Write-Host "⚠ .jules/ directory not found in $SourceDir" -ForegroundColor Yellow
}

# Copy AGENTS.md
$AgentsSource = Join-Path $SourceDir "AGENTS.md"
if (Test-Path $AgentsSource) {
    Write-Host "→ Copying AGENTS.md..." -ForegroundColor Blue
    $AgentsDest = Join-Path $ProjectPath "AGENTS.md"
    Copy-Item -Path $AgentsSource -Destination $AgentsDest -Force
    Write-Host "✓ Copied AGENTS.md" -ForegroundColor Green
} else {
    Write-Host "⚠ AGENTS.md not found in $SourceDir" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✓ Files copied successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Blue
Write-Host "  cd $ProjectPath"
Write-Host "  git add .jules/ AGENTS.md"
Write-Host "  git commit -m `"Add Jules hardware access`""
Write-Host "  git push"
Write-Host ""
Write-Host "ℹ Jules will now be able to access your hardware when working on this project!" -ForegroundColor Blue
