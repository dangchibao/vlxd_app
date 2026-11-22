$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
$builder = 'D:\app\vlxd_app\.web_pwa_build\build-web-pwa.ps1'
if (Test-Path -LiteralPath $builder) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder
  if ($LASTEXITCODE -ne 0) { throw 'PWA build script FAILED' }
} else {
  & flutter build web --release
  if ($LASTEXITCODE -ne 0) { throw 'Web build FAILED' }
  Write-Host 'Web build done. PWA offline-manifest creation still required before deployment.' -ForegroundColor Yellow
}
Write-Host 'This command does NOT deploy to Firebase Hosting. Check release before publishing.'
