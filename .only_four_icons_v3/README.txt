VLXD BAY HAI - FOUR ICONS ONLY (NO TEXT BUTTONS) - V3

SCOPE: Only lib/ui/catalog.dart, the action strip of each product in HANG HOA.
The same actions widget is used in both the narrow and wide product card.

Exact icons from the screenshot:
* Blue pencil: edit product (Icons.edit_outlined, #1976D2).
* Orange clipboard-check: unit correction (Icons.assignment_turned_in_outlined, #D97706), Admin only.
* Teal printer: barcode/print (Icons.print_outlined, #0D9488).
* Red prohibition symbol: archive item (Icons.block_outlined, #DC2626).

Each action uses the original IconButton: NO visible labels, NO wide button,
NO background pill; tooltip on mouse hover. Print and permission handlers unchanged.
The barcode dialog, Code128, print action, unit correction dialog, Firestore,
SQLite and historical data are untouched.

INSTALL (PowerShell 5.1):
cd D:pplxd_app
$zip = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_Chi_4_Icon_Gon_Gang_V3.zip"
$folder = "D:pplxd_app\.only_four_icons_v3"
Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder_CHI_THAY_4_ICON.ps1"

After successful tests, rebuild using 02_BUILD_WINDOWS.ps1 or 03_BUILD_WEB_PWA.ps1.
Building Web does NOT deploy hosting. Deploy ONLY after verifying the build.
Automatic backup path: .vlxd_safe_backups\icons_only_v3_<timestamp>\catalog.dart
If format, analyze, or tests fail, source is restored. Does not uninstall software.
