VLXD BAY HAI - MA VACH & IN / GIAO DIEN NUT (2026-11-20)

MUC TIEU:
- But chi xanh: Chi tiet va sua san pham (giữ chức năng cũ)
- Phieu kiem tra cam: Dinh chinh don vi (Admin)
- May in xanh ngoc + nhan "Ma vach & In": Mo xem truoc Code 128 va in tem
- Cam do: Ngung kinh doanh (giữ chức năng cũ)
- Tren di dong, menu "Ma vach & In" co bieu tuong may in mau xanh ngoc.
- Trong hop thoai in, nut "In tem ma vach" mau xanh ngoc.

KHONG DOI: ma SKU, noidung Code128, PrintService.barcode(p), quan ly kho,
Firestore Rules, SQLite, hoa don, dong bo, ma lo.

CAI DAT (Windows PowerShell 5.1):
1. Tai ZIP va dat trong Downloads.
2. GIAI NEN toan bo ZIP bang PowerShell (khong nhap dup file trong ZIP):
   cd D:\app\vlxd_app
   $zip = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_Ma_Vach_Va_In_Mau_Xanh_Ngoc.zip"
   $folder = "D:\app\vlxd_app\.barcode_print_visual_fix"
   Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
3. Dong tat ca cua so VLXD Bay Hai Windows, sau do:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\01_CAP_NHAT_ICON_MAU_VA_IN.ps1"
4. Neu 'All tests passed!', build Windows:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\02_BUILD_WINDOWS.ps1"
   Hoac build Web/PWA:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\03_BUILD_WEB_PWA.ps1"

AN TOAN: script sao luu catalog.dart va mobile_products.dart tu dong truoc khi
chinh. Neu flutter analyze/test that bai, 2 file duoc phuc hoi. Thong bao duong
dan BACKUP tren PowerShell. Khong tu deploy Web hay go bo/cai dat Windows.
Sau khi build Windows, mo EXE Release/shortcut BAN MOI (khong phai app cu).
Sau khi build Web, kiem tra ban preview tren Firebase Hosting truoc khi deploy chinh thuc.
