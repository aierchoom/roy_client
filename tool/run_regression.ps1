<#
.SYNOPSIS
    SecretRoy 一键回归测试脚本（Windows）
.DESCRIPTION
    运行 analyze → style check → unit test (含 coverage) → integration test，
    输出汇总报告。基于 flutter_test.ps1 的 winsqlite3 处理逻辑。
.PARAMETER UnitOnly
    只运行单元测试阶段（analyze + style + unit + coverage）。
.PARAMETER IntegrationOnly
    只运行集成测试阶段。
.PARAMETER NoCoverage
    跳过覆盖率生成。
.EXAMPLE
    .\tool\run_regression.ps1
    .\tool\run_regression.ps1 -UnitOnly
    .\tool\run_regression.ps1 -IntegrationOnly
#>

param(
    [switch]$UnitOnly,
    [switch]$IntegrationOnly,
    [switch]$NoCoverage
)

$ErrorActionPreference = 'Stop'
$host.ui.RawUI.WindowTitle = 'SecretRoy Regression Tests'

# ------------------------------------------------------------------------------
# 1. 环境准备
# ------------------------------------------------------------------------------
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$localAppData = Join-Path $repoRoot '.dart_appdata'
New-Item -ItemType Directory -Force -Path $localAppData | Out-Null
$env:APPDATA = $localAppData

$flutterBin = $env:FLUTTER_BIN
if ([string]::IsNullOrWhiteSpace($flutterBin)) {
  $defaultFlutter = 'F:\FlutterSDK\flutter\bin\flutter.bat'
  $flutterBin = if (Test-Path $defaultFlutter) { $defaultFlutter } else { 'flutter' }
}

# NOTE: pubspec_overrides.yaml with `hooks:` is no longer supported by Flutter 3.38+.
# sqlite3 3.3.1 uses native_assets; winsqlite3.dll is auto-detected on Windows.
$createdOverride = $false

function Setup-Override {
    return $false
}

function Cleanup-Override {
    param([bool]$created)
}

# ------------------------------------------------------------------------------
# 2. 阶段执行器
# ------------------------------------------------------------------------------
$globalResults = @()
$overallPassed = $true

function Run-Stage {
    param(
        [string]$Name,
        [scriptblock]$Block
    )
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Name -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    $start = Get-Date
    $exitCode = 0
    try {
        & $Block
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            $exitCode = $LASTEXITCODE
        }
    } catch {
        $exitCode = 1
        Write-Host "Exception: $_" -ForegroundColor Red
    }
    $duration = (Get-Date) - $start
    $passed = ($exitCode -eq 0)
    if (-not $passed) { $script:overallPassed = $false }
    $script:globalResults += [PSCustomObject]@{
        Name     = $Name
        Status   = if ($passed) { 'PASS' } else { 'FAIL' }
        Duration = "{0:mm\:ss\.fff}" -f $duration
    }
    Write-Host ""
    Write-Host ("[{0}] {1} ({2})" -f $(if ($passed){'PASS'}else{'FAIL'}), $Name, $duration.ToString('s\.fff')) -ForegroundColor $(if ($passed){'Green'}else{'Red'})
    Write-Host ""
    return $passed
}

# ------------------------------------------------------------------------------
# 3. 各阶段定义
# ------------------------------------------------------------------------------
$unitStages = @(
    @{
        Name = 'Dart Analyze'
        Block = {
            Push-Location $repoRoot
            try {
                & $flutterBin analyze lib test
                if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }
            } finally { Pop-Location }
        }
    },
    @{
        Name = 'Style Token Check'
        Block = {
            $python = Get-Command python3 -ErrorAction SilentlyContinue
            if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
            if (-not $python) {
                Write-Host "Python not found, skipping style token check." -ForegroundColor Yellow
                exit 0
            }
            Push-Location $repoRoot
            try {
                & $python.Path tool/check_style_tokens.py
                if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }
            } finally { Pop-Location }
        }
    },
    @{
        Name = 'Unit Tests'
        Block = {
            Push-Location $repoRoot
            try {
                $args = if ($NoCoverage) { @('test') } else { @('test', '--coverage') }
                & $flutterBin @args
                if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE }
            } finally { Pop-Location }
        }
    }
)

$integrationStages = @(
    @{
        Name = 'Integration Tests'
        Block = {
            $scriptRoot = $repoRoot
            $testFiles = Get-ChildItem -Path (Join-Path $scriptRoot 'integration_test') -Filter '*.dart' | Sort-Object Name
            if ($testFiles.Count -eq 0) {
                Write-Host "No integration test files found." -ForegroundColor Yellow
                exit 0
            }
            $allPassed = $true
            foreach ($file in $testFiles) {
                $safeName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
                $testDir = Join-Path $env:TEMP ("secret_roy_integration_test_" + [DateTime]::Now.ToString('yyyyMMdd_HHmmss_fff') + "_" + $safeName)
                New-Item -ItemType Directory -Force -Path $testDir | Out-Null
                $env:SECRETROY_TEST_DIR = $testDir
                $env:SECRETROY_TEST_DISABLE_NO_PASSWORD = '1'
                Write-Host "Running: $($file.Name)" -ForegroundColor Yellow
                try {
                    & $flutterBin test -d windows ("integration_test/" + $file.Name) --reporter expanded
                    if ($LASTEXITCODE -ne 0) { $allPassed = $false }
                } catch {
                    $allPassed = $false
                } finally {
                    # Wait for unawaited closeStorage() to finish writing the
                    # encrypted database file, otherwise Remove-Item races it.
                    Start-Sleep -Seconds 5
                    Remove-Item -Recurse -Force -Path $testDir -ErrorAction SilentlyContinue
                }
            }
            if (-not $allPassed) { exit 1 }
        }
    }
)

# ------------------------------------------------------------------------------
# 4. 执行
# ------------------------------------------------------------------------------
$created = Setup-Override

try {
    $stagesToRun = @()
    if ($UnitOnly) {
        $stagesToRun = $unitStages
    } elseif ($IntegrationOnly) {
        $stagesToRun = $integrationStages
    } else {
        $stagesToRun = $unitStages + $integrationStages
    }

    foreach ($stage in $stagesToRun) {
        Run-Stage -Name $stage.Name -Block $stage.Block
    }
} finally {
    Cleanup-Override -created $created
}

# ------------------------------------------------------------------------------
# 5. 汇总
# ------------------------------------------------------------------------------
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Regression Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$globalResults | Format-Table -AutoSize | Out-String | Write-Host

$passedCount = ($globalResults | Where-Object { $_.Status -eq 'PASS' }).Count
$failedCount = ($globalResults | Where-Object { $_.Status -eq 'FAIL' }).Count
$totalCount = $globalResults.Count

if ($failedCount -eq 0) {
    Write-Host "All $totalCount stages passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Failed: $failedCount / $totalCount" -ForegroundColor Red
    exit 1
}
