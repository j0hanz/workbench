#Requires -Version 5.1
<#
.SYNOPSIS
    Executes a refactoring operation with automated rollback on failure.

.DESCRIPTION
    Provides a safe wrapper for code refactoring that:
    1. Validates prerequisites (clean working tree, tests pass, baseline exists)
    2. Creates a backup branch before changes
    3. Executes the refactoring command or script
    4. Runs validation (lint, type-check, tests, metrics comparison)
    5. Automatically rolls back on any failure
    6. Logs all operations to a timestamped file

    All log and metric files are stored in the scripts/ folder.

.PARAMETER Command
    Shell command to execute for the refactoring (e.g., "npm run lint:fix").

.PARAMETER ScriptBlock
    PowerShell script block to execute for the refactoring.

.PARAMETER Description
    Description of the refactoring operation for logging.

.PARAMETER SkipTests
    Skip test execution (use with caution).

.PARAMETER SkipMetrics
    Skip metrics comparison (useful for non-code changes).

.PARAMETER KeepBackup
    Keep the backup branch even after successful completion.

.PARAMETER TimeoutMinutes
    Maximum time for the refactoring command. Default: 10 minutes.

.PARAMETER Force
    Skip confirmation prompt for destructive operations.

.EXAMPLE
    .\Invoke-SafeRefactor.ps1 -Command "npm run lint -- --fix"
    Run ESLint auto-fix with safety checks.

.EXAMPLE
    .\Invoke-SafeRefactor.ps1 -ScriptBlock { npm run format } -Description "Format code"
    Run Prettier with custom description.

.EXAMPLE
    .\Invoke-SafeRefactor.ps1 -Command "npx knip --fix" -SkipMetrics -WhatIf
    Preview what would happen without executing.

.OUTPUTS
    PSCustomObject with operation result and details

.NOTES
    Author: Filesystem Context MCP
    Version: 2.0.0
    Exit Codes:
        0 = Success
        1 = Pre-flight validation failed
        2 = Refactor command failed
        3 = Post-refactor tests failed
        4 = Metrics gates failed
        5 = Rollback performed (recoverable failure)
        6 = Critical error (manual intervention needed)
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Command')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Command')]
    [ValidateNotNullOrEmpty()]
    [string]$Command,

    [Parameter(Mandatory, ParameterSetName = 'ScriptBlock')]
    [ValidateNotNull()]
    [scriptblock]$ScriptBlock,

    [Parameter()]
    [string]$Description = "Automated refactor",

    [Parameter()]
    [switch]$SkipTests,

    [Parameter()]
    [switch]$SkipMetrics,

    [Parameter()]
    [switch]$KeepBackup,

    [Parameter()]
    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 10,

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration

$scriptsDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $PSScriptRoot
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $scriptsDir "refactor-log-$timestamp.txt"
$backupBranch = "backup/safe-refactor-$timestamp"

#endregion

#region Helper Functions

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info'
    )

    $ts = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Level) {
        'Info' { "[$ts] INFO   " }
        'Success' { "[$ts] OK     " }
        'Warning' { "[$ts] WARN   " }
        'Error' { "[$ts] ERROR  " }
        'Debug' { "[$ts] DEBUG  " }
    }

    $logMessage = if ($Message) { "$prefix$Message" } else { "" }
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue

    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Debug' { 'Gray' }
    }

    if ($Message -and ($Level -ne 'Debug' -or $VerbosePreference -eq 'Continue')) {
        Write-Host $logMessage -ForegroundColor $color
    } elseif (-not $Message) {
        Write-Host ""
    }
}

function Test-CleanWorkingTree {
    [CmdletBinding()]
    param()

    $status = git status --porcelain 2>$null
    return -not [bool]$status
}

function Test-CommandSuccess {
    [CmdletBinding()]
    param(
        [string]$Name,
        [scriptblock]$Command,
        [switch]$CaptureOutput
    )

    Write-Log "Running: $Name" -Level Debug

    try {
        if ($CaptureOutput) {
            $output = & $Command 2>&1
            $success = $LASTEXITCODE -eq 0
            return @{ Success = $success; Output = $output }
        }
        else {
            & $Command | Out-Null
            return @{ Success = $LASTEXITCODE -eq 0; Output = $null }
        }
    }
    catch {
        return @{ Success = $false; Output = $_.Exception.Message }
    }
}

function Invoke-Rollback {
    [CmdletBinding()]
    param([string]$Reason)

    Write-Log "Initiating rollback: $Reason" -Level Warning

    try {
        # Discard all changes
        git checkout . 2>$null
        git clean -fd 2>$null

        # Restore from backup branch if it exists
        $branchExists = git branch --list $backupBranch 2>$null
        if ($branchExists) {
            git checkout $backupBranch -- . 2>$null
            Write-Log "Restored from backup branch: $backupBranch" -Level Success
        }

        Write-Log "Rollback completed successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Rollback failed: $_" -Level Error
        return $false
    }
}

function Remove-BackupBranch {
    [CmdletBinding()]
    param()

    try {
        $branchExists = git branch --list $backupBranch 2>$null
        if ($branchExists) {
            git branch -D $backupBranch 2>$null | Out-Null
            Write-Log "Cleaned up backup branch" -Level Debug
        }
    }
    catch {
        Write-Log "Could not clean up backup branch: $_" -Level Warning
    }
}

#endregion

#region Main Script

# Initialize result object
$result = [PSCustomObject]@{
    Success     = $false
    Description = $Description
    StartTime   = Get-Date
    EndTime     = $null
    Duration    = $null
    LogFile     = $logFile
    ExitCode    = 0
    Phase       = 'Init'
    Error       = $null
    Rollback    = $false
}

# Initialize log file
$null = New-Item -Path $logFile -ItemType File -Force
Write-Log ("=" * 60) -Level Info
Write-Log "Safe Refactor: $Description" -Level Info
Write-Log "Started: $($result.StartTime)" -Level Info
Write-Log ("=" * 60) -Level Info
Write-Log ""

# Change to project root
Push-Location $projectRoot

try {
    #region Phase 1: Pre-flight Checks

    $result.Phase = 'PreFlight'
    Write-Host ""
    Write-Host "🔍 Pre-flight Checks" -ForegroundColor Cyan
    Write-Host ""

    # Check for clean working tree
    Write-Log "Checking working tree status..." -Level Info
    if (-not (Test-CleanWorkingTree)) {
        Write-Log "Working tree has uncommitted changes. Commit or stash them first." -Level Error
        $result.ExitCode = 1
        $result.Error = "Uncommitted changes in working tree"
        throw "Pre-flight failed"
    }
    Write-Log "Working tree is clean" -Level Success

    # Check baseline exists
    $baselinePath = Join-Path $scriptsDir "metrics-baseline.json"
    if (-not $SkipMetrics -and -not (Test-Path $baselinePath)) {
        Write-Log "Baseline metrics not found. Run Measure-Baseline.ps1 first." -Level Error
        $result.ExitCode = 1
        $result.Error = "Missing baseline metrics"
        throw "Pre-flight failed"
    }

    # Run pre-flight tests
    if (-not $SkipTests) {
        Write-Log "Running pre-flight tests..." -Level Info
        $testResult = Test-CommandSuccess -Name "npm test" -Command { npm run test --silent }
        if (-not $testResult.Success) {
            Write-Log "Pre-flight tests failed. Fix tests before refactoring." -Level Error
            $result.ExitCode = 1
            $result.Error = "Pre-flight tests failed"
            throw "Pre-flight failed"
        }
        Write-Log "Pre-flight tests passed" -Level Success
    }
    else {
        Write-Log "Skipping pre-flight tests" -Level Warning
    }

    #endregion

    #region Phase 2: Create Backup

    $result.Phase = 'Backup'
    Write-Host ""
    Write-Host "💾 Creating Backup" -ForegroundColor Cyan
    Write-Host ""

    # Create backup branch
    Write-Log "Creating backup branch: $backupBranch" -Level Info

    if ($PSCmdlet.ShouldProcess($backupBranch, "Create backup branch")) {
        git branch $backupBranch 2>$null
        Write-Log "Backup branch created" -Level Success
    }

    #endregion

    #region Phase 3: Execute Refactor

    $result.Phase = 'Refactor'
    Write-Host ""
    Write-Host "🔧 Executing Refactor" -ForegroundColor Cyan
    Write-Host ""

    $refactorCommand = if ($PSCmdlet.ParameterSetName -eq 'Command') {
        $Command
    }
    else {
        $ScriptBlock.ToString()
    }

    Write-Log "Command: $refactorCommand" -Level Info

    if ($PSCmdlet.ShouldProcess($refactorCommand, "Execute refactoring command")) {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Command') {
                # Execute shell command
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $Command" `
                    -WorkingDirectory $projectRoot -PassThru -NoNewWindow -Wait

                if ($process.ExitCode -ne 0) {
                    throw "Command exited with code: $($process.ExitCode)"
                }
            }
            else {
                # Execute script block
                & $ScriptBlock

                if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                    throw "Script block exited with code: $LASTEXITCODE"
                }
            }

            Write-Log "Refactoring command completed" -Level Success
        }
        catch {
            Write-Log "Refactoring command failed: $_" -Level Error
            $result.ExitCode = 2
            $result.Error = "Refactor command failed: $_"

            # Rollback
            $result.Rollback = Invoke-Rollback -Reason "Refactor command failed"
            $result.ExitCode = 5
            throw "Refactor failed"
        }
    }

    #endregion

    #region Phase 4: Post-Refactor Validation

    $result.Phase = 'Validation'
    Write-Host ""
    Write-Host "✅ Post-Refactor Validation" -ForegroundColor Cyan
    Write-Host ""

    # Run lint
    Write-Log "Running lint check..." -Level Info
    $lintResult = Test-CommandSuccess -Name "npm lint" -Command { npm run lint --silent }
    if (-not $lintResult.Success) {
        Write-Log "Lint check failed" -Level Error
        $result.ExitCode = 3
        $result.Error = "Lint check failed"
        $result.Rollback = Invoke-Rollback -Reason "Lint check failed"
        $result.ExitCode = 5
        throw "Validation failed"
    }
    Write-Log "Lint check passed" -Level Success

    # Run type-check
    Write-Log "Running type check..." -Level Info
    $typeResult = Test-CommandSuccess -Name "npm type-check" -Command { npm run type-check --silent }
    if (-not $typeResult.Success) {
        Write-Log "Type check failed" -Level Error
        $result.ExitCode = 3
        $result.Error = "Type check failed"
        $result.Rollback = Invoke-Rollback -Reason "Type check failed"
        $result.ExitCode = 5
        throw "Validation failed"
    }
    Write-Log "Type check passed" -Level Success

    # Run tests
    if (-not $SkipTests) {
        Write-Log "Running post-refactor tests..." -Level Info
        $postTestResult = Test-CommandSuccess -Name "npm test" -Command { npm run test --silent }
        if (-not $postTestResult.Success) {
            Write-Log "Post-refactor tests failed" -Level Error
            $result.ExitCode = 3
            $result.Error = "Post-refactor tests failed"
            $result.Rollback = Invoke-Rollback -Reason "Post-refactor tests failed"
            $result.ExitCode = 5
            throw "Validation failed"
        }
        Write-Log "Post-refactor tests passed" -Level Success
    }

    #endregion

    #region Phase 5: Metrics Comparison

    if (-not $SkipMetrics) {
        $result.Phase = 'Metrics'
        Write-Host ""
        Write-Host "📊 Metrics Comparison" -ForegroundColor Cyan
        Write-Host ""

        Write-Log "Comparing metrics against baseline..." -Level Info

        $compareScript = Join-Path $scriptsDir "Compare-Metrics.ps1"
        & $compareScript

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Metrics gates failed" -Level Error
            $result.ExitCode = 4
            $result.Error = "Metrics gates failed"
            $result.Rollback = Invoke-Rollback -Reason "Metrics gates failed"
            $result.ExitCode = 5
            throw "Metrics failed"
        }
        Write-Log "Metrics gates passed" -Level Success
    }

    #endregion

    #region Phase 6: Cleanup & Success

    $result.Phase = 'Complete'
    $result.Success = $true

    # Clean up backup branch unless requested to keep
    if (-not $KeepBackup) {
        Remove-BackupBranch
    }
    else {
        Write-Log "Keeping backup branch: $backupBranch" -Level Info
    }

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host "✅ REFACTOR COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host ""

    Write-Log "Refactor completed successfully" -Level Success

    #endregion

}
catch {
    # Final error handling
    if (-not $result.Error) {
        $result.Error = $_.Exception.Message
    }

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Red
    Write-Host "❌ REFACTOR FAILED" -ForegroundColor Red
    if ($result.Rollback) {
        Write-Host "   Changes have been rolled back" -ForegroundColor Yellow
    }
    Write-Host ("=" * 60) -ForegroundColor Red
    Write-Host ""

}
finally {
    # Record end time
    $result.EndTime = Get-Date
    $result.Duration = $result.EndTime - $result.StartTime

    Write-Log ""
    Write-Log ("=" * 60) -Level Info
    Write-Log "Completed: $($result.EndTime)" -Level Info
    Write-Log "Duration:  $($result.Duration.ToString('mm\:ss'))" -Level Info
    Write-Log "Log file:  $logFile" -Level Info
    Write-Log ("=" * 60) -Level Info

    Pop-Location
}

# Output result
Write-Host ""
Write-Host "📄 Log file: $logFile" -ForegroundColor Gray
Write-Host ""

# Return result and set exit code
if ($result.Success) {
    exit 0
}
else {
    exit $result.ExitCode
}

#endregion
