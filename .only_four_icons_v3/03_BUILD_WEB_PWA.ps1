#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
$builder = '.\.web_pwa_build\build-web-pwa.ps1'
if (-not (Test-Path -LiteralPath $builder)) { throw 'Missing .web_pwa_build\build-web-pwa.ps1' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder
if ($LASTEXITCODE -ne 0) { throw 'Web/PWA build failed' }
if (-not (Test-Path 'build\web\offline-manifest.js')) { throw 'Missing offline-manifest.js; do not deploy!' }
Write-Host '[OK] Web/PWA local build done. No Hosting deployment.' -ForegroundColor Green
