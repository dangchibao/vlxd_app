#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
if (-not (Test-Path '.\pubspec.yaml')) { throw 'Run from D:\app\vlxd_app.' }
$catalogFile = Join-Path $root 'lib\ui\catalog.dart'
$catalog = [IO.File]::ReadAllText($catalogFile, [Text.Encoding]::UTF8)
if (-not $catalog.Contains('vlxd-low-stock-space-v1')) { throw 'Spacing patch not found. Do not deploy.' }
$jsFile = Join-Path $root 'build\web\main.dart.js'
$manifestFile = Join-Path $root 'build\web\offline-manifest.js'
if (-not (Test-Path $jsFile) -or -not (Test-Path $manifestFile)) { throw 'Web/PWA build missing. Run 03 first.' }
if ((Get-Item $jsFile).LastWriteTimeUtc -lt (Get-Item $catalogFile).LastWriteTimeUtc) {
    throw 'Web build older than UI source. Run 03 again to avoid deploying stale UI.'
}
Write-Host '[LIVE] This will replace https://vlxd-bay-hai.web.app' -ForegroundColor Yellow
$answer = Read-Host 'Type DANG to publish LIVE (any other input cancels)'
if ($answer -cne 'DANG') { Write-Host '[CANCELLED] No deployment.'; exit 0 }
& firebase deploy --only hosting --project vlxd-bay-hai
if ($LASTEXITCODE -ne 0) { throw 'Production Hosting deployment failed.' }
Write-Host '[SUCCESS] Updated official VLXD Bay Hai Web/PWA.' -ForegroundColor Green
