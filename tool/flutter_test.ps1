param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$localAppData = Join-Path $repoRoot '.dart_appdata'
New-Item -ItemType Directory -Force -Path $localAppData | Out-Null
$env:APPDATA = $localAppData

if ($FlutterArgs.Count -eq 0) {
  $FlutterArgs = @('test')
} elseif ($FlutterArgs[0] -ne 'test') {
  $FlutterArgs = @('test') + $FlutterArgs
}

$flutterBin = $env:FLUTTER_BIN
if ([string]::IsNullOrWhiteSpace($flutterBin)) {
  $defaultFlutter = 'F:\FlutterSDK\flutter\bin\flutter.bat'
  $flutterBin = if (Test-Path $defaultFlutter) { $defaultFlutter } else { 'flutter' }
}

# NOTE: pubspec_overrides.yaml with `hooks:` is no longer supported by Flutter 3.38+.
# sqlite3 3.3.1 uses native_assets; winsqlite3.dll is auto-detected on Windows.
$exitCode = 0

Push-Location $repoRoot
try {
  & $flutterBin @FlutterArgs
  if ($null -ne $LASTEXITCODE) {
    $exitCode = $LASTEXITCODE
  }
} finally {
  Pop-Location
}

exit $exitCode
