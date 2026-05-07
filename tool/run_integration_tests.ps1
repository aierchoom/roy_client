<#
.SYNOPSIS
    SecretRoy Windows desktop one-click integration test runner
.DESCRIPTION
    Sets up temp test directory, runs all integration_test scripts, outputs summary report.
    Requires Flutter SDK and `flutter pub get` to have been run.
.EXAMPLE
    .\tool\run_integration_tests.ps1
#>

$ErrorActionPreference = 'Stop'
$host.ui.RawUI.WindowTitle = 'SecretRoy Integration Tests'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SecretRoy PC Automation Test" -ForegroundColor Cyan
Write-Host "Each test file uses an isolated temp data dir." -ForegroundColor DarkGray
Write-Host "========================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 2. Find all test scripts
# ------------------------------------------------------------------------------
$scriptRoot = Split-Path -Parent $PSScriptRoot
$testFiles = Get-ChildItem -Path (Join-Path $scriptRoot 'integration_test') -Filter '*.dart' | Sort-Object Name

if ($testFiles.Count -eq 0) {
    Write-Host "Error: no .dart test scripts found in integration_test/" -ForegroundColor Red
    exit 1
}

Write-Host ("Found " + $testFiles.Count + " test scripts:`n")
$testFiles | ForEach-Object { Write-Host ("  - " + $_.Name) }
Write-Host ""

# ------------------------------------------------------------------------------
# 3. Execute one by one
# ------------------------------------------------------------------------------
$passed = 0
$failed = 0
$results = @()

foreach ($file in $testFiles) {
    $safeName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $testDir = Join-Path $env:TEMP ("secret_roy_integration_test_" + [DateTime]::Now.ToString('yyyyMMdd_HHmmss_fff') + "_" + $safeName)
    New-Item -ItemType Directory -Force -Path $testDir | Out-Null
    $env:SECRETROY_TEST_DIR = $testDir
    $env:SECRETROY_TEST_DISABLE_NO_PASSWORD = '1'

    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host ("Running: " + $file.Name + " ...") -ForegroundColor Yellow
    Write-Host ("Test data dir: " + $testDir) -ForegroundColor DarkGray
    Write-Host "----------------------------------------" -ForegroundColor DarkGray

    $start = Get-Date
    try {
        flutter test -d windows ("integration_test/" + $file.Name) --reporter expanded
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 1
    } finally {
        Write-Host "Cleaning up test data directory ..." -ForegroundColor DarkGray
        Remove-Item -Recurse -Force -Path $testDir -ErrorAction SilentlyContinue
        Write-Host ("Cleaned: " + $testDir) -ForegroundColor DarkGray
    }
    $duration = (Get-Date) - $start

    if ($exitCode -eq 0) {
        $passed++
        $status = 'PASS'
        $color = 'Green'
    } else {
        $failed++
        $status = 'FAIL'
        $color = 'Red'
    }

    $results += [PSCustomObject]@{
        Name     = $file.Name
        Status   = $status
        Duration = "{0:mm\:ss\.fff}" -f $duration
    }

    Write-Host ("[" + $status + "] " + $file.Name + " (" + $duration.ToString('s\.fff') + ")") -ForegroundColor $color
    Write-Host ""
}

# ------------------------------------------------------------------------------
# 4. Summary report
# ------------------------------------------------------------------------------
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results | Format-Table -AutoSize | Out-String | Write-Host

$total = $passed + $failed
if ($failed -eq 0) { $summaryColor = 'Green' } else { $summaryColor = 'Yellow' }
Write-Host ("Total: " + $total + "  |  Pass: " + $passed + "  |  Fail: " + $failed) -ForegroundColor $summaryColor

# ------------------------------------------------------------------------------
# 5. Exit code
# ------------------------------------------------------------------------------
if ($failed -gt 0) {
    Write-Host "`nTests failed, please check output above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll tests passed." -ForegroundColor Green
    exit 0
}
