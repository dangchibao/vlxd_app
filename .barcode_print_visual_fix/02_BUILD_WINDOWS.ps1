#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
if (Get-Process vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai before building Windows.' }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build FAILED' }
Write-Host '[OK] Windows EXE built: D:\app\vlxd_app\build\windows\x64\runner\Release\vlxd_app.exe' -ForegroundColor Green
Write-Host 'Keep the entire Release directory with the EXE. Setup must be built separately.'
