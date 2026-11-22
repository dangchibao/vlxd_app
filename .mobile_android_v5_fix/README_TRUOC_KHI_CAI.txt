VLXD Bay Hai — Mobile Web/PWA UI V4

Ap dung CHI 2 file: lib/ui/mobile_products.dart, lib/ui/debt.dart.
Ban va co 15 thay doi giao dien; khong sua logic, Firebase, SQLite, kho, ban hang, in, quyen Admin.

CD D:\app\vlxd_app
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<folder>\01_CAI_UI_MOBILE_PS51.ps1"

Script check 15 anchors BEFORE writing anything, backup, dart format, flutter analyze, flutter test, auto rollback if fail.
NEU SOURCE-MISMATCH thi DUNG; khong force hay overwrite.

Khi test pass: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<folder>\02_BUILD_VA_XEM_TRUOC.ps1"
Bước 02 build Web PWA qua script da co va deploy PREVIEW; khong publish LIVE.
DANG LIVE chi khi preview da duoc kiem tra tren phone, login/offline/sync.
