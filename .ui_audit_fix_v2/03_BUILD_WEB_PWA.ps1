#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
Set-Location -LiteralPath $root
if (-not ([IO.File]::ReadAllText((Join-Path $root 'lib\ui\catalog.dart')).Contains('vlxd-responsive-correction-v1'))) { throw 'UI review patch not installed.' }
$builder = Join-Path $root '.web_pwa_build\build-web-pwa.ps1'
if (-not (Test-Path -LiteralPath $builder)) { throw 'Missing previous PWA manifest builder. NO HOSTING DEPLOY.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder
if ($LASTEXITCODE -ne 0) { throw 'Web/PWA build failed.' }
if (-not (Test-Path (Join-Path $root 'build\web\main.dart.js')) -or -not (Test-Path (Join-Path $root 'build\web\offline-manifest.js'))) { throw 'Web output missing.' }
Write-Host '[OK] Web/PWA build complete. Not deployed to Firebase.' -ForegroundColor Green
