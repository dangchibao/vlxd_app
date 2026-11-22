@echo off
setlocal
if not exist "%~dp0build-web-pwa.ps1" (
  echo [ERROR] Giai nen TOAN BO ZIP truoc khi chay, khong chay truc tiep trong ZIP.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-web-pwa.ps1" -ProjectRoot "D:\app\vlxd_app"
if errorlevel 1 (
  echo [FAILED] Khong hoan tat build Web/PWA. Xem loi phia tren.
  pause
  exit /b 1
)
echo [OK] Da build Web/PWA tai D:\app\vlxd_app\build\web
pause
