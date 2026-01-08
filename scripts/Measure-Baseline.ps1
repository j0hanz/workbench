#Requires -Version 5.1
<#
.SYNOPSIS
    Captures baseline code quality metrics for refactoring comparison.

.DESCRIPTION
    Collects ESLint errors/warnings, jscpd code duplication percentage, and test
    coverage metrics. Outputs a structured JSON file for use with Compare-Metrics.ps1.

    All output files are stored in the scripts/ folder. Only the 'src' directory
    is analyzed by default.

.PARAMETER OutFile
    Output filename (relative to scripts/ folder). Default: metrics-baseline.json

.PARAMETER TargetPath
    Directories to analyze. Default: @("src")

.PARAMETER SkipCoverage
    Skip test coverage collection (faster for quick checks).

.PARAMETER PassThru
    Return the metrics object in addition to saving to file.

.EXAMPLE
    .\Measure-Baseline.ps1
    Captures baseline metrics to scripts/metrics-baseline.json

.EXAMPLE
    .\Measure-Baseline.ps1 -OutFile "before-refactor.json" -PassThru
    Captures metrics to custom file and returns the object.

.EXAMPLE
    .\Measure-Baseline.ps1 -SkipCoverage -Verbose
    Quick capture without coverage, with verbose logging.

.OUTPUTS
    PSCustomObject with metrics data (when -PassThru is specified)
    JSON file in scripts/ folder

.NOTES
    Author: Filesystem Context MCP
    Version: 2.0.0
    Requires: Node.js 20+, npm, eslint, jscpd
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [ValidatePattern('^[\w\-\.]+\.json$')]
    [string]$OutFile = "metrics-baseline.json",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetPath = @("src"),

    [Parameter()]
    [switch]$SkipCoverage,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function Test-CommandAvailable {
    [CmdletBinding()]
    param([string]$Command)

    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Get-ToolVersion {
    [CmdletBinding()]
    param([string]$Tool)

    try {
        switch ($Tool) {
            'node' { return (node --version 2>$null) -replace '^v', '' }
            'npm' { return (npm --version 2>$null) }
            'eslint' { return (npx eslint --version 2>$null) -replace '^v', '' }
            'jscpd' { return (npx jscpd --version 2>$null) -replace '^v', '' }
            default { return $null }
        }
    }
    catch {
        return $null
    }
}

function Get-GitInfo {
    [CmdletBinding()]
    param()

    $info = @{
        commit = $null
        branch = $null
        dirty  = $false
    }

    try {
        $info.commit = git rev-parse HEAD 2>$null
        $info.branch = git rev-parse --abbrev-ref HEAD 2>$null
        $status = git status --porcelain 2>$null
        $info.dirty = [bool]$status
    }
    catch {
        Write-Verbose "Git info unavailable: $_"
    }

    return $info
}

function Get-EslintMetrics {
    [CmdletBinding()]
    param([string[]]$Paths)

    $result = @{
        errors   = 0
        warnings = 0
        fixable  = 0
        files    = 0
    }

    try {
        Write-Verbose "Running ESLint on: $($Paths -join ', ')"
        $eslintArgs = @($Paths) + @('--format', 'json')
        $output = & npx eslint @eslintArgs 2>$null

        if ($output) {
            $eslintData = $output | ConvertFrom-Json -ErrorAction Stop

            foreach ($file in $eslintData) {
                $result.errors += $file.errorCount
                $result.warnings += $file.warningCount
                $result.fixable += $file.fixableErrorCount + $file.fixableWarningCount
                if ($file.errorCount -gt 0 -or $file.warningCount -gt 0) {
                    $result.files++
                }
            }
        }

        Write-Verbose "ESLint: $($result.errors) errors, $($result.warnings) warnings"
    }
    catch {
        Write-Warning "ESLint analysis failed: $_"
    }

    return $result
}

function Get-DuplicationMetrics {
    [CmdletBinding()]
    param(
        [string[]]$Paths,
        [string]$OutputDir
    )

    $result = @{
        percentage = 0.0
        clones     = 0
        sources    = 0
        lines      = 0
    }

    try {
        Write-Verbose "Running jscpd on: $($Paths -join ', ')"

        # Ensure output directory exists
        if (-not (Test-Path $OutputDir)) {
            $null = New-Item -Path $OutputDir -ItemType Directory -Force
        }

        $jscpdArgs = @(
            '--min-tokens', '50',
            '--reporters', 'json',
            '--output', $OutputDir,
            '--gitignore'
        ) + $Paths

        $null = & npx jscpd @jscpdArgs 2>$null

        $reportPath = Join-Path $OutputDir "jscpd-report.json"
        if (Test-Path $reportPath) {
            $dupData = Get-Content $reportPath -Raw | ConvertFrom-Json -ErrorAction Stop

            if ($dupData.statistics -and $dupData.statistics.total) {
                $total = $dupData.statistics.total
                $result.percentage = [math]::Round([double]$total.percentage, 2)
                $result.clones = [int]$total.clones
                $result.sources = [int]$total.sources
                $result.lines = [int]$total.duplicatedLines
            }
        }

        Write-Verbose "Duplication: $($result.percentage)% ($($result.clones) clones)"
    }
    catch {
        Write-Warning "Duplication analysis failed: $_"
    }

    return $result
}

function Get-CoverageMetrics {
    [CmdletBinding()]
    param([string]$TempDir)

    $result = @{
        lines      = 0.0
        branches   = 0.0
        functions  = 0.0
    }

    try {
        Write-Verbose "Running test coverage..."

        $coverageOutput = & npm run test:coverage 2>&1 | Out-String

        # Parse Node.js test runner coverage output
        # Format: "all files | line % | branch % | funcs %"
        $coverageMatch = [regex]::Match(
            $coverageOutput,
            'all files\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)'
        )

        if ($coverageMatch.Success) {
            $result.lines = [math]::Round([double]$coverageMatch.Groups[1].Value, 2)
            $result.branches = [math]::Round([double]$coverageMatch.Groups[2].Value, 2)
            $result.functions = [math]::Round([double]$coverageMatch.Groups[3].Value, 2)
            Write-Verbose "Coverage: $($result.lines)% lines, $($result.branches)% branches, $($result.functions)% functions"
        }
        else {
            # Fallback: try to find any percentage in coverage output
            $fallbackMatch = [regex]::Match($coverageOutput, '(\d+\.?\d*)\s*%')
            if ($fallbackMatch.Success) {
                $result.lines = [math]::Round([double]$fallbackMatch.Groups[1].Value, 2)
                Write-Verbose "Coverage (fallback): $($result.lines)% lines"
            }
            else {
                Write-Warning "Could not parse coverage output"
            }
        }
    }
    catch {
        Write-Warning "Coverage collection failed: $_"
    }

    return $result
}

#endregion

#region Main Script

# Resolve paths
$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = $PSScriptRoot
$outputPath = Join-Path $scriptsDir $OutFile
$jscpdDir = Join-Path $scriptsDir ".jscpd"

# Verify we're in the right location
if (-not (Test-Path (Join-Path $projectRoot "package.json"))) {
    throw "Cannot find package.json in project root: $projectRoot"
}

# Check required tools
$requiredTools = @('node', 'npm')
foreach ($tool in $requiredTools) {
    if (-not (Test-CommandAvailable $tool)) {
        throw "Required tool not found: $tool"
    }
}

# Collect git info
$gitInfo = Get-GitInfo

# Build metrics object
$metrics = [ordered]@{
    version      = "2.0"
    timestamp    = Get-Date -Format "o"
    git          = [ordered]@{
        commit = $gitInfo.commit
        branch = $gitInfo.branch
        dirty  = $gitInfo.dirty
    }
    targets      = $TargetPath
    metrics      = [ordered]@{
        eslint      = $null
        duplication = $null
        coverage    = $null
    }
    toolVersions = [ordered]@{
        node   = Get-ToolVersion 'node'
        npm    = Get-ToolVersion 'npm'
        eslint = Get-ToolVersion 'eslint'
        jscpd  = Get-ToolVersion 'jscpd'
    }
}

# Resolve target paths relative to project root
$resolvedPaths = $TargetPath | ForEach-Object {
    $fullPath = Join-Path $projectRoot $_
    if (Test-Path $fullPath) {
        $_
    }
    else {
        Write-Warning "Target path not found: $_"
        $null
    }
} | Where-Object { $_ }

if (-not $resolvedPaths) {
    throw "No valid target paths found"
}

# Change to project root for tool execution
Push-Location $projectRoot
try {
    # Collect ESLint metrics
    Write-Host "📊 Collecting ESLint metrics..." -ForegroundColor Cyan
    $metrics.metrics.eslint = Get-EslintMetrics -Paths $resolvedPaths

    # Collect duplication metrics
    Write-Host "📊 Collecting duplication metrics..." -ForegroundColor Cyan
    $metrics.metrics.duplication = Get-DuplicationMetrics -Paths $resolvedPaths -OutputDir $jscpdDir

    # Collect coverage metrics (optional)
    if (-not $SkipCoverage) {
        Write-Host "📊 Collecting coverage metrics..." -ForegroundColor Cyan
        $metrics.metrics.coverage = Get-CoverageMetrics -TempDir $scriptsDir
    }
    else {
        Write-Verbose "Skipping coverage collection"
        $metrics.metrics.coverage = @{
            lines      = $null
            branches   = $null
            functions  = $null
            statements = $null
            skipped    = $true
        }
    }
}
finally {
    Pop-Location
}

# Save metrics to file
if ($PSCmdlet.ShouldProcess($outputPath, "Save metrics")) {
    $jsonContent = $metrics | ConvertTo-Json -Depth 10
    $jsonContent | Set-Content -Path $outputPath -Encoding UTF8

    Write-Host ""
    Write-Host "✅ Baseline saved to: " -ForegroundColor Green -NoNewline
    Write-Host $outputPath -ForegroundColor White
    Write-Host ""

    # Summary output
    Write-Host "📈 Summary:" -ForegroundColor Cyan
    Write-Host "   ESLint Errors:   $($metrics.metrics.eslint.errors)" -ForegroundColor $(if ($metrics.metrics.eslint.errors -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "   ESLint Warnings: $($metrics.metrics.eslint.warnings)" -ForegroundColor $(if ($metrics.metrics.eslint.warnings -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "   Duplication:     $($metrics.metrics.duplication.percentage)%" -ForegroundColor $(if ($metrics.metrics.duplication.percentage -lt 5) { 'Green' } else { 'Yellow' })

    if (-not $SkipCoverage -and $metrics.metrics.coverage.lines) {
        Write-Host "   Coverage:        $($metrics.metrics.coverage.lines)%" -ForegroundColor $(if ($metrics.metrics.coverage.lines -ge 80) { 'Green' } elseif ($metrics.metrics.coverage.lines -ge 60) { 'Yellow' } else { 'Red' })
    }
}

# Return object if requested
if ($PassThru) {
    return [PSCustomObject]$metrics
}

#endregion
