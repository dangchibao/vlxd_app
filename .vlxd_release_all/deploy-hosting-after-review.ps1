#Requires -Version 5.1
# Deploys an ALREADY BUILT Web/PWA to the existing Firebase Hosting project.
# No build, no Firebase Rules changes, no Firestore operations.
[CmdletBinding()]
param(
  [string]$ProjectRoot = 'D:\app\vlxd_app',
  [switch]$IReviewedAllDeviceQueues
)
$ErrorActionPreference = 'Stop'
try {
  if (-not $IReviewedAllDeviceQueues) {
    throw 'Review all pending/failed/uncertain offline orders on EVERY Windows, Android and PWA device first. Then add -IReviewedAllDeviceQueues.'
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $public = Join-Path $ProjectRoot 'build\web'
  foreach ($required in @('index.html','main.dart.js','offline-sw.js','offline-manifest.js','manifest.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $public $required) -PathType Leaf)) {
      throw "Missing build/Web/PWA resource: $required. Run build-and-release.ps1 first."
    }
  }
  $json = Get-Content -LiteralPath (Join-Path $ProjectRoot 'firebase.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$json.hosting.public -cne 'build/web') { throw 'Wrong firebase.json Hosting public folder.' }
  $null = Get-Command firebase.cmd -ErrorAction Stop
  Push-Location -LiteralPath $ProjectRoot
  try {
    Write-Host 'Deploying ONLY Hosting to vlxd-bay-hai; Firestore Rules/Data untouched.' -ForegroundColor Cyan
    & firebase.cmd deploy --only hosting --project vlxd-bay-hai --non-interactive
    if ($LASTEXITCODE -ne 0) { throw "Firebase deploy failed ($LASTEXITCODE)." }
  } finally { Pop-Location }
  Write-Host 'Hosting deploy finished: https://vlxd-bay-hai.web.app/' -ForegroundColor Green
  Write-Warning 'PWA users should close/reopen their app to load a new Service Worker. Do not clear site data with pending offline orders.'
} catch {
  Write-Host "[DEPLOY FAILED] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
