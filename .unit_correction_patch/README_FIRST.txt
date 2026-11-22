VLXD Bay Hai - ADMIN CORRECTION OF WRONG BASE UNIT AFTER RECEIVING

This source patch is based ONLY on the uploaded 467-file review ZIP dated 2026-11-20.
It does not overwrite Firestore data or install/uninstall Windows applications.
Patch does not require changing Firestore Rules.

HOW TO INSTALL (DO NOT DOUBLE CLICK WITHIN ZIP):
  1. Extract all files to D:\app\vlxd_app\.unit_correction_patch
  2. Open PowerShell and run:
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\app\vlxd_app\.unit_correction_patch\01_CAI_VA_KIEM_THU.ps1"
  3. Source SHA256 checks must match the uploaded review ZIP.
     If it says SOURCE CHANGED, stop. Do not force overwrite newer source.
  4. On analyzer/test failure, script restores previous code from local backups.
  5. Only after tests pass, optionally run 02_BUILD_WINDOWS.ps1 or 03_BUILD_WEB_PWA.ps1.

IN THE APP (DESKTOP-WIDTH CATALOG):
  - Admin > Hang hoa > chosen product > edit_note icon next to Edit.
  - Enter corrected BASE UNIT, secondary unit and units per secondary.
  - Enter correct existing physical stock for EACH LOT in new base unit.
  - Enter selling price in NEW base unit and detailed reason.
  - Check all other devices fully synced, confirm, save ONLINE.

STRICT CONDITIONS:
  - Owner/Admin only. One-time correction when all lots are original untouched receipts.
  - Not available after sale, delivery, reservation, stock count/adjustment,
    any other stock movement, or if local unresolved offline operations remain.
  - Cross-device pending offline operations cannot be checked by this app: verify manually.
  - Original receipt history is immutable. New stock movement and audit record added.
  - Preserve each lot's original total purchase cost (nearest VND rounding).
  - Stock warning threshold is reset to 0 because the unit changed.
  - If a receipt was itself wrong in value/cost, use an accounting correction,
    not just this unit correction function.
  - This is NOT a general unit conversion for products with sales history.

IMPORTANT:
  - Code changes have NOT been executed with Flutter in the assistant environment.
  - Do not deploy web/build before flutter analyze and all tests pass on Windows.
  - Review result with stock/cost reports on a test/staging store before applying to live data.
  - Backup server data and confirm the current store and account before live use.
