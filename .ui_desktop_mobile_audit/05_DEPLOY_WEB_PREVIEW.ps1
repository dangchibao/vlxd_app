#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath 'D:\app\vlxd_app'
if (-not (Test-Path -LiteralPath '.\build\web\offline-manifest.js')) { throw 'PWA build missing. Run 03 first.' }
& firebase hosting:channel:deploy ui-responsive-review --project vlxd-bay-hai --expires 1d
if ($LASTEXITCODE -ne 0) { throw 'Preview deployment failed' }
Write-Host '[OK] Preview is online. DO NOT deploy live before checking phone + laptop.' -ForegroundColor Green
