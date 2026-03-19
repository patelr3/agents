<#
.SYNOPSIS
    Setup Git Worktree - Create a branch and worktree without changing HEAD.

.DESCRIPTION
    Creates a new branch from BaseRef (default: HEAD) using git update-ref so the
    current working tree is never disturbed, then adds a worktree for that branch.

.EXAMPLE
    ./setup-worktree.ps1 -Branch feat/new-feature -BaseRef main

.EXAMPLE
    ./setup-worktree.ps1 -Branch fix/bug-123 -ExistingBranch

.EXAMPLE
    ./setup-worktree.ps1 -Branch ralph/task-1 -PlanFile docs/plan.md -PlanStatus inprogress
#>

param(
    [Parameter(Mandatory)]
    [string]$Branch,

    [string]$BaseRef = "HEAD",

    [string]$WorktreeDir,

    [switch]$ExistingBranch,

    [string]$PlanFile,

    [string]$PlanStatus
)

$ErrorActionPreference = 'Stop'

# --- Validation ---

$RepoRoot = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not inside a git repository."
    exit 1
}

$null = git rev-parse --verify $BaseRef 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "base-ref '$BaseRef' does not resolve to a valid commit."
    exit 1
}

# --- Auto-derive worktree directory ---

if (-not $WorktreeDir) {
    $ProjectName = Split-Path -Leaf $RepoRoot
    $BranchSuffix = $Branch -replace '^(feat|fix|chore|ralph)/', ''
    $WorktreeDir = Join-Path (Split-Path -Parent $RepoRoot) "${ProjectName}-${BranchSuffix}"
}

if (Test-Path $WorktreeDir) {
    Write-Error "Worktree directory already exists: $WorktreeDir"
    exit 1
}

# --- Create or fetch branch ---

if ($ExistingBranch) {
    Write-Host "Fetching existing branch '$Branch' from origin..."
    git fetch origin $Branch
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    Write-Host "Creating branch '$Branch' from '$BaseRef' (without changing HEAD)..."
    $ResolvedRef = git rev-parse $BaseRef
    if ($LASTEXITCODE -ne 0) { exit 1 }
    git update-ref "refs/heads/$Branch" $ResolvedRef
    if ($LASTEXITCODE -ne 0) { exit 1 }
    Write-Host "Pushing branch '$Branch' to origin..."
    git push -u origin $Branch
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- Create worktree ---

Write-Host "Adding worktree at '$WorktreeDir' for branch '$Branch'..."
git worktree add $WorktreeDir $Branch
if ($LASTEXITCODE -ne 0) { exit 1 }

if (-not (Test-Path $WorktreeDir)) {
    Write-Error "Worktree directory was not created: $WorktreeDir"
    exit 1
}

Write-Host "Worktree created successfully."

# --- Update plan file status ---

if ($PlanFile -and $PlanStatus) {
    Write-Host "Updating plan file status to '$PlanStatus'..."
    Push-Location $WorktreeDir

    try {
        if (-not (Test-Path $PlanFile)) {
            Write-Error "Plan file not found in worktree: $PlanFile"
            exit 1
        }

        # Replace only the first occurrence of status: ... in YAML frontmatter
        $Lines = (Get-Content $PlanFile -Raw) -split "`n"
        $Replaced = $false
        $UpdatedLines = foreach ($Line in $Lines) {
            if (-not $Replaced -and $Line -match '^status:') {
                "status: $PlanStatus"
                $Replaced = $true
            } else {
                $Line
            }
        }
        $UpdatedContent = $UpdatedLines -join "`n"
        Set-Content -Path $PlanFile -Value $UpdatedContent -NoNewline

        $PlanBaseName = Split-Path -Leaf $PlanFile
        git add -A
        if ($LASTEXITCODE -ne 0) { exit 1 }
        git commit -m "chore: set $PlanBaseName status to $PlanStatus"
        if ($LASTEXITCODE -ne 0) { exit 1 }
        git push
        if ($LASTEXITCODE -ne 0) { exit 1 }

        Write-Host "Plan file updated and pushed."
    } finally {
        Pop-Location
    }
}

# --- Output worktree path (last line for callers to capture) ---

Write-Output $WorktreeDir
exit 0
