<#
.SYNOPSIS
    Build and start a dev container using @devcontainers/cli.

.DESCRIPTION
    Builds and starts a dev container from the workspace's .devcontainer/ config.
    Outputs the container ID on the last line for callers to capture.

.EXAMPLE
    ./devcontainer-up.ps1 -Workspace /path/to/repo

.EXAMPLE
    ./devcontainer-up.ps1 -Workspace /path/to/repo -Name myapp-feature-x
#>

param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$Name
)

$ErrorActionPreference = 'Stop'

# --- Validation ---

$Workspace = (Resolve-Path $Workspace).Path

if (-not (Test-Path (Join-Path $Workspace ".devcontainer")) -and
    -not (Test-Path (Join-Path $Workspace ".devcontainer.json"))) {
    Write-Error "No .devcontainer/ directory or .devcontainer.json found in '$Workspace'."
    exit 1
}

# --- Build and start the dev container ---

Write-Host "Building and starting dev container for workspace: $Workspace"

$DevcontainerArgs = @(
    "up",
    "--workspace-folder", $Workspace,
    "--id-label", "devcontainer.local_folder=$Workspace"
)

if ($Name) {
    $DevcontainerArgs += @("--id-label", "devcontainer.name=$Name")
    Write-Host "Container name label: $Name"
}

$Output = & devcontainer @DevcontainerArgs 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Error "devcontainer up failed (exit code $LASTEXITCODE):`n$Output"
    exit 1
}

Write-Host "Dev container started successfully."

# Parse the container ID from the JSON output
$Match = [regex]::Match($Output, '"containerId"\s*:\s*"([^"]+)"')

if ($Match.Success) {
    $ContainerId = $Match.Groups[1].Value
    Write-Host "Container ID: $ContainerId"
    Write-Output $ContainerId
} else {
    Write-Host "Warning: Could not parse container ID from devcontainer output."
    Write-Host $Output
    Write-Output "unknown"
}

exit 0
