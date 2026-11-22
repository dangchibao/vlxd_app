VLXD BAY HAI — UI PATCH THEO DUNG 6 FILE MA NGUON BAN VUA GUI (V3)
=========================================================================
Source ZIP: .vlxd_ui_source_for_review_20261121_000225.zip

1) Giai nen ZIP vao: D:\app\vlxd_app\.ui_real_source_v3
2) Chay PowerShell 5.1:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\app\vlxd_app\.ui_real_source_v3\01_CAI_VA_KIEM_THU_PS51.ps1"

Script kiem tra SHA256 CUA 6 FILE HIEN TAI truoc khi sua. Neu mot file khong khop: KHONG SUA GI.
Neu khop: sao luu 6 file vao .vlxd_safe_backups, copy 6 file UI, chay dart format, flutter analyze --no-pub, flutter test --no-pub.
Neu bat ky test fail: sao luu duoc khoi phuc tu dong, test moi bi xoa.
KHONG tu trien khai Firebase, KHONG xoa SQLite/outbox hay thay doi logic domain.

SAU KHI TEST DAT:
  02_BUILD_WINDOWS.ps1     (chi build exe, khong cai)
  03_BUILD_WEB_PWA.ps1     (dung script offline-manifest cu neu co)
  04_DEPLOY_PREVIEW.ps1   (chi xem truoc, KHONG dang web chinh thuc)

Chi sau khi xem tren dien thoai va desktop dung y moi deploy production/cai setup.
Xem BAO_CAO_KIEM_TRA.md de biet chi tiet va gioi han.
