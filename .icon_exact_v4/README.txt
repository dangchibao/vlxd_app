VLXD Bay Hai - DUNG 4 ICON TRONG ANH - V4 (PowerShell 5.1)

CHINH XAC YEU CAU (chi icon, KHONG chu, KHONG vien, KHONG doi layout):
  [BLUE] PEN/PENCIL - sua san pham
  [ORANGE] CLIPBOARD + CHECK - dinh chinh don vi
  [TEAL] PRINTER - Ma vach & In, KHONG QR
  [RED] BAN circle/slash - ngung kinh doanh

V4 dung CustomPainter trong Flutter de ve 4 hinh vector nhu anh mau,
KHONG dua vao cac glyph Material co the khac hinh, KHONG them package.
IconButton, tooltips, handlers, quyen Admin giu nguyen.
Chi thay lib/ui/catalog.dart; script tao backup va rollback khi test fail.

CAC BUOC (moi command chay trong PowerShell 5.1):
  cd D:pplxd_app
  $z = "$env:USERPROFILE\Downloads\VLXD_Bay_Hai_Icon_Dung_Anh_Mau_V4.zip"
  $p = 'D:pplxd_app\.icon_exact_v4'
  Expand-Archive -LiteralPath $z -DestinationPath $p -Force
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p_ICON_DUNG_ANH_MAU_PS51.ps1"

SAU KHI TEST PASS:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p_BUILD_WEB_V4.ps1"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p_DEPLOY_PREVIEW_V4.ps1"
  # Kiem tra link preview; sau do LIVE neu dung:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p_DEPLOY_LIVE_V4.ps1"

WINDOWS (neu can):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p_BUILD_WINDOWS_V4.ps1"

CANH BAO: Flutter build Web KHONG tu deploy Firebase Hosting!
V3 truoc do chi build nen trang web live van co the hien 4 icon cu.
Khong xoa cache Offline/PWA neu con giao dich chua dong bo.
Script 05 can nguoi dung go DANG truoc khi dang live.
