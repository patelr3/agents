<#
.SYNOPSIS
    Cleanup a git worktree — best-effort, never fails the caller.
#>
param(
    [Parameter(Mandatory)]
    [string]$WorktreeDir
)

$ErrorActionPreference = 'SilentlyContinue'

# Navigate to the repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    Push-Location $repoRoot
}

try {
    git worktree remove $WorktreeDir --force 2>$null
    git worktree prune 2>$null

    if (Test-Path $WorktreeDir) {
        Remove-Item -Path $WorktreeDir -Recurse -Force
        git worktree prune 2>$null
    }

    Write-Host "Worktree cleaned up: $WorktreeDir"
} finally {
    if ($repoRoot) {
        Pop-Location
    }
}

exit 0
