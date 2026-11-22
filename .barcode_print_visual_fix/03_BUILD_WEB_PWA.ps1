#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
$builder = '.\.web_pwa_build\build-web-pwa.ps1'
if (-not (Test-Path -LiteralPath $builder)) { throw 'Missing .web_pwa_build\build-web-pwa.ps1. Use the previously installed Web/PWA build package first.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder
if ($LASTEXITCODE -ne 0) { throw 'Web/PWA build FAILED' }
if (-not (Test-Path 'build\web\offline-manifest.js')) { throw 'Missing offline manifest: DO NOT deploy Web/PWA.' }
Write-Host '[OK] Web/PWA built locally. Hosting has NOT been deployed.' -ForegroundColor Green
