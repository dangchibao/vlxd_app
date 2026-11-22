VLXD BAY HAI - MA VACH & IN - FIX PS 5.1 / VERSION 2

The first package failed with: Unexpected source layout for unit correction confirmation button (0 matches).
This replacement ONLY updates the barcode and print UI. It DOES NOT try to change the unit-correction confirmation button.

Changes:
- Desktop barcode: replace QR-like icon with a teal "Ma vach & In" button.
- Barcode dialog: rename title to "Ma vach & In tem".
- Print button: teal "In tem ma vach".
- Mobile product popup: "Ma vach & In" with a teal printer icon.
- PrintService.barcode(p), Code128, barcode SKU, unit correction buttons, stock and Firestore unchanged.

Install (extract ZIP first, then run PowerShell; do NOT run directly inside ZIP):
cd D:\app\vlxd_app
$zip = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_Ma_Vach_In_FIX_V2_PS51.zip"
$folder = "D:\app\vlxd_app\.barcode_print_fix_v2"
Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\01_SUA_MA_VACH_VA_IN_PS51.ps1"

After Analyze/Test pass, to build Windows:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\02_BUILD_WINDOWS.ps1"
To build Web/PWA:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\03_BUILD_WEB_PWA.ps1"

This package does not create Setup, does not deploy Firebase Hosting, and does not clean project or app data.
If tests fail, catalog.dart and mobile_products.dart are restored from a timestamped backup automatically.
