#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
$stamp = '.action-icons-v4-build.sha256'
if (-not (Test-Path $stamp)) { throw 'No verified V4 web build. Run 03_BUILD_WEB_V4.ps1.' }
$expected = [IO.File]::ReadAllText((Resolve-Path $stamp)).Trim()
$actual = (Get-FileHash -Algorithm SHA256 -LiteralPath 'lib\ui\catalog.dart').Hash
if ($expected -ne $actual) { throw 'catalog.dart changed after build. Rebuild before deploy.' }
if (-not (Test-Path 'build\web\main.dart.js') -or -not (Test-Path 'build\web\offline-manifest.js')) {
  throw 'Web build files missing. Do not deploy.'
}
Write-Host 'WARNING: This publishes your local build to live https://vlxd-bay-hai.web.app' -ForegroundColor Yellow
$confirm = Read-Host 'Type DANG to confirm LIVE Hosting deployment'
if ($confirm -cne 'DANG') { throw 'Cancelled without deploying.' }
& firebase deploy --only hosting --project vlxd-bay-hai
if ($LASTEXITCODE -ne 0) { throw 'Live Hosting deployment failed.' }
Write-Host '[SUCCESS] V4 UI uploaded to https://vlxd-bay-hai.web.app' -ForegroundColor Green
