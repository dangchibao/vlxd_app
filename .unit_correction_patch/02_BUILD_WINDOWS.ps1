$ErrorActionPreference = 'Stop'
Set-Location 'D:\app\vlxd_app'
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build FAILED' }
Write-Host '[SUCCESS] D:\app\vlxd_app\build\windows\x64\runner\Release\vlxd_app.exe' -ForegroundColor Green
Write-Host 'Close previous app before testing new EXE. Do not copy just EXE without other Release files.'
