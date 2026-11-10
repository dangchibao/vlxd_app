param(
  [switch]$RunBrowserQa,
  [switch]$BuildWindows,
  [switch]$BuildWeb,
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

function Run-Checked([string]$Program, [string[]]$Arguments) {
  Write-Host ("RUN: " + $Program + ' ' + ($Arguments -join ' '))
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Program returned exit code $LASTEXITCODE" }
}

if (-not (Test-Path 'pubspec.yaml')) { throw 'Run this command from the Flutter project root.' }
if (-not (Test-Path 'lib/main.dart')) { throw 'Missing lib/main.dart.' }

if (-not $SkipTests) {
  # Analyzer info lints are non-blocking; errors and warnings remain blocking.
  Run-Checked 'flutter' @('analyze', '--no-fatal-infos')
  Run-Checked 'flutter' @('test')
}

if ($RunBrowserQa) {
  # Only a demo project is acceptable. User must start Auth/Firestore emulators.
  foreach ($port in @(9099, 8080)) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
      $connect = $tcp.BeginConnect('127.0.0.1', [int]$port, $null, $null)
      if (-not $connect.AsyncWaitHandle.WaitOne(1500)) {
        throw "Emulator port $port is unavailable"
      }
      $tcp.EndConnect($connect)
    } finally { $tcp.Close() }
  }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tools\build-web-offline.ps1' -Emulator -Output 'build/web-offline-qa'
  if ($LASTEXITCODE -ne 0) { throw 'Emulator web build failed.' }
  Run-Checked 'node' @('.qa/offline-browser.cjs')
}

if ($BuildWeb) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tools\build-web-offline.ps1' -Output 'build/web'
  if ($LASTEXITCODE -ne 0) { throw 'Production web build failed.' }
  Write-Warning 'Built production web files with auto-sync disabled. This is NOT authorization to deploy.'
}
if ($BuildWindows) {
  Run-Checked 'flutter' @('build', 'windows', '--release', '--dart-define=AUTO_SYNC_OUTBOX=false', '--dart-define=ALLOW_PRODUCTION_AUTO_SYNC=false')
  Write-Warning 'Windows release was built with auto-sync disabled pending production sign-off.'
}
Write-Host 'Selected checks/builds completed.'
