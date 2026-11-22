#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
Set-Location -LiteralPath $root
if (-not ([IO.File]::ReadAllText((Join-Path $root 'lib\ui\catalog.dart')).Contains('vlxd-responsive-real-v3'))) { throw 'V3 exact UI patch not detected.' }
$builder = Join-Path $root '.web_pwa_build\build-web-pwa.ps1'
if (-not (Test-Path -LiteralPath $builder)) {
  throw 'Existing PWA offline manifest builder not found. Not building plain web in place of offline-capable PWA.'
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder
if ($LASTEXITCODE -ne 0) { throw 'Web/PWA build failed' }
if (-not (Test-Path (Join-Path $root 'build\web\main.dart.js')) -or -not (Test-Path (Join-Path $root 'build\web\offline-manifest.js'))) { throw 'Web/PWA output is incomplete.' }
Write-Host '[OK] Web/PWA build complete; no Firebase Hosting deployment.' -ForegroundColor Green
