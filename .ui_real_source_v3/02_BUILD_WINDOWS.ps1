#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
Set-Location -LiteralPath $root
if (-not ([IO.File]::ReadAllText((Join-Path $root 'lib\ui\catalog.dart')).Contains('vlxd-responsive-real-v3'))) { throw 'V3 exact UI patch not detected.' }
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai Windows before build.' }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows Release build failed' }
Write-Host '[OK] build\windows\x64\runner\Release\vlxd_app.exe' -ForegroundColor Green
Write-Host 'Release EXE only; not a Windows Setup. Existing installed app unchanged.'
