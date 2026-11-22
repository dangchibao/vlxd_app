@echo off
setlocal
if not exist "%~dp0publish-web.ps1" (
  echo [ERROR] Giai nen TOAN BO ZIP truoc khi chay.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish-web.ps1" -ProjectRoot "D:\app\vlxd_app" -Mode preview
if errorlevel 1 (
  echo [FAILED] Xem thong bao phia tren.
  pause
  exit /b 1
)
pause
