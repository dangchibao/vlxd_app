@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-fresh.ps1" -ProjectRoot "%~dp0.."
if errorlevel 1 (
  echo.
  echo Tao bo cai KHONG thanh cong. Kiem tra thong bao loi phia tren.
) else (
  echo.
  echo Da tao bo cai. Xem thu muc release\installers trong du an.
)
pause
