VLXD Bay Hai - FIX TAO SETUP WINDOWS 1.0.10
============================================

Nguon loi: file vlxd_app.exe co the giu thoi gian cu khi Dart code duoc build lai.
Ban fix se build Windows Release truc tiep, kiem tra data\app.so va nguon Dart,
roi moi goi Inno Setup. Khong can chay lai ban va 01 hoac 02.

CACH DUNG POWERSHELL 5.1:
cd D:\app\vlxd_app
$zip = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_FIX_Setup_1_0_10_Kiem_Tra_AppSO.zip"
$folder = "D:\app\vlxd_app\.low_stock_spacing_patch"
Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\05_TAO_SETUP_WINDOWS.ps1"

NEU [SUCCESS] XUAT HIEN:
D:\app\vlxd_app\release\installers\VLXD_Bay_Hai_Setup_1.0.10.exe

Luu y: Dong phan mem VLXD Bay Hai truoc khi tao Setup / cai dat.
Kiem tra giao dich offline da dong bo hoac sao luu truoc khi nang cap.
KHONG go cai dat cu, KHONG xoa SQLite, KHONG xoa du lieu.
Script chi thay file 05, khong thay nguon Dart.
