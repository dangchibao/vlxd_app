#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
if (Get-Process vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai before build.' }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed' }
Write-Host '[OK] D:\app\vlxd_app\build\windows\x64\runner\Release\vlxd_app.exe' -ForegroundColor Green
