VLXD BAY HAI - WINDOWS SETUP V4
================================
What this package does
- Checks that the exact V4 icon patch is present in D:\app\vlxd_app.
- Runs flutter analyze, flutter test, builds Windows Release.
- Creates a full Inno Setup installer under D:\app\vlxd_app\release\installers.
- Uses the ORIGINAL Inno AppId VLXD.App.Windows.Desktop to upgrade previous VLXD App.
- Opens the installer wizard (user completes it).
- Keeps existing SQLite/outbox/Firebase data; does NOT uninstall old app or reset the stores.
- Does not deploy the web app.

Run in Windows PowerShell 5.1:

cd D:\app\vlxd_app
$zip = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_Cai_Dat_Windows_V4.zip"
$folder = "D:\app\vlxd_app\.windows_setup_v4"
Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\01_BUILD_VA_CAI_DAT_WINDOWS_V4.ps1"

Expected setup:
D:\app\vlxd_app\release\installers\VLXD_Bay_Hai_Setup_1.0.8.exe

IMPORTANT
- Close the app before beginning. If unsynced offline transactions exist, reconcile/backup before upgrading.
- Do not delete %LOCALAPPDATA%, SQLite databases, outbox, or website data.
- This ZIP is NOT a compiled Windows setup (needs local Flutter + Inno Setup 6).
- Tested by static source checking only in this environment; your Windows build and install logs confirm success.
