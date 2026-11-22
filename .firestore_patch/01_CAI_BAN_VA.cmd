@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-firestore-rule.ps1" -ProjectRoot "D:\app\vlxd_app"
set RESULT=%ERRORLEVEL%
echo.
if not "%RESULT%"=="0" echo Sua rules chua thanh cong - xem thong bao phia tren.
pause
exit /b %RESULT%
