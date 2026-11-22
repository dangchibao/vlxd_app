#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
$src = 'lib\ui\catalog.dart'
$body = [IO.File]::ReadAllText((Resolve-Path $src),[Text.Encoding]::UTF8)
if (-not $body.Contains('product-action-row-exact-v4')) { throw 'V4 icons NOT found. Run 01 first.' }
$builder = '.\.web_pwa_build\build-web-pwa.ps1'
if (-not (Test-Path $builder)) { throw 'Missing previously installed PWA builder.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder
if ($LASTEXITCODE -ne 0) { throw 'Web/PWA build failed.' }
if (-not (Test-Path 'build\web\main.dart.js') -or -not (Test-Path 'build\web\offline-manifest.js')) {
  throw 'Web assets missing after build. Do not deploy.'
}
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $src).Hash
[IO.File]::WriteAllText((Join-Path (Resolve-Path .).Path '.action-icons-v4-build.sha256'),$hash)
Write-Host "[OK] Web built with V4 icons. Source SHA256: $hash" -ForegroundColor Green
Write-Host '[NEXT] Preview: 04_DEPLOY_PREVIEW_V4.ps1. Site unchanged until deployment.' -ForegroundColor Yellow
