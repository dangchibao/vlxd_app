VLXD BAY HAI - UI AUDIT & RESPONSIVE SAFETY PATCH (Desktop + Phone)
===============================================================

This package is designed for the local Windows project at D:\app\vlxd_app.
It is NOT a full replacement source tree. No .exe is embedded.

INCLUDED
- 22 carefully-scoped source replacements in 6 UI-only Dart files
- UI audit report; smoke regression tests at widths 320, 390, 430px
- Conservative PowerShell 5.1 installation with preflight (all replacement matches must be unique)
- Automatic source backup and rollback if dart format/analyze/test fails
- Build Windows, Web/PWA, optional 1.0.9 Inno Setup installer and Preview/Live deployment scripts

NO DATA CHANGES
Does not change business/domain/controllers/data, invoices, stock values,
local SQLite, Firestore, Firestore rules, offline outbox, or credentials.
Existing billing/printing and the exact V4 icon design are preserved.

INSTALL ONLY AFTER YOU HAVE CONFIRMED BACKUP/SYNC OF ANY OFFLINE WORK:
  cd D:\app\vlxd_app
  $zip = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_UI_Tong_The_Desktop_Mobile_Audit.zip"
  $folder = "D:\app\vlxd_app\.ui_desktop_mobile_audit"
  Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\01_KIEM_TRA_VA_SUA_UI_PS51.ps1"

AFTER SUCCESS (not before):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\02_BUILD_WINDOWS.ps1"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\03_BUILD_WEB_PWA.ps1"

OPTIONAL SETUP (Inno Setup is expected at D:\Inno Setup 6\ISCC.exe):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\04_TAO_SETUP_WINDOWS_1_0_9.ps1" -BuildOnly
  # Remove -BuildOnly if you intentionally want to open the setup wizard.

OPTIONAL PREVIEW FIRST (DO NOT deploy live without phone/desktop checking):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\05_DEPLOY_WEB_PREVIEW.ps1"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\06_DEPLOY_WEB_LIVE.ps1"

IMPORTANT:
- A Flutter build does not update the installed app or the live website on its own.
- Do NOT uninstall previous versions or clear browser/site data with unsynced work.
- Test the form, warehouse, checkout, barcode print, accounts, and offline sync
  separately on real devices. Unit/widget tests cannot prove visual perfection.
- If the installer reports an unsupported source structure, send the error and
  a fresh source ZIP. Do not force-replace files or delete backups.
