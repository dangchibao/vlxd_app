#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
$src = 'lib\ui\catalog.dart'
if (-not (Test-Path $src) -or -not ([IO.File]::ReadAllText((Resolve-Path $src))).Contains('product-action-row-exact-v4')) {
  throw 'V4 icons NOT found. Run 01 first.'
}
if (Get-Process vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai Windows first.' }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
Write-Host '[SUCCESS] Windows V4 release built: build\windows\x64\runner\Release\vlxd_app.exe' -ForegroundColor Green
