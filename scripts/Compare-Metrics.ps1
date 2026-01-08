#Requires -Version 5.1
<#
.SYNOPSIS
    Compares current code quality metrics against a baseline.

.DESCRIPTION
    Reads baseline and current metrics JSON files, compares them against configurable
    thresholds, and reports pass/fail status with detailed deltas. Supports multiple
    output formats including console, JSON, and markdown.

    All metric files are read from the scripts/ folder.

.PARAMETER BaselineFile
    Baseline metrics filename (relative to scripts/). Default: metrics-baseline.json

.PARAMETER CurrentFile
    Current metrics filename (relative to scripts/). Default: metrics-current.json

.PARAMETER ReportFile
    Optional markdown report filename (relative to scripts/).

.PARAMETER CoverageThreshold
    Maximum allowed coverage decrease in percentage points. Default: 0

.PARAMETER DuplicationThreshold
    Maximum allowed duplication increase in percentage points. Default: 0

.PARAMETER ComplexityThreshold
    Maximum allowed ESLint error increase. Default: 0

.PARAMETER Strict
    Treat any regression (including warnings) as failure.

.PARAMETER SkipCurrentCapture
    Use existing current file instead of capturing new metrics.

.PARAMETER PassThru
    Return comparison result object in addition to console output.

.EXAMPLE
    .\Compare-Metrics.ps1
    Compares baseline vs newly captured current metrics.

.EXAMPLE
    .\Compare-Metrics.ps1 -CoverageThreshold 2 -Verbose
    Allow up to 2% coverage drop with verbose output.

.EXAMPLE
    .\Compare-Metrics.ps1 -ReportFile "comparison.md" -PassThru
    Generate markdown report and return comparison object.

.OUTPUTS
    PSCustomObject with comparison results (when -PassThru is specified)

.NOTES
    Author: Filesystem Context MCP
    Version: 2.0.0
    Exit Codes:
        0 = All gates passed
        1 = One or more gates failed
        2 = Error (missing files, invalid JSON, etc.)
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidatePattern('^[\w\-\.]+\.json$')]
    [string]$BaselineFile = "metrics-baseline.json",

    [Parameter(Position = 1)]
    [ValidatePattern('^[\w\-\.]+\.json$')]
    [string]$CurrentFile = "metrics-current.json",

    [Parameter()]
    [ValidatePattern('^[\w\-\.]+\.md$')]
    [string]$ReportFile,

    [Parameter()]
    [ValidateRange(0, 100)]
    [double]$CoverageThreshold = 0,

    [Parameter()]
    [ValidateRange(0, 100)]
    [double]$DuplicationThreshold = 0,

    [Parameter()]
    [ValidateRange(0, 1000)]
    [int]$ComplexityThreshold = 0,

    [Parameter()]
    [switch]$Strict,

    [Parameter()]
    [switch]$SkipCurrentCapture,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function Get-MetricStatus {
    [CmdletBinding()]
    param(
        [double]$Before,
        [double]$After,
        [double]$Threshold,
        [ValidateSet('LowerIsBetter', 'HigherIsBetter')]
        [string]$Direction
    )

    $delta = $After - $Before

    if ($Direction -eq 'HigherIsBetter') {
        # For coverage: decrease is bad
        if ($delta -lt - $Threshold) {
            return 'fail'
        }
        elseif ($delta -lt 0) {
            return 'warn'
        }
        return 'pass'
    }
    else {
        # For errors/duplication: increase is bad
        if ($delta -gt $Threshold) {
            return 'fail'
        }
        elseif ($delta -gt 0) {
            return 'warn'
        }
        return 'pass'
    }
}

function Format-Delta {
    [CmdletBinding()]
    param(
        [double]$Delta,
        [string]$Unit = '',
        [bool]$HigherIsBetter = $false
    )

    $sign = if ($Delta -gt 0) { '+' } elseif ($Delta -lt 0) { '' } else { '±' }
    $formatted = "{0}{1:N2}{2}" -f $sign, $Delta, $Unit

    return $formatted
}

function Write-ColoredStatus {
    [CmdletBinding()]
    param(
        [string]$Label,
        [string]$Before,
        [string]$After,
        [string]$Delta,
        [string]$Status
    )

    $color = switch ($Status) {
        'pass' { 'Green' }
        'warn' { 'Yellow' }
        'fail' { 'Red' }
        default { 'White' }
    }

    $icon = switch ($Status) {
        'pass' { '✅' }
        'warn' { '⚠️' }
        'fail' { '❌' }
        default { '❓' }
    }

    Write-Host "  $icon " -NoNewline
    Write-Host "$Label`t" -NoNewline -ForegroundColor White
    Write-Host "$Before → $After " -NoNewline -ForegroundColor Gray
    Write-Host "($Delta)" -ForegroundColor $color
}

function New-MarkdownReport {
    [CmdletBinding()]
    param(
        [PSCustomObject]$Comparison,
        [string]$OutputPath
    )

    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine("# Code Quality Metrics Comparison")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Generated:** $($Comparison.timestamp)")
    $null = $sb.AppendLine("**Overall Status:** $($Comparison.overall.ToUpper())")
    $null = $sb.AppendLine("")

    # Git Info
    $null = $sb.AppendLine("## Git Info")
    $null = $sb.AppendLine("| Property | Baseline | Current |")
    $null = $sb.AppendLine("|----------|----------|---------|")
    $null = $sb.AppendLine("| Commit | ``$($Comparison.baseline.git.commit.Substring(0,8))`` | ``$($Comparison.current.git.commit.Substring(0,8))`` |")
    $null = $sb.AppendLine("| Branch | $($Comparison.baseline.git.branch) | $($Comparison.current.git.branch) |")
    $null = $sb.AppendLine("")

    # Metrics Table
    $null = $sb.AppendLine("## Metrics")
    $null = $sb.AppendLine("| Metric | Baseline | Current | Delta | Status |")
    $null = $sb.AppendLine("|--------|----------|---------|-------|--------|")

    foreach ($key in $Comparison.deltas.PSObject.Properties.Name) {
        $d = $Comparison.deltas.$key
        $statusEmoji = switch ($d.status) {
            'pass' { '✅' }
            'warn' { '⚠️' }
            'fail' { '❌' }
            default { '❓' }
        }
        $null = $sb.AppendLine("| $key | $($d.before) | $($d.after) | $($d.deltaFormatted) | $statusEmoji |")
    }

    $null = $sb.AppendLine("")

    # Recommendations
    if ($Comparison.recommendations.Count -gt 0) {
        $null = $sb.AppendLine("## Recommendations")
        foreach ($rec in $Comparison.recommendations) {
            $null = $sb.AppendLine("- $rec")
        }
        $null = $sb.AppendLine("")
    }

    $sb.ToString() | Set-Content -Path $OutputPath -Encoding UTF8
}

#endregion

#region Main Script

$scriptsDir = $PSScriptRoot
$baselinePath = Join-Path $scriptsDir $BaselineFile
$currentPath = Join-Path $scriptsDir $CurrentFile

# Verify baseline exists
if (-not (Test-Path $baselinePath)) {
    Write-Error "Baseline file not found: $baselinePath`nRun Measure-Baseline.ps1 first."
    exit 2
}

# Capture current metrics if needed
if (-not $SkipCurrentCapture) {
    Write-Host "📊 Capturing current metrics..." -ForegroundColor Cyan
    & "$scriptsDir\Measure-Baseline.ps1" -OutFile $CurrentFile -SkipCoverage:$false
}

# Verify current exists
if (-not (Test-Path $currentPath)) {
    Write-Error "Current metrics file not found: $currentPath"
    exit 2
}

# Load metrics
try {
    $baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
    $current = Get-Content $currentPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse metrics files: $_"
    exit 2
}

# Initialize comparison result
$comparison = [PSCustomObject]@{
    timestamp       = Get-Date -Format "o"
    baseline        = $baseline
    current         = $current
    thresholds      = [PSCustomObject]@{
        coverage    = $CoverageThreshold
        duplication = $DuplicationThreshold
        complexity  = $ComplexityThreshold
    }
    deltas          = [PSCustomObject]@{}
    overall         = 'pass'
    recommendations = [System.Collections.ArrayList]::new()
}

$hasFailure = $false
$hasWarning = $false

Write-Host ""
Write-Host "📈 Metrics Comparison" -ForegroundColor Cyan
Write-Host "   Baseline: $($baseline.timestamp)" -ForegroundColor Gray
Write-Host "   Current:  $($current.timestamp)" -ForegroundColor Gray
Write-Host ""

# Compare ESLint Errors
$eslintBefore = $baseline.metrics.eslint.errors
$eslintAfter = $current.metrics.eslint.errors
$eslintDelta = $eslintAfter - $eslintBefore
$eslintStatus = Get-MetricStatus -Before $eslintBefore -After $eslintAfter -Threshold $ComplexityThreshold -Direction 'LowerIsBetter'

$comparison.deltas | Add-Member -NotePropertyName 'eslint.errors' -NotePropertyValue ([PSCustomObject]@{
        before         = $eslintBefore
        after          = $eslintAfter
        delta          = $eslintDelta
        deltaFormatted = Format-Delta -Delta $eslintDelta
        status         = $eslintStatus
    })

Write-ColoredStatus -Label "ESLint Errors" -Before $eslintBefore -After $eslintAfter -Delta (Format-Delta $eslintDelta) -Status $eslintStatus

if ($eslintStatus -eq 'fail') { $hasFailure = $true; $null = $comparison.recommendations.Add("Reduce ESLint errors before proceeding") }
if ($eslintStatus -eq 'warn') { $hasWarning = $true }

# Compare ESLint Warnings
$warnBefore = $baseline.metrics.eslint.warnings
$warnAfter = $current.metrics.eslint.warnings
$warnDelta = $warnAfter - $warnBefore
$warnStatus = if ($warnDelta -gt 0) { 'warn' } else { 'pass' }

$comparison.deltas | Add-Member -NotePropertyName 'eslint.warnings' -NotePropertyValue ([PSCustomObject]@{
        before         = $warnBefore
        after          = $warnAfter
        delta          = $warnDelta
        deltaFormatted = Format-Delta -Delta $warnDelta
        status         = $warnStatus
    })

Write-ColoredStatus -Label "ESLint Warnings" -Before $warnBefore -After $warnAfter -Delta (Format-Delta $warnDelta) -Status $warnStatus

if ($Strict -and $warnStatus -eq 'warn') { $hasFailure = $true }

# Compare Duplication
$dupBefore = $baseline.metrics.duplication.percentage
$dupAfter = $current.metrics.duplication.percentage
$dupDelta = $dupAfter - $dupBefore
$dupStatus = Get-MetricStatus -Before $dupBefore -After $dupAfter -Threshold $DuplicationThreshold -Direction 'LowerIsBetter'

$comparison.deltas | Add-Member -NotePropertyName 'duplication' -NotePropertyValue ([PSCustomObject]@{
        before         = "$dupBefore%"
        after          = "$dupAfter%"
        delta          = $dupDelta
        deltaFormatted = Format-Delta -Delta $dupDelta -Unit '%'
        status         = $dupStatus
    })

Write-ColoredStatus -Label "Duplication" -Before "$dupBefore%" -After "$dupAfter%" -Delta (Format-Delta $dupDelta '%') -Status $dupStatus

if ($dupStatus -eq 'fail') { $hasFailure = $true; $null = $comparison.recommendations.Add("Reduce code duplication - consider extracting common patterns") }
if ($dupStatus -eq 'warn') { $hasWarning = $true }

# Compare Coverage (if available)
$baselineCovSkipped = $baseline.metrics.coverage.PSObject.Properties['skipped'] -and $baseline.metrics.coverage.skipped
$currentCovSkipped = $current.metrics.coverage.PSObject.Properties['skipped'] -and $current.metrics.coverage.skipped

if ($baseline.metrics.coverage -and $current.metrics.coverage -and
    -not $baselineCovSkipped -and -not $currentCovSkipped -and
    $baseline.metrics.coverage.lines -and $current.metrics.coverage.lines) {

    $covBefore = $baseline.metrics.coverage.lines
    $covAfter = $current.metrics.coverage.lines
    $covDelta = $covAfter - $covBefore
    $covStatus = Get-MetricStatus -Before $covBefore -After $covAfter -Threshold $CoverageThreshold -Direction 'HigherIsBetter'

    $comparison.deltas | Add-Member -NotePropertyName 'coverage' -NotePropertyValue ([PSCustomObject]@{
            before         = "$covBefore%"
            after          = "$covAfter%"
            delta          = $covDelta
            deltaFormatted = Format-Delta -Delta $covDelta -Unit '%'
            status         = $covStatus
        })

    Write-ColoredStatus -Label "Coverage" -Before "$covBefore%" -After "$covAfter%" -Delta (Format-Delta $covDelta '%') -Status $covStatus

    if ($covStatus -eq 'fail') { $hasFailure = $true; $null = $comparison.recommendations.Add("Add tests to improve coverage before proceeding") }
    if ($covStatus -eq 'warn') { $hasWarning = $true }
}

# Determine overall status
if ($hasFailure) {
    $comparison.overall = 'fail'
}
elseif ($hasWarning -and $Strict) {
    $comparison.overall = 'fail'
}
elseif ($hasWarning) {
    $comparison.overall = 'warn'
}

# Output final status
Write-Host ""
if ($comparison.overall -eq 'pass') {
    Write-Host "✅ ALL GATES PASSED" -ForegroundColor Green
}
elseif ($comparison.overall -eq 'warn') {
    Write-Host "⚠️  PASSED WITH WARNINGS" -ForegroundColor Yellow
}
else {
    Write-Host "❌ GATE FAILED - Refactor does not meet quality standards" -ForegroundColor Red

    if ($comparison.recommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "📋 Recommendations:" -ForegroundColor Cyan
        foreach ($rec in $comparison.recommendations) {
            Write-Host "   • $rec" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

# Generate markdown report if requested
if ($ReportFile) {
    $reportPath = Join-Path $scriptsDir $ReportFile
    New-MarkdownReport -Comparison $comparison -OutputPath $reportPath
    Write-Host "📄 Report saved to: $reportPath" -ForegroundColor Cyan
}

# Return object if requested
if ($PassThru) {
    return $comparison
}

# Exit with appropriate code
if ($comparison.overall -eq 'fail') {
    exit 1
}
exit 0

#endregion
