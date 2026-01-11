#Requires -Version 5.1
<#
.SYNOPSIS
    Unified code quality and safe-refactor tool for this repo.

.DESCRIPTION
    Consolidates three workflows into one script:

    - Measure: capture ESLint, duplication, and optional coverage metrics.
    - Compare: compare current metrics to baseline (optionally capturing current).
    - SafeRefactor: run a refactor command with rollback + validation + metrics gates.

    Notes:
    - PowerShell 5.1 compatible.
    - Console output uses ASCII-only status markers for broad codepage compatibility.

.PARAMETER Mode
    Operation mode: Measure, Compare, or SafeRefactor.

# Measure
.PARAMETER OutFile
    Output filename (relative to scripts/ folder). Default: metrics-baseline.json

.PARAMETER TargetPath
    Directories to analyze. Default: @('src')

.PARAMETER SkipCoverage
    Skip test coverage collection.

.PARAMETER SkipSecurity
    Skip security vulnerability audit (npm audit).

.PARAMETER SkipDependencies
    Skip dependency health check (npm outdated).

# Compare
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

# SafeRefactor
.PARAMETER Command
    Shell command to execute for the refactoring (e.g., "npm run lint -- --fix").

.PARAMETER ScriptBlock
    PowerShell script block to execute for the refactoring.

.PARAMETER Description
    Description of the refactoring operation for logging.

.PARAMETER SkipTests
    Skip test execution (use with caution).

.PARAMETER SkipMetrics
    Skip metrics comparison.

.PARAMETER KeepBackup
    Keep the backup branch even after successful completion.

.PARAMETER TimeoutMinutes
    Maximum time for the refactoring command. Default: 10 minutes.

.PARAMETER Force
    Skip confirmation prompt for destructive operations.

# Common
.PARAMETER PassThru
    Return the primary result object for the selected mode.

.EXAMPLE
    .\Quality-Gates.ps1 -Mode Measure

.EXAMPLE
    .\Quality-Gates.ps1 -Mode Compare -SkipCurrentCapture -PassThru

.EXAMPLE
    .\Quality-Gates.ps1 -Mode SafeRefactor -Command "npm run format" -WhatIf

.OUTPUTS
    PSCustomObject when -PassThru is specified.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Measure', 'Compare', 'SafeRefactor')]
    [string]$Mode,

    # Measure
    [Parameter()]
    [ValidatePattern('^[\w\-\.]+\.json$')]
    [string]$OutFile = 'metrics-baseline.json',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$TargetPath = @('src'),

    [Parameter()]
    [switch]$SkipCoverage,

    [Parameter()]
    [switch]$SkipSecurity,

    [Parameter()]
    [switch]$SkipDependencies,

    # Compare
    [Parameter()]
    [ValidatePattern('^[\w\-\.]+\.json$')]
    [string]$BaselineFile = 'metrics-baseline.json',

    [Parameter()]
    [ValidatePattern('^[\w\-\.]+\.json$')]
    [string]$CurrentFile = 'metrics-current.json',

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

    # SafeRefactor
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Command,

    [Parameter()]
    [ValidateNotNull()]
    [scriptblock]$ScriptBlock,

    [Parameter()]
    [string]$Description = 'Automated refactor',

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
    [switch]$Force,

    # Common
    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Force) {
    $ConfirmPreference = 'None'
}

# Script-level constants
$script:scriptsDir = $PSScriptRoot
$script:projectRoot = Split-Path -Parent $PSScriptRoot
$script:gitCommand = $null  # Cached git availability

$script:ExitCodes = @{
    Success           = 0
    PreFlightFailed   = 1
    IOParseError      = 2
    ValidationFailed  = 3
    MetricsFailed     = 4
    RollbackCompleted = 5
    Fatal             = 6
}

function Assert-ModeParameters {
    [CmdletBinding()]
    param([string]$SelectedMode)

    switch ($SelectedMode) {
        'Measure' { return }
        'Compare' { return }
        'SafeRefactor' {
            $hasCommand = -not [string]::IsNullOrWhiteSpace($Command)
            $hasScriptBlock = ($null -ne $ScriptBlock)

            if ($hasCommand -and $hasScriptBlock) {
                throw "Specify only one of -Command or -ScriptBlock"
            }
            if (-not $hasCommand -and -not $hasScriptBlock) {
                throw "Specify either -Command or -ScriptBlock"
            }
            return
        }
        default {
            throw "Unknown Mode: $SelectedMode"
        }
    }
}

function Test-CommandAvailable {
    [CmdletBinding()]
    param([string]$CommandName)

    $null = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $?
}

function Get-GitCommand {
    <#
    .SYNOPSIS
        Returns cached git command availability.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandInfo])]
    param()

    if ($null -eq $script:gitCommand) {
        $script:gitCommand = Get-Command git -ErrorAction SilentlyContinue
    }
    return $script:gitCommand
}

function Compare-SingleMetric {
    <#
    .SYNOPSIS
        Compare a single metric between baseline and current values.
    .DESCRIPTION
        Eliminates repeated comparison logic for eslint/duplication/coverage metrics.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowNull()]$Before,
        [Parameter(Mandatory)][AllowNull()]$After,
        [double]$Threshold = 0,
        [Parameter(Mandatory)][ValidateSet('LowerIsBetter', 'HigherIsBetter')][string]$Direction,
        [string]$Unit = ''
    )

    $beforeValue = if ($null -ne $Before) { [double]$Before } else { 0 }
    $afterValue = if ($null -ne $After) { [double]$After } else { 0 }
    $delta = $afterValue - $beforeValue

    $status = Get-MetricStatus -Before $beforeValue -After $afterValue -Threshold $Threshold -Direction $Direction
    $deltaFormatted = Format-Delta -Delta $delta -Unit $Unit

    $beforeDisplay = if ($Unit) { "$beforeValue$Unit" } else { $beforeValue }
    $afterDisplay = if ($Unit) { "$afterValue$Unit" } else { $afterValue }

    return [PSCustomObject]@{
        Name           = $Name
        Before         = $beforeDisplay
        After          = $afterDisplay
        Delta          = $delta
        DeltaFormatted = $deltaFormatted
        Status         = $status
    }
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

function Read-JsonFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $content = Get-Content -Path $Path -Raw -ErrorAction Stop
    return $content | ConvertFrom-Json -ErrorAction Stop
}

function Write-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Object
    )

    $json = $Object | ConvertTo-Json -Depth 10
    $json | Set-Content -Path $Path -Encoding UTF8
}

function Get-GitInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $info = @{
        commit = $null
        branch = $null
        dirty  = $false
    }

    $gitCmd = Get-GitCommand
    if ($null -eq $gitCmd) {
        Write-Verbose 'Git command not found'
        return $info
    }

    try {
        $commitResult = git rev-parse HEAD 2>&1
        if ($LASTEXITCODE -eq 0) { $info.commit = $commitResult.Trim() }

        $branchResult = git rev-parse --abbrev-ref HEAD 2>&1
        if ($LASTEXITCODE -eq 0) { $info.branch = $branchResult.Trim() }

        $statusResult = git status --porcelain 2>&1
        if ($LASTEXITCODE -eq 0) {
            $info.dirty = [bool]($statusResult | Where-Object { $_ })
        }
    }
    catch {
        $errorRecord = $_
        Write-Verbose "Git info unavailable: $($errorRecord.Exception.Message)"
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
        $null = Get-Command npx -ErrorAction Stop

        $eslintArgs = @($Paths) + @('--format', 'json')
        $output = & npx eslint @eslintArgs 2>&1

        $jsonOutput = $output | Where-Object { $_ -notmatch '^npm|^npx' } | Out-String
        $jsonText = if ($jsonOutput) { $jsonOutput.Trim() } else { '' }

        if ($jsonText) {
            if (-not $jsonText.StartsWith('[')) {
                $start = $jsonText.IndexOf('[')
                $end = $jsonText.LastIndexOf(']')
                if ($start -ge 0 -and $end -gt $start) {
                    $jsonText = $jsonText.Substring($start, ($end - $start + 1))
                }
            }

            if ($jsonText.StartsWith('[')) {
                $eslintData = $jsonText | ConvertFrom-Json -ErrorAction Stop

                foreach ($file in $eslintData) {
                    $result.errors += [int]$file.errorCount
                    $result.warnings += [int]$file.warningCount
                    $result.fixable += [int]$file.fixableErrorCount + [int]$file.fixableWarningCount
                    if ($file.errorCount -gt 0 -or $file.warningCount -gt 0) { $result.files++ }
                }
            }
        }
    }
    catch {
        $errorRecord = $_
        Write-Warning "ESLint analysis failed: $($errorRecord.Exception.Message)"
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
        $null = Get-Command npx -ErrorAction Stop

        if (-not (Test-Path $OutputDir)) {
            $null = New-Item -Path $OutputDir -ItemType Directory -Force -ErrorAction Stop
        }

        $jscpdArgs = @(
            '--min-tokens', '50',
            '--reporters', 'json',
            '--output', $OutputDir,
            '--gitignore'
        ) + $Paths

        $null = & npx jscpd @jscpdArgs 2>&1

        $reportPath = Join-Path $OutputDir 'jscpd-report.json'
        if (Test-Path $reportPath -ErrorAction SilentlyContinue) {
            $dupData = Get-Content $reportPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

            if ($null -ne $dupData.statistics -and $null -ne $dupData.statistics.total) {
                $total = $dupData.statistics.total
                $result.percentage = [math]::Round([double]$total.percentage, 2)
                $result.clones = [int]$total.clones
                $result.sources = [int]$total.sources
                $result.lines = [int]$total.duplicatedLines
            }
        }
    }
    catch {
        $errorRecord = $_
        Write-Warning "Duplication analysis failed: $($errorRecord.Exception.Message)"
    }

    return $result
}

function Get-CoverageMetrics {
    [CmdletBinding()]
    param([int]$TimeoutSeconds = 300)

    $result = @{
        lines     = 0.0
        branches  = 0.0
        functions = 0.0
    }

    try {
        $job = Start-Job -ScriptBlock {
            Set-Location $using:projectRoot
            npm run test:coverage 2>&1
        }

        $completed = $job | Wait-Job -Timeout $TimeoutSeconds
        if ($null -eq $completed) {
            $job | Stop-Job
            $job | Remove-Job -Force
            Write-Warning "Coverage collection timed out after $TimeoutSeconds seconds"
            return $result
        }

        $coverageOutput = $job | Receive-Job | Out-String
        $job | Remove-Job -Force

        $patterns = @(
            @{ Pattern = 'all files\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)'; Groups = @{ lines = 1; branches = 2; functions = 3 } },
            @{ Pattern = 'Lines\s*:\s*([0-9.]+)%.*?Branches\s*:\s*([0-9.]+)%.*?Functions\s*:\s*([0-9.]+)%'; Groups = @{ lines = 1; branches = 2; functions = 3 } },
            @{ Pattern = 'coverage[:\s]+([0-9.]+)\s*%'; Groups = @{ lines = 1 } }
        )

        foreach ($patternDef in $patterns) {
            $match = [regex]::Match($coverageOutput, $patternDef.Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($match.Success) {
                foreach ($key in $patternDef.Groups.Keys) {
                    $groupIndex = $patternDef.Groups[$key]
                    if ($match.Groups[$groupIndex].Success) {
                        $result[$key] = [math]::Round([double]$match.Groups[$groupIndex].Value, 2)
                    }
                }
                break
            }
        }
    }
    catch {
        $errorRecord = $_
        Write-Warning "Coverage collection failed: $($errorRecord.Exception.Message)"
    }

    return $result
}

function Get-SecurityMetrics {
    <#
    .SYNOPSIS
        Collects npm audit security vulnerability metrics.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $result = @{
        high     = 0
        moderate = 0
        low      = 0
        info     = 0
        total    = 0
    }

    try {
        $null = Get-Command npm -ErrorAction Stop

        # npm audit exits non-zero when vulnerabilities exist - ignore exit code
        $auditOutput = npm audit --json 2>&1 | Out-String

        if ($auditOutput) {
            $jsonText = $auditOutput.Trim()
            if ($jsonText.StartsWith('{')) {
                $auditData = $jsonText | ConvertFrom-Json -ErrorAction Stop

                if ($null -ne $auditData.metadata -and $null -ne $auditData.metadata.vulnerabilities) {
                    $vulns = $auditData.metadata.vulnerabilities
                    $result.high = [int]($vulns.high)
                    $result.moderate = [int]($vulns.moderate)
                    $result.low = [int]($vulns.low)
                    $result.info = [int]($vulns.info)
                    $result.total = [int]($vulns.total)
                }
            }
        }
    }
    catch {
        $errorRecord = $_
        Write-Warning "Security audit failed: $($errorRecord.Exception.Message)"
    }

    return $result
}

function Get-TechDebtMetrics {
    <#
    .SYNOPSIS
        Counts TODO, FIXME, HACK, and XXX comments in source files.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string[]]$Paths)

    $result = @{
        todoCount  = 0
        fixmeCount = 0
        hackCount  = 0
        totalDebt  = 0
    }

    try {
        $extensions = @('*.ts', '*.tsx', '*.js', '*.jsx')
        $excludeDirs = @('node_modules', 'dist', '.git', 'coverage')

        foreach ($targetPath in $Paths) {
            $fullPath = Join-Path $script:projectRoot $targetPath
            if (-not (Test-Path $fullPath)) { continue }

            foreach ($ext in $extensions) {
                $files = Get-ChildItem -Path $fullPath -Filter $ext -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object {
                        $filePath = $_.FullName
                        $excluded = $false
                        foreach ($dir in $excludeDirs) {
                            if ($filePath -match [regex]::Escape($dir)) { $excluded = $true; break }
                        }
                        -not $excluded
                    }

                foreach ($file in $files) {
                    $searchResults = Select-String -Path $file.FullName -Pattern '\bTODO\b|\bFIXME\b|\bHACK\b|\bXXX\b' -AllMatches -ErrorAction SilentlyContinue

                    foreach ($searchMatch in $searchResults) {
                        if ($searchMatch.Line -match '\bTODO\b') { $result.todoCount++ }
                        if ($searchMatch.Line -match '\bFIXME\b') { $result.fixmeCount++ }
                        if ($searchMatch.Line -match '\bHACK\b') { $result.hackCount++ }
                    }
                }
            }
        }

        $result.totalDebt = $result.todoCount + $result.fixmeCount + $result.hackCount
    }
    catch {
        $errorRecord = $_
        Write-Warning "Tech debt analysis failed: $($errorRecord.Exception.Message)"
    }

    return $result
}

function Get-DependencyHealthMetrics {
    <#
    .SYNOPSIS
        Checks for outdated npm dependencies.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $result = @{
        outdatedCount = 0
        majorUpdates  = 0
        minorUpdates  = 0
        patchUpdates  = 0
    }

    try {
        $null = Get-Command npm -ErrorAction Stop

        # npm outdated exits non-zero when outdated packages exist - ignore exit code
        $outdatedOutput = npm outdated --json 2>&1 | Out-String

        if ($outdatedOutput) {
            $jsonText = $outdatedOutput.Trim()
            if ($jsonText.StartsWith('{') -and $jsonText.Length -gt 2) {
                $outdatedData = $jsonText | ConvertFrom-Json -ErrorAction Stop

                foreach ($prop in $outdatedData.PSObject.Properties) {
                    $pkg = $prop.Value
                    $result.outdatedCount++

                    # Parse semver to categorize update type
                    if ($null -ne $pkg.current -and $null -ne $pkg.latest) {
                        $currentParts = ([string]$pkg.current) -split '\.'
                        $latestParts = ([string]$pkg.latest) -split '\.'

                        if ($currentParts.Count -ge 1 -and $latestParts.Count -ge 1) {
                            if ($currentParts[0] -ne $latestParts[0]) {
                                $result.majorUpdates++
                            }
                            elseif ($currentParts.Count -ge 2 -and $latestParts.Count -ge 2 -and $currentParts[1] -ne $latestParts[1]) {
                                $result.minorUpdates++
                            }
                            else {
                                $result.patchUpdates++
                            }
                        }
                    }
                }
            }
        }
    }
    catch {
        $errorRecord = $_
        Write-Warning "Dependency health check failed: $($errorRecord.Exception.Message)"
    }

    return $result
}

function Invoke-Measure {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$OutFileName,
        [Parameter(Mandatory)][string[]]$Targets,
        [Parameter(Mandatory)][bool]$SkipCoverageCollection,
        [bool]$SkipSecurityCollection = $false,
        [bool]$SkipDependenciesCollection = $false
    )

    $outputPath = Join-Path $script:scriptsDir $OutFileName
    $jscpdDir = Join-Path $script:scriptsDir '.jscpd'

    if (-not (Test-Path (Join-Path $script:projectRoot 'package.json'))) {
        throw "Cannot find package.json in project root: $script:projectRoot"
    }

    foreach ($tool in @('node', 'npm')) {
        if (-not (Test-CommandAvailable $tool)) {
            throw "Required tool not found: $tool"
        }
    }

    $gitInfo = Get-GitInfo

    $metrics = [ordered]@{
        version      = '2.1'
        timestamp    = Get-Date -Format 'o'
        git          = [ordered]@{
            commit = $gitInfo.commit
            branch = $gitInfo.branch
            dirty  = $gitInfo.dirty
        }
        targets      = $Targets
        metrics      = [ordered]@{
            eslint       = $null
            duplication  = $null
            coverage     = $null
            security     = $null
            techDebt     = $null
            dependencies = $null
        }
        toolVersions = [ordered]@{
            node   = Get-ToolVersion 'node'
            npm    = Get-ToolVersion 'npm'
            eslint = Get-ToolVersion 'eslint'
            jscpd  = Get-ToolVersion 'jscpd'
        }
    }

    $resolvedTargets = $Targets | ForEach-Object {
        $fullPath = Join-Path $script:projectRoot $_
        if (Test-Path $fullPath) { $_ } else { Write-Warning "Target path not found: $_"; $null }
    } | Where-Object { $_ }

    if (-not $resolvedTargets) {
        throw 'No valid target paths found'
    }

    Push-Location $script:projectRoot
    try {
        Write-Host 'Collecting ESLint metrics...' -ForegroundColor Cyan
        $metrics.metrics.eslint = Get-EslintMetrics -Paths $resolvedTargets

        Write-Host 'Collecting duplication metrics...' -ForegroundColor Cyan
        $metrics.metrics.duplication = Get-DuplicationMetrics -Paths $resolvedTargets -OutputDir $jscpdDir

        if (-not $SkipCoverageCollection) {
            Write-Host 'Collecting coverage metrics...' -ForegroundColor Cyan
            $metrics.metrics.coverage = Get-CoverageMetrics
        }
        else {
            Write-Verbose 'Skipping coverage collection'
            $metrics.metrics.coverage = @{
                lines      = $null
                branches   = $null
                functions  = $null
                statements = $null
                skipped    = $true
            }
        }

        # Security metrics
        if (-not $SkipSecurityCollection) {
            Write-Host 'Collecting security metrics...' -ForegroundColor Cyan
            $metrics.metrics.security = Get-SecurityMetrics
        }
        else {
            Write-Verbose 'Skipping security collection'
            $metrics.metrics.security = @{ high = $null; moderate = $null; low = $null; info = $null; total = $null; skipped = $true }
        }

        # Tech debt metrics
        Write-Host 'Collecting tech debt metrics...' -ForegroundColor Cyan
        $metrics.metrics.techDebt = Get-TechDebtMetrics -Paths $resolvedTargets

        # Dependency health metrics
        if (-not $SkipDependenciesCollection) {
            Write-Host 'Collecting dependency health metrics...' -ForegroundColor Cyan
            $metrics.metrics.dependencies = Get-DependencyHealthMetrics
        }
        else {
            Write-Verbose 'Skipping dependencies collection'
            $metrics.metrics.dependencies = @{ outdatedCount = $null; majorUpdates = $null; minorUpdates = $null; patchUpdates = $null; skipped = $true }
        }
    }
    finally {
        Pop-Location
    }

    if ($PSCmdlet.ShouldProcess($outputPath, 'Save metrics')) {
        Write-JsonFile -Path $outputPath -Object $metrics

        Write-Host ''
        Write-Host 'Metrics saved to: ' -ForegroundColor Green -NoNewline
        Write-Host $outputPath -ForegroundColor White
        Write-Host ''

        Write-Host 'Summary:' -ForegroundColor Cyan
        Write-Host "   ESLint Errors:   $($metrics.metrics.eslint.errors)" -ForegroundColor $(if ($metrics.metrics.eslint.errors -eq 0) { 'Green' } else { 'Yellow' })
        Write-Host "   ESLint Warnings: $($metrics.metrics.eslint.warnings)" -ForegroundColor $(if ($metrics.metrics.eslint.warnings -eq 0) { 'Green' } else { 'Yellow' })
        Write-Host "   Duplication:     $($metrics.metrics.duplication.percentage)%" -ForegroundColor $(if ($metrics.metrics.duplication.percentage -lt 5) { 'Green' } else { 'Yellow' })
        if (-not $SkipCoverageCollection -and $metrics.metrics.coverage.lines) {
            Write-Host "   Coverage:        $($metrics.metrics.coverage.lines)%" -ForegroundColor $(if ($metrics.metrics.coverage.lines -ge 80) { 'Green' } elseif ($metrics.metrics.coverage.lines -ge 60) { 'Yellow' } else { 'Red' })
        }
        if (-not $SkipSecurityCollection) {
            Write-Host "   Security Vulns:  $($metrics.metrics.security.high) high, $($metrics.metrics.security.moderate) moderate" -ForegroundColor $(if ($metrics.metrics.security.high -eq 0) { 'Green' } else { 'Red' })
        }
        Write-Host "   Tech Debt:       $($metrics.metrics.techDebt.totalDebt) items" -ForegroundColor $(if ($metrics.metrics.techDebt.totalDebt -lt 20) { 'Green' } else { 'Yellow' })
        if (-not $SkipDependenciesCollection) {
            Write-Host "   Outdated Deps:   $($metrics.metrics.dependencies.outdatedCount)" -ForegroundColor $(if ($metrics.metrics.dependencies.outdatedCount -eq 0) { 'Green' } else { 'Yellow' })
        }
    }

    return [PSCustomObject]$metrics
}

function Get-MetricStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()]$Before,
        [Parameter(Mandatory)][AllowNull()]$After,
        [double]$Threshold = 0,
        [Parameter(Mandatory)][ValidateSet('LowerIsBetter', 'HigherIsBetter')][string]$Direction
    )

    $beforeValue = if ($null -ne $Before) { [double]$Before } else { 0 }
    $afterValue = if ($null -ne $After) { [double]$After } else { 0 }
    $delta = $afterValue - $beforeValue

    if ($Direction -eq 'HigherIsBetter') {
        if ($delta -lt - $Threshold) { return 'fail' }
        if ($delta -lt 0) { return 'warn' }
        return 'pass'
    }

    if ($delta -gt $Threshold) { return 'fail' }
    if ($delta -gt 0) { return 'warn' }
    return 'pass'
}

function Format-Delta {
    [CmdletBinding()]
    param([AllowNull()]$Delta, [string]$Unit = '')

    if ($null -eq $Delta) {
        return '+/-0{0}' -f $Unit
    }

    [double]$deltaValue = $Delta
    $sign = if ($deltaValue -gt 0) { '+' } elseif ($deltaValue -lt 0) { '' } else { '+/-' }
    return '{0}{1:N2}{2}' -f $sign, $deltaValue, $Unit
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
        'pass' { '[OK]  ' }
        'warn' { '[WARN]' }
        'fail' { '[FAIL]' }
        default { '[?]   ' }
    }

    Write-Host "  $icon " -NoNewline
    Write-Host "$Label`t" -NoNewline -ForegroundColor White
    Write-Host "$Before -> $After " -NoNewline -ForegroundColor Gray
    Write-Host "($Delta)" -ForegroundColor $color
}

function New-MarkdownReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Comparison,
        [Parameter(Mandatory)][string]$OutputPath
    )

    function Get-ShortCommit {
        [CmdletBinding()]
        param([AllowNull()][string]$Commit, [int]$Length = 8)

        if ([string]::IsNullOrWhiteSpace($Commit)) { return 'unknown' }
        $safeLength = [Math]::Min($Length, $Commit.Length)
        return $Commit.Substring(0, $safeLength)
    }

    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine('# Code Quality Metrics Comparison')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine("**Generated:** $($Comparison.timestamp)")
    $null = $sb.AppendLine("**Overall Status:** $($Comparison.overall.ToUpper())")
    $null = $sb.AppendLine('')

    $null = $sb.AppendLine('## Git Info')
    $null = $sb.AppendLine('| Property | Baseline | Current |')
    $null = $sb.AppendLine('|----------|----------|---------|')

    $baselineCommit = Get-ShortCommit -Commit $Comparison.baseline.git.commit
    $currentCommit = Get-ShortCommit -Commit $Comparison.current.git.commit
    $baselineBranch = if ([string]::IsNullOrWhiteSpace([string]$Comparison.baseline.git.branch)) { 'unknown' } else { [string]$Comparison.baseline.git.branch }
    $currentBranch = if ([string]::IsNullOrWhiteSpace([string]$Comparison.current.git.branch)) { 'unknown' } else { [string]$Comparison.current.git.branch }

    $null = $sb.AppendLine(( '| Commit | `{0}` | `{1}` |' -f $baselineCommit, $currentCommit ))
    $null = $sb.AppendLine(( '| Branch | {0} | {1} |' -f $baselineBranch, $currentBranch ))
    $null = $sb.AppendLine('')

    $null = $sb.AppendLine('## Metrics')
    $null = $sb.AppendLine('| Metric | Baseline | Current | Delta | Status |')
    $null = $sb.AppendLine('|--------|----------|---------|-------|--------|')

    foreach ($key in $Comparison.deltas.PSObject.Properties.Name) {
        $d = $Comparison.deltas.$key
        $statusText = switch ($d.status) {
            'pass' { 'PASS' }
            'warn' { 'WARN' }
            'fail' { 'FAIL' }
            default { '?' }
        }
        $null = $sb.AppendLine("| $key | $($d.before) | $($d.after) | $($d.deltaFormatted) | $statusText |")
    }

    $null = $sb.AppendLine('')

    if ($Comparison.recommendations.Count -gt 0) {
        $null = $sb.AppendLine('## Recommendations')
        foreach ($rec in $Comparison.recommendations) {
            $null = $sb.AppendLine("- $rec")
        }
        $null = $sb.AppendLine('')
    }

    $sb.ToString() | Set-Content -Path $OutputPath -Encoding UTF8
}

function Invoke-Compare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BaselineFileName,
        [Parameter(Mandatory)][string]$CurrentFileName,
        [string]$ReportFileName,
        [double]$CoverageGate,
        [double]$DuplicationGate,
        [int]$ComplexityGate,
        [bool]$StrictMode,
        [bool]$SkipCapture
    )

    $baselinePath = Join-Path $script:scriptsDir $BaselineFileName
    $currentPath = Join-Path $script:scriptsDir $CurrentFileName

    if (-not (Test-Path $baselinePath -ErrorAction SilentlyContinue)) {
        Write-Error "Baseline file not found: $baselinePath`nRun .\Quality-Gates.ps1 -Mode Measure to create a baseline first."
        return @{ ExitCode = $script:ExitCodes.IOParseError; Comparison = $null }
    }

    $current = $null
    if (-not $SkipCapture) {
        Write-Host 'Capturing current metrics...' -ForegroundColor Cyan
        try {
            $current = Invoke-Measure -OutFileName $CurrentFileName -Targets $TargetPath -SkipCoverageCollection:$false
        }
        catch {
            $errorRecord = $_
            Write-Error "Failed to capture current metrics: $($errorRecord.Exception.Message)"
            return @{ ExitCode = $script:ExitCodes.IOParseError; Comparison = $null }
        }
    }

    if (-not (Test-Path $currentPath -ErrorAction SilentlyContinue)) {
        Write-Error "Current metrics file not found: $currentPath"
        return @{ ExitCode = $script:ExitCodes.IOParseError; Comparison = $null }
    }

    try {
        $baseline = Read-JsonFile -Path $baselinePath
        if ($null -eq $current) {
            $current = Read-JsonFile -Path $currentPath
        }
    }
    catch {
        $errorRecord = $_
        Write-Error "Failed to parse metrics files: $($errorRecord.Exception.Message)"
        return @{ ExitCode = $script:ExitCodes.IOParseError; Comparison = $null }
    }

    $comparison = [PSCustomObject]@{
        timestamp       = Get-Date -Format 'o'
        baseline        = $baseline
        current         = $current
        thresholds      = [PSCustomObject]@{
            coverage    = $CoverageGate
            duplication = $DuplicationGate
            complexity  = $ComplexityGate
        }
        deltas          = [PSCustomObject]@{}
        overall         = 'pass'
        recommendations = [System.Collections.ArrayList]::new()
    }

    $hasFailure = $false
    $hasWarning = $false

    Write-Host ''
    Write-Host 'Metrics Comparison' -ForegroundColor Cyan
    Write-Host "   Baseline: $($baseline.timestamp)" -ForegroundColor Gray
    Write-Host "   Current:  $($current.timestamp)" -ForegroundColor Gray
    Write-Host ''

    # Define metrics to compare with their extraction logic and recommendations
    $metricDefinitions = @(
        @{
            Key            = 'eslint.errors'
            Label          = 'ESLint Errors'
            BeforeValue    = if ($null -ne $baseline.metrics.eslint -and $null -ne $baseline.metrics.eslint.errors) { [int]$baseline.metrics.eslint.errors } else { 0 }
            AfterValue     = if ($null -ne $current.metrics.eslint -and $null -ne $current.metrics.eslint.errors) { [int]$current.metrics.eslint.errors } else { 0 }
            Threshold      = $ComplexityGate
            Direction      = 'LowerIsBetter'
            Unit           = ''
            Recommendation = 'Reduce ESLint errors before proceeding'
            FailOnWarn     = $false
        },
        @{
            Key            = 'eslint.warnings'
            Label          = 'ESLint Warnings'
            BeforeValue    = if ($null -ne $baseline.metrics.eslint -and $null -ne $baseline.metrics.eslint.warnings) { [int]$baseline.metrics.eslint.warnings } else { 0 }
            AfterValue     = if ($null -ne $current.metrics.eslint -and $null -ne $current.metrics.eslint.warnings) { [int]$current.metrics.eslint.warnings } else { 0 }
            Threshold      = 0
            Direction      = 'LowerIsBetter'
            Unit           = ''
            Recommendation = $null  # Warnings don't have a recommendation
            FailOnWarn     = $StrictMode
        },
        @{
            Key            = 'duplication'
            Label          = 'Duplication'
            BeforeValue    = if ($null -ne $baseline.metrics.duplication -and $null -ne $baseline.metrics.duplication.percentage) { [double]$baseline.metrics.duplication.percentage } else { 0.0 }
            AfterValue     = if ($null -ne $current.metrics.duplication -and $null -ne $current.metrics.duplication.percentage) { [double]$current.metrics.duplication.percentage } else { 0.0 }
            Threshold      = $DuplicationGate
            Direction      = 'LowerIsBetter'
            Unit           = '%'
            Recommendation = 'Reduce code duplication - consider extracting common patterns'
            FailOnWarn     = $false
        },
        @{
            Key            = 'security.high'
            Label          = 'High Vulnerabilities'
            BeforeValue    = if ($null -ne $baseline.metrics.security -and $null -ne $baseline.metrics.security.high) { [int]$baseline.metrics.security.high } else { 0 }
            AfterValue     = if ($null -ne $current.metrics.security -and $null -ne $current.metrics.security.high) { [int]$current.metrics.security.high } else { 0 }
            Threshold      = 0
            Direction      = 'LowerIsBetter'
            Unit           = ''
            Recommendation = 'Fix high-severity vulnerabilities immediately'
            FailOnWarn     = $true
        },
        @{
            Key            = 'techDebt.totalDebt'
            Label          = 'Tech Debt Items'
            BeforeValue    = if ($null -ne $baseline.metrics.techDebt -and $null -ne $baseline.metrics.techDebt.totalDebt) { [int]$baseline.metrics.techDebt.totalDebt } else { 0 }
            AfterValue     = if ($null -ne $current.metrics.techDebt -and $null -ne $current.metrics.techDebt.totalDebt) { [int]$current.metrics.techDebt.totalDebt } else { 0 }
            Threshold      = 5
            Direction      = 'LowerIsBetter'
            Unit           = ''
            Recommendation = $null
            FailOnWarn     = $false
        },
        @{
            Key            = 'dependencies.outdatedCount'
            Label          = 'Outdated Packages'
            BeforeValue    = if ($null -ne $baseline.metrics.dependencies -and $null -ne $baseline.metrics.dependencies.outdatedCount) { [int]$baseline.metrics.dependencies.outdatedCount } else { 0 }
            AfterValue     = if ($null -ne $current.metrics.dependencies -and $null -ne $current.metrics.dependencies.outdatedCount) { [int]$current.metrics.dependencies.outdatedCount } else { 0 }
            Threshold      = 0
            Direction      = 'LowerIsBetter'
            Unit           = ''
            Recommendation = 'Run npm update to refresh dependencies'
            FailOnWarn     = $false
        }
    )

    # Process each metric using the helper
    foreach ($def in $metricDefinitions) {
        $metric = Compare-SingleMetric -Name $def.Key -Before $def.BeforeValue -After $def.AfterValue -Threshold $def.Threshold -Direction $def.Direction -Unit $def.Unit

        $comparison.deltas | Add-Member -NotePropertyName $def.Key -NotePropertyValue ([PSCustomObject]@{
                before         = $metric.Before
                after          = $metric.After
                delta          = $metric.Delta
                deltaFormatted = $metric.DeltaFormatted
                status         = $metric.Status
            })

        Write-ColoredStatus -Label $def.Label -Before $metric.Before -After $metric.After -Delta $metric.DeltaFormatted -Status $metric.Status

        if ($metric.Status -eq 'fail') {
            $hasFailure = $true
            if ($def.Recommendation) { $null = $comparison.recommendations.Add($def.Recommendation) }
        }
        if ($metric.Status -eq 'warn') {
            $hasWarning = $true
            if ($def.FailOnWarn) { $hasFailure = $true }
        }
    }

    # Coverage requires special handling (skip check)
    $baselineCovSkipped = ($null -ne $baseline.metrics.coverage) -and ($baseline.metrics.coverage.PSObject.Properties['skipped']) -and ($baseline.metrics.coverage.skipped -eq $true)
    $currentCovSkipped = ($null -ne $current.metrics.coverage) -and ($current.metrics.coverage.PSObject.Properties['skipped']) -and ($current.metrics.coverage.skipped -eq $true)

    $canCompareCoverage = $null -ne $baseline.metrics.coverage -and $null -ne $current.metrics.coverage -and -not $baselineCovSkipped -and -not $currentCovSkipped -and $null -ne $baseline.metrics.coverage.lines -and $null -ne $current.metrics.coverage.lines

    if ($canCompareCoverage) {
        $covMetric = Compare-SingleMetric -Name 'coverage' -Before ([double]$baseline.metrics.coverage.lines) -After ([double]$current.metrics.coverage.lines) -Threshold $CoverageGate -Direction 'HigherIsBetter' -Unit '%'

        $comparison.deltas | Add-Member -NotePropertyName 'coverage' -NotePropertyValue ([PSCustomObject]@{
                before         = $covMetric.Before
                after          = $covMetric.After
                delta          = $covMetric.Delta
                deltaFormatted = $covMetric.DeltaFormatted
                status         = $covMetric.Status
            })

        Write-ColoredStatus -Label 'Coverage' -Before $covMetric.Before -After $covMetric.After -Delta $covMetric.DeltaFormatted -Status $covMetric.Status

        if ($covMetric.Status -eq 'fail') { $hasFailure = $true; $null = $comparison.recommendations.Add('Add tests to improve coverage before proceeding') }
        if ($covMetric.Status -eq 'warn') { $hasWarning = $true }
    }

    if ($hasFailure) {
        $comparison.overall = 'fail'
    }
    elseif ($hasWarning -and $StrictMode) {
        $comparison.overall = 'fail'
    }
    elseif ($hasWarning) {
        $comparison.overall = 'warn'
    }

    Write-Host ''
    if ($comparison.overall -eq 'pass') {
        Write-Host 'ALL GATES PASSED' -ForegroundColor Green
    }
    elseif ($comparison.overall -eq 'warn') {
        Write-Host 'PASSED WITH WARNINGS' -ForegroundColor Yellow
    }
    else {
        Write-Host 'GATE FAILED - Refactor does not meet quality standards' -ForegroundColor Red
        if ($comparison.recommendations.Count -gt 0) {
            Write-Host ''
            Write-Host 'Recommendations:' -ForegroundColor Cyan
            foreach ($rec in $comparison.recommendations) {
                Write-Host "   - $rec" -ForegroundColor Yellow
            }
        }
    }
    Write-Host ''

    if ($ReportFileName) {
        $reportPath = Join-Path $script:scriptsDir $ReportFileName
        New-MarkdownReport -Comparison $comparison -OutputPath $reportPath
        Write-Host "Report saved to: $reportPath" -ForegroundColor Cyan
    }

    $exitCode = 0
    if ($comparison.overall -eq 'fail') { $exitCode = 1 }

    return @{ ExitCode = $exitCode; Comparison = $comparison }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')][string]$Level = 'Info',
        [Parameter(Mandatory)][string]$LogFile
    )

    $ts = Get-Date -Format 'HH:mm:ss'
    $prefix = switch ($Level) {
        'Info' { "[$ts] INFO   " }
        'Success' { "[$ts] OK     " }
        'Warning' { "[$ts] WARN   " }
        'Error' { "[$ts] ERROR  " }
        'Debug' { "[$ts] DEBUG  " }
    }

    $logMessage = if ($Message) { "$prefix$Message" } else { '' }
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue

    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Debug' { 'Gray' }
    }

    if ($Message -and ($Level -ne 'Debug' -or $VerbosePreference -eq 'Continue')) {
        Write-Host $logMessage -ForegroundColor $color
    }
    elseif (-not $Message) {
        Write-Host ''
    }
}

function Test-CleanWorkingTree {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$LogFile)

    $gitCmd = Get-GitCommand
    if ($null -eq $gitCmd) {
        Write-Log -Message 'Git not available - assuming clean working tree' -Level Warning -LogFile $LogFile
        return $true
    }

    $statusOutput = git status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message 'Failed to check git status' -Level Warning -LogFile $LogFile
        return $true
    }

    return -not [bool]($statusOutput | Where-Object { $_ })
}

function Test-CommandSuccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$CommandToRun,
        [Parameter(Mandatory)][string]$LogFile,
        [switch]$CaptureOutput
    )

    Write-Log -Message "Running: $Name" -Level Debug -LogFile $LogFile

    try {
        if ($CaptureOutput) {
            $output = & $CommandToRun 2>&1
            $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            return @{ Success = ($exitCode -eq 0); Output = $output; ExitCode = $exitCode }
        }

        $null = & $CommandToRun 2>&1
        $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
        return @{ Success = ($exitCode -eq 0); Output = $null; ExitCode = $exitCode }
    }
    catch {
        $errorRecord = $_
        return @{ Success = $false; Output = $errorRecord.Exception.Message; ExitCode = -1 }
    }
}

function Invoke-Rollback {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$BackupBranch,
        [Parameter(Mandatory)][string]$LogFile
    )

    Write-Log -Message "Initiating rollback: $Reason" -Level Warning -LogFile $LogFile

    $gitCmd = Get-GitCommand
    if ($null -eq $gitCmd) {
        Write-Log -Message 'Git not available for rollback' -Level Error -LogFile $LogFile
        return $false
    }

    try {
        $checkoutResult = git checkout -- . 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "git checkout failed: $checkoutResult" -Level Warning -LogFile $LogFile
        }

        $cleanResult = git clean -fd 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "git clean failed: $cleanResult" -Level Warning -LogFile $LogFile
        }

        $branchExists = git branch --list $BackupBranch 2>&1
        if ($LASTEXITCODE -eq 0 -and $branchExists) {
            $restoreResult = git checkout $BackupBranch -- . 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "Restored from backup branch: $BackupBranch" -Level Success -LogFile $LogFile
            }
            else {
                Write-Log -Message "Failed to restore from backup: $restoreResult" -Level Warning -LogFile $LogFile
            }
        }

        Write-Log -Message 'Rollback completed successfully' -Level Success -LogFile $LogFile
        return $true
    }
    catch {
        $errorRecord = $_
        Write-Log -Message "Rollback failed: $($errorRecord.Exception.Message)" -Level Error -LogFile $LogFile
        return $false
    }
}

function Remove-BackupBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BackupBranch,
        [Parameter(Mandatory)][string]$LogFile
    )

    $gitCmd = Get-GitCommand
    if ($null -eq $gitCmd) {
        Write-Log -Message 'Git not available for branch cleanup' -Level Warning -LogFile $LogFile
        return
    }

    try {
        $branchExists = git branch --list $BackupBranch 2>&1
        if ($LASTEXITCODE -eq 0 -and $branchExists) {
            $deleteResult = git branch -D $BackupBranch 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message 'Cleaned up backup branch' -Level Debug -LogFile $LogFile
            }
            else {
                Write-Log -Message "Could not delete backup branch: $deleteResult" -Level Warning -LogFile $LogFile
            }
        }
    }
    catch {
        $errorRecord = $_
        Write-Log -Message "Could not clean up backup branch: $($errorRecord.Exception.Message)" -Level Warning -LogFile $LogFile
    }
}

function Invoke-SafeRefactor {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$DescriptionText,
        [Parameter(Mandatory)][string]$ScriptsDir,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][int]$TimeoutMins,
        [bool]$SkipTestsRun,
        [bool]$SkipMetricsRun,
        [bool]$KeepBackupBranch,
        [string]$RefactorCommand,
        [scriptblock]$RefactorScriptBlock
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logFile = Join-Path $ScriptsDir "refactor-log-$timestamp.txt"
    $backupBranch = "backup/safe-refactor-$timestamp"

    $result = [PSCustomObject]@{
        Success     = $false
        Description = $DescriptionText
        StartTime   = Get-Date
        EndTime     = $null
        Duration    = $null
        LogFile     = $logFile
        ExitCode    = 0
        Phase       = 'Init'
        Error       = $null
        Rollback    = $false
    }

    $null = New-Item -Path $logFile -ItemType File -Force
    Write-Log -Message ('=' * 60) -Level Info -LogFile $logFile
    Write-Log -Message "Safe Refactor: $DescriptionText" -Level Info -LogFile $logFile
    Write-Log -Message "Started: $($result.StartTime)" -Level Info -LogFile $logFile
    Write-Log -Message ('=' * 60) -Level Info -LogFile $logFile
    Write-Log -Message '' -Level Info -LogFile $logFile

    Push-Location $ProjectRoot
    try {
        $result.Phase = 'PreFlight'
        Write-Host ''
        Write-Host 'Pre-flight Checks' -ForegroundColor Cyan
        Write-Host ''

        Write-Log -Message 'Checking working tree status...' -Level Info -LogFile $logFile
        if (-not (Test-CleanWorkingTree -LogFile $logFile)) {
            Write-Log -Message 'Working tree has uncommitted changes. Commit or stash them first.' -Level Error -LogFile $logFile
            $result.ExitCode = $script:ExitCodes.PreFlightFailed
            $result.Error = 'Uncommitted changes in working tree'
            throw 'Pre-flight failed'
        }
        Write-Log -Message 'Working tree is clean' -Level Success -LogFile $logFile

        $baselinePath = Join-Path $ScriptsDir 'metrics-baseline.json'
        if (-not $SkipMetricsRun -and -not (Test-Path $baselinePath)) {
            Write-Log -Message 'Baseline metrics not found. Run .\Quality-Gates.ps1 -Mode Measure first.' -Level Error -LogFile $logFile
            $result.ExitCode = $script:ExitCodes.PreFlightFailed
            $result.Error = 'Missing baseline metrics'
            throw 'Pre-flight failed'
        }

        if (-not $SkipTestsRun) {
            Write-Log -Message 'Running pre-flight tests...' -Level Info -LogFile $logFile
            $testResult = Test-CommandSuccess -Name 'npm test' -CommandToRun { npm run test --silent } -LogFile $logFile
            if (-not $testResult.Success) {
                Write-Log -Message 'Pre-flight tests failed. Fix tests before refactoring.' -Level Error -LogFile $logFile
                $result.ExitCode = $script:ExitCodes.PreFlightFailed
                $result.Error = 'Pre-flight tests failed'
                throw 'Pre-flight failed'
            }
            Write-Log -Message 'Pre-flight tests passed' -Level Success -LogFile $logFile
        }
        else {
            Write-Log -Message 'Skipping pre-flight tests' -Level Warning -LogFile $logFile
        }

        $result.Phase = 'Backup'
        Write-Host ''
        Write-Host 'Creating Backup' -ForegroundColor Cyan
        Write-Host ''

        Write-Log -Message "Creating backup branch: $backupBranch" -Level Info -LogFile $logFile
        if ($PSCmdlet.ShouldProcess($backupBranch, 'Create backup branch')) {
            git branch $backupBranch 2>$null
            Write-Log -Message 'Backup branch created' -Level Success -LogFile $logFile
        }

        $result.Phase = 'Refactor'
        Write-Host ''
        Write-Host 'Executing Refactor' -ForegroundColor Cyan
        Write-Host ''

        $refactorDisplay = if (-not [string]::IsNullOrWhiteSpace($RefactorCommand)) { $RefactorCommand } else { $RefactorScriptBlock.ToString() }
        Write-Log -Message "Command: $refactorDisplay" -Level Info -LogFile $logFile

        if ($PSCmdlet.ShouldProcess($refactorDisplay, 'Execute refactoring command')) {
            try {
                $timeoutSeconds = $TimeoutMins * 60

                if (-not [string]::IsNullOrWhiteSpace($RefactorCommand)) {
                    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c $RefactorCommand" -WorkingDirectory $ProjectRoot -PassThru -NoNewWindow
                    $null = $process | Wait-Process -Timeout $timeoutSeconds -ErrorAction SilentlyContinue

                    if (-not $process.HasExited) {
                        $process | Stop-Process -Force -ErrorAction SilentlyContinue
                        throw "Command timed out after $TimeoutMins minutes"
                    }

                    if ($process.ExitCode -ne 0) {
                        throw "Command exited with code: $($process.ExitCode)"
                    }
                }
                else {
                    $job = Start-Job -InitializationScript { Set-Location $using:ProjectRoot } -ScriptBlock $RefactorScriptBlock
                    $completed = $job | Wait-Job -Timeout $timeoutSeconds

                    if ($null -eq $completed) {
                        $job | Stop-Job
                        $job | Remove-Job -Force
                        throw "Script block timed out after $TimeoutMins minutes"
                    }

                    $null = $job | Receive-Job | Out-String
                    if ($job.State -eq 'Failed') {
                        $job | Remove-Job -Force
                        throw 'Script block failed'
                    }
                    $job | Remove-Job -Force
                }

                Write-Log -Message 'Refactoring command completed' -Level Success -LogFile $logFile
            }
            catch {
                $errorRecord = $_
                Write-Log -Message "Refactoring command failed: $($errorRecord.Exception.Message)" -Level Error -LogFile $logFile
                $result.ExitCode = $script:ExitCodes.IOParseError
                $result.Error = "Refactor command failed: $($errorRecord.Exception.Message)"

                $result.Rollback = Invoke-Rollback -Reason 'Refactor command failed' -BackupBranch $backupBranch -LogFile $logFile
                $result.ExitCode = $script:ExitCodes.RollbackCompleted
                throw 'Refactor failed'
            }
        }

        $result.Phase = 'Validation'
        Write-Host ''
        Write-Host 'Post-Refactor Validation' -ForegroundColor Cyan
        Write-Host ''

        Write-Log -Message 'Running lint check...' -Level Info -LogFile $logFile
        $lintResult = Test-CommandSuccess -Name 'npm lint' -CommandToRun { npm run lint --silent 2>&1 } -LogFile $logFile
        if (-not $lintResult.Success) {
            Write-Log -Message "Lint check failed (exit code: $($lintResult.ExitCode))" -Level Error -LogFile $logFile
            $result.ExitCode = $script:ExitCodes.ValidationFailed
            $result.Error = 'Lint check failed'
            $result.Rollback = Invoke-Rollback -Reason 'Lint check failed' -BackupBranch $backupBranch -LogFile $logFile
            $result.ExitCode = $script:ExitCodes.RollbackCompleted
            throw 'Validation failed'
        }
        Write-Log -Message 'Lint check passed' -Level Success -LogFile $logFile

        Write-Log -Message 'Running type check...' -Level Info -LogFile $logFile
        $typeResult = Test-CommandSuccess -Name 'npm type-check' -CommandToRun { npm run type-check --silent 2>&1 } -LogFile $logFile
        if (-not $typeResult.Success) {
            Write-Log -Message "Type check failed (exit code: $($typeResult.ExitCode))" -Level Error -LogFile $logFile
            $result.ExitCode = $script:ExitCodes.ValidationFailed
            $result.Error = 'Type check failed'
            $result.Rollback = Invoke-Rollback -Reason 'Type check failed' -BackupBranch $backupBranch -LogFile $logFile
            $result.ExitCode = $script:ExitCodes.RollbackCompleted
            throw 'Validation failed'
        }
        Write-Log -Message 'Type check passed' -Level Success -LogFile $logFile

        if (-not $SkipTestsRun) {
            Write-Log -Message 'Running post-refactor tests...' -Level Info -LogFile $logFile
            $postTestResult = Test-CommandSuccess -Name 'npm test' -CommandToRun { npm run test --silent 2>&1 } -LogFile $logFile
            if (-not $postTestResult.Success) {
                Write-Log -Message "Post-refactor tests failed (exit code: $($postTestResult.ExitCode))" -Level Error -LogFile $logFile
                $result.ExitCode = $script:ExitCodes.ValidationFailed
                $result.Error = 'Post-refactor tests failed'
                $result.Rollback = Invoke-Rollback -Reason 'Post-refactor tests failed' -BackupBranch $backupBranch -LogFile $logFile
                $result.ExitCode = $script:ExitCodes.RollbackCompleted
                throw 'Validation failed'
            }
            Write-Log -Message 'Post-refactor tests passed' -Level Success -LogFile $logFile
        }

        if (-not $SkipMetricsRun) {
            $result.Phase = 'Metrics'
            Write-Host ''
            Write-Host 'Metrics Comparison' -ForegroundColor Cyan
            Write-Host ''

            Write-Log -Message 'Comparing metrics against baseline...' -Level Info -LogFile $logFile

            $compareResult = Invoke-Compare -BaselineFileName 'metrics-baseline.json' -CurrentFileName 'metrics-current.json' -ReportFileName $null -CoverageGate 0 -DuplicationGate 0 -ComplexityGate 0 -StrictMode:$false -SkipCapture:$false

            if ($compareResult.ExitCode -ne 0) {
                Write-Log -Message 'Metrics gates failed' -Level Error -LogFile $logFile
                $result.ExitCode = $script:ExitCodes.MetricsFailed
                $result.Error = 'Metrics gates failed'
                $result.Rollback = Invoke-Rollback -Reason 'Metrics gates failed' -BackupBranch $backupBranch -LogFile $logFile
                $result.ExitCode = $script:ExitCodes.RollbackCompleted
                throw 'Metrics failed'
            }

            Write-Log -Message 'Metrics gates passed' -Level Success -LogFile $logFile
        }

        $result.Phase = 'Complete'
        $result.Success = $true

        if (-not $KeepBackupBranch) {
            Remove-BackupBranch -BackupBranch $backupBranch -LogFile $logFile
        }
        else {
            Write-Log -Message "Keeping backup branch: $backupBranch" -Level Info -LogFile $logFile
        }

        Write-Host ''
        Write-Host ('=' * 60) -ForegroundColor Green
        Write-Host 'REFACTOR COMPLETED SUCCESSFULLY' -ForegroundColor Green
        Write-Host ('=' * 60) -ForegroundColor Green
        Write-Host ''

        Write-Log -Message 'Refactor completed successfully' -Level Success -LogFile $logFile
    }
    catch {
        if (-not $result.Error) {
            $result.Error = $_.Exception.Message
        }

        Write-Host ''
        Write-Host ('=' * 60) -ForegroundColor Red
        Write-Host 'REFACTOR FAILED' -ForegroundColor Red
        if ($result.Rollback) {
            Write-Host '   Changes have been rolled back' -ForegroundColor Yellow
        }
        Write-Host ('=' * 60) -ForegroundColor Red
        Write-Host ''
    }
    finally {
        $result.EndTime = Get-Date
        $result.Duration = $result.EndTime - $result.StartTime

        Write-Log -Message '' -Level Info -LogFile $logFile
        Write-Log -Message ('=' * 60) -Level Info -LogFile $logFile
        Write-Log -Message "Completed: $($result.EndTime)" -Level Info -LogFile $logFile
        Write-Log -Message "Duration:  $($result.Duration.ToString('mm\:ss'))" -Level Info -LogFile $logFile
        Write-Log -Message "Log file:  $logFile" -Level Info -LogFile $logFile
        Write-Log -Message ('=' * 60) -Level Info -LogFile $logFile

        Pop-Location
    }

    Write-Host ''
    Write-Host "Log file: $logFile" -ForegroundColor Gray
    Write-Host ''

    return $result
}

# --- Entry point ---
Assert-ModeParameters -SelectedMode $Mode

try {
    switch ($Mode) {
        'Measure' {
            $result = Invoke-Measure -OutFileName $OutFile -Targets $TargetPath -SkipCoverageCollection:$SkipCoverage -SkipSecurityCollection:$SkipSecurity -SkipDependenciesCollection:$SkipDependencies
            if ($PassThru) { Write-Output $result }
            exit $script:ExitCodes.Success
        }
        'Compare' {
            $compare = Invoke-Compare -BaselineFileName $BaselineFile -CurrentFileName $CurrentFile -ReportFileName $ReportFile -CoverageGate $CoverageThreshold -DuplicationGate $DuplicationThreshold -ComplexityGate $ComplexityThreshold -StrictMode:$Strict -SkipCapture:$SkipCurrentCapture
            if ($PassThru) { Write-Output $compare.Comparison }
            exit $compare.ExitCode
        }
        'SafeRefactor' {
            $safe = Invoke-SafeRefactor -DescriptionText $Description -ScriptsDir $script:scriptsDir -ProjectRoot $script:projectRoot -TimeoutMins $TimeoutMinutes -SkipTestsRun:$SkipTests -SkipMetricsRun:$SkipMetrics -KeepBackupBranch:$KeepBackup -RefactorCommand $Command -RefactorScriptBlock $ScriptBlock
            if ($PassThru) { Write-Output $safe }
            exit $safe.ExitCode
        }
    }
}
catch {
    $errorRecord = $_
    Write-Error $errorRecord.Exception.Message

    # Match legacy scripts: Compare uses IOParseError for parse/IO errors.
    if ($Mode -eq 'Compare') { exit $script:ExitCodes.IOParseError }

    # Measure historically throws; map to a non-zero exit for automation.
    if ($Mode -eq 'Measure') { exit $script:ExitCodes.IOParseError }

    # SafeRefactor fatal
    exit $script:ExitCodes.Fatal
}
