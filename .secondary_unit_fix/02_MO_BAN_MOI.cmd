@echo off
setlocal
set "EXE=D:\app\vlxd_app\build\windows\x64\runner\Release\vlxd_app.exe"
if not exist "%EXE%" (
  echo [LOI] Chua co EXE Release. Hay chay 01_KHOI_PHUC_DON_VI_PHU.cmd.
  pause
  exit /b 1
)
start "" "%EXE%"
