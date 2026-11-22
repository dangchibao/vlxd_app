VLXD Bay Hai - Chinh khoang cach phia tren "Bao ton thap"

Muc tieu: de muc "Bao ton thap" khong dinh sat doan giai thich quy doi phia tren.
- Man hinh nho (<600px): 12px
- Man hinh lon (>=600px): 16px
- Chi them 01 SizedBox truoc field(minimum); khong sua nhan, business logic, Firebase, SQLite.

CAI DAT (Windows PowerShell 5.1):
 cd D:\app\vlxd_app
 $zip = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_Bao_Ton_Thap_Gian_Cach_UI.zip"
 $folder = 'D:\app\vlxd_app\.low_stock_spacing_patch'
 Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\01_SUA_KHOANG_CACH_VA_KIEM_THU_PS51.ps1"

Khi Flutter analyze va test PASS:
 - Build Windows: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\02_BUILD_WINDOWS.ps1"
 - Build Web/PWA & preview: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\03_BUILD_WEB_VA_PREVIEW.ps1"
 - Deploy LIVE sau khi xem preview: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\04_DEPLOY_WEB_LIVE.ps1"
 - Tao bo cai Windows (optional, sau khi build): powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$folder\05_TAO_SETUP_WINDOWS.ps1"

Bo cai Windows duoc luu tai release\installers. Script 05 chi tao EXE, KHONG tu dong cai.
Cai nang cap bang AppId hien co; KHONG go ban cu khi chua dong bo/backup offline data.

An toan: co backup catalog.dart duoi .vlxd_safe_backups, rollback neu analyze/test loi.
Neu source khac khong tim thay nhan, script dung "NO FILES CHANGED".
