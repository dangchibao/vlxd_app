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
& firebase hosting:channel:deploy exact-icons-v4 --project vlxd-bay-hai --expires 1d
if ($LASTEXITCODE -ne 0) { throw 'Preview Hosting deployment failed.' }
Write-Host '[OK] Preview uploaded. Check the URL returned above.' -ForegroundColor Green
