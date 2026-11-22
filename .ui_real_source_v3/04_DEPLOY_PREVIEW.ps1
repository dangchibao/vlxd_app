#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath 'D:\app\vlxd_app'
if (-not (Test-Path -LiteralPath '.\build\web\offline-manifest.js')) { throw 'Missing web PWA build; run 03 first.' }
& firebase hosting:channel:deploy ui-real-source-v3 --project vlxd-bay-hai --expires 1d
if ($LASTEXITCODE -ne 0) { throw 'Preview deployment failed.' }
Write-Host '[OK] Preview ready. Check phone and desktop; NOT production Hosting.' -ForegroundColor Green
