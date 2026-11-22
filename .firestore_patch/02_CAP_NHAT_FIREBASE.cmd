@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-firestore.ps1" -ProjectRoot "D:\app\vlxd_app"
set RESULT=%ERRORLEVEL%
echo.
if not "%RESULT%"=="0" echo Firebase chua duoc deploy - xem thong bao phia tren.
pause
exit /b %RESULT%
