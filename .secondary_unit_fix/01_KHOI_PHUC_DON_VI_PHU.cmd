@echo off
setlocal
if not exist "%~dp0fix-and-build.ps1" (
  echo [LOI] Hay GIAI NEN tat ca file ZIP truoc, KHONG chay CMD truc tiep trong ZIP.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix-and-build.ps1" -Project "D:\app\vlxd_app"
if errorlevel 1 (
  echo [LOI] Ban va chua hoan tat. Xem dong FAILED phia tren.
  pause
  exit /b 1
)
echo [OK] Da hoan tat. Mo bang shortcut VLXD Bay Hai - BAN MOI tren Desktop.
pause
