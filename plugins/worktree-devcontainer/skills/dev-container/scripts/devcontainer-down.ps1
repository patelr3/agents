<#
.SYNOPSIS
    Stop and remove a dev container — best-effort, never fails the caller.

.DESCRIPTION
    Stops and removes the dev container associated with the given workspace.
    Falls back to finding the container by label and force-removing it.
    Always exits 0.

.EXAMPLE
    ./devcontainer-down.ps1 -Workspace /path/to/repo

.EXAMPLE
    ./devcontainer-down.ps1 -Workspace /path/to/repo -Name myapp-feature-x
#>

param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [string]$Name
)

$ErrorActionPreference = 'SilentlyContinue'

# Resolve workspace path (best-effort)
if (Test-Path $Workspace) {
    $Workspace = (Resolve-Path $Workspace).Path
}

Write-Host "Stopping dev container for workspace: $Workspace"

# Try devcontainer down first (available in newer versions of @devcontainers/cli)
& devcontainer down --workspace-folder $Workspace 2>$null

# Fallback: find container by label and force-remove it
$ContainerId = & docker ps -aq --filter "label=devcontainer.local_folder=$Workspace" 2>$null | Select-Object -First 1

if ($ContainerId) {
    Write-Host "Found container $ContainerId by workspace label, force-removing..."
    & docker rm -f $ContainerId 2>$null
}

# Also try by name label if provided
if ($Name) {
    $ContainerId = & docker ps -aq --filter "label=devcontainer.name=$Name" 2>$null | Select-Object -First 1
    if ($ContainerId) {
        Write-Host "Found container $ContainerId by name label, force-removing..."
        & docker rm -f $ContainerId 2>$null
    }
}

Write-Host "Dev container cleaned up: $Workspace"
exit 0
