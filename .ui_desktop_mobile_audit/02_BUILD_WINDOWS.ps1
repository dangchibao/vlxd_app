#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
Set-Location -LiteralPath $root
if (-not ([IO.File]::ReadAllText((Join-Path $root 'lib\ui\catalog.dart')).Contains('vlxd-responsive-correction-v1'))) { throw 'UI review patch not installed.' }
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai Windows.' }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
Write-Host '[OK] build\windows\x64\runner\Release\vlxd_app.exe' -ForegroundColor Green
Write-Host 'EXE built, existing installer not overwritten. Do not delete SQLite/Outbox.'
