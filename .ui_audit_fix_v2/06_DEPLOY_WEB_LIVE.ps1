#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath 'D:\app\vlxd_app'
if (-not (Test-Path -LiteralPath '.\build\web\offline-manifest.js')) { throw 'PWA build missing. Run 03 first.' }
$confirmation = Read-Host 'Checked live preview on phone and laptop? Type DANG to publish'
if ($confirmation -cne 'DANG') { throw 'Live deployment cancelled.' }
& firebase deploy --only hosting --project vlxd-bay-hai
if ($LASTEXITCODE -ne 0) { throw 'Live deployment failed' }
Write-Host '[OK] Web/PWA live deploy completed.' -ForegroundColor Green
