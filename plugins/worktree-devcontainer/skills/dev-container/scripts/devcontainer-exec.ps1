<#
.SYNOPSIS
    Execute an AI tool inside a running dev container.

.DESCRIPTION
    Runs the specified AI tool command inside the dev container associated with
    the given workspace folder. Passes through the exit code from the tool.

.EXAMPLE
    ./devcontainer-exec.ps1 -Workspace /path/to/repo -Tool copilot -Prompt "Fix the login bug"

.EXAMPLE
    ./devcontainer-exec.ps1 -Workspace /path/to/repo -Tool claude -Prompt "Implement feature X"
#>

param(
    [Parameter(Mandatory)]
    [string]$Workspace,

    [Parameter(Mandatory)]
    [ValidateSet("copilot", "claude", "amp")]
    [string]$Tool,

    [Parameter(Mandatory)]
    [string]$Prompt
)

$ErrorActionPreference = 'Stop'

# --- Validation ---

$Workspace = (Resolve-Path $Workspace).Path

# --- Build the tool command ---

switch ($Tool) {
    "copilot" {
        $ToolCmd = "copilot -p `"$Prompt`""
    }
    "claude" {
        $ToolCmd = "claude -p `"$Prompt`" --allowedTools `"edit,write,bash,computer,mcp`" --dangerouslySkipPermissions"
    }
    "amp" {
        $ToolCmd = "amp -p `"$Prompt`""
    }
}

Write-Host "Executing $Tool inside dev container for workspace: $Workspace"
Write-Host "---"

# --- Run the command inside the dev container ---

& devcontainer exec `
    --workspace-folder $Workspace `
    sh -c $ToolCmd

$ExitCode = $LASTEXITCODE

Write-Host "---"
Write-Host "Tool '$Tool' exited with code: $ExitCode"

exit $ExitCode
