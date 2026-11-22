BAN FIX PS 5.1: sua ParserError o dong thay khung Dashboard.
Loi cu xay ra TRUOC khi bat dau chinh sua code.
Thuc hien giai nen toan bo ZIP moi (khong chay truc tiep trong ZIP).

VLXD Bay Hai - Khôi phục kho tồn 0 / tìm kiếm / mã lô / dashboard

1) Dùng PowerShell, KHÔNG nhấp CMD bên trong ZIP.
2) Giai nen TOAN BO vao D:\app\vlxd_app\.patch_kho_ton0_timkiem
3) Dong VLXD Bay Hai Windows (neu dang mo), luu nhap lieu.
4) Chay PowerShell:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\app\vlxd_app\.patch_kho_ton0_timkiem\01_CAI_VA_KIEM_THU.ps1"

Noi dung:
- Chi nhan ly do dinh chinh >= 3 TU (thay cho >=10 ky tu).
- Admin co the doi don vi cho san pham CO LO nhung TAT CA LO TON 0, KHONG co don ban/giao/giu va khong co giao dich kho bat thuong; luu audit, KHONG cong ton.
- Van chan khi co don ban, giao hang, giu hang, nhap/xuat kho phuc tap, outbox chua dong bo.
- Ma lo ngan de doc, nut copy toan bo UUID; khong doi ID that.
- Khu vuc So luong theo lo khong de dai UUID de len nhan TextField.
- Them tim kiem trong Kho theo ma, ten, quy cach, NCC, ma lo.
- Thay 'Viec can chu y' bang 'Cong viec dang mo' (don giu, chuyen dang giao, cong no + loi tat).
- Backup vao .vlxd_safe_backups; tu khoi phuc file neu Flutter analyze/test khong dat.
- Khong deploy Firebase va khong xoa du lieu SQLite.

Sau khi KIEM THU DAT:
- 02_BUILD_WINDOWS.ps1 de build Windows Release
- 03_BUILD_WEB_PWA.ps1 de build Web/PWA tu code moi
- KHONG deploy Web len du lieu that neu chua test du tren moi truong mau.

Chu y: ket qua 0 ton khong co nghia la lich su chung tu da duoc xac nhan. Tuyet doi khong bo qua cac dieu kien chong sua sai ton kho.
