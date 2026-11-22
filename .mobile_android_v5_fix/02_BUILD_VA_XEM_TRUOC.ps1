$ErrorActionPreference='Stop'
if (!(Test-Path '.\pubspec.yaml')) { throw 'Cd D:\app\vlxd_app first' }
& flutter build web --release
if ($LASTEXITCODE -ne 0) { throw 'Web build failed' }
# Use previous already-tested manifest generation script to keep offline PWA support.
$prev = 'D:\app\vlxd_app\.ui_real_source_v3\03_BUILD_WEB_PWA.ps1'
if (Test-Path $prev) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $prev
  if ($LASTEXITCODE -ne 0) { throw 'PWA manifest script failed' }
} else {
  throw 'Previous PWA build script missing; web compiled but do not deploy before regenerating offline-manifest.js.'
}
& firebase hosting:channel:deploy mobile-ui-v4 --project vlxd-bay-hai --expires 2d
if ($LASTEXITCODE -ne 0) { throw 'Preview deployment failed' }
Write-Host '[OK] Check Firebase preview URL on phone; LIVE NOT CHANGED.' -ForegroundColor Green
