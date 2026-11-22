#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
if (-not (Test-Path '.\pubspec.yaml')) { throw 'Run from D:\app\vlxd_app.' }
$catalog = [IO.File]::ReadAllText((Join-Path $root 'lib\ui\catalog.dart'), [Text.Encoding]::UTF8)
if (-not $catalog.Contains('vlxd-low-stock-space-v1')) { throw 'Spacing patch not found. Run 01 first.' }
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai Windows app before build.' }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows release build failed.' }
$exe = Join-Path $root 'build\windows\x64\runner\Release\vlxd_app.exe'
if (-not (Test-Path $exe)) { throw 'Windows EXE not found after build.' }
Write-Host "[OK] Windows Release created: $exe" -ForegroundColor Green
Write-Host '[NOTE] Release EXE does not update an already installed Windows application.' -ForegroundColor Yellow
