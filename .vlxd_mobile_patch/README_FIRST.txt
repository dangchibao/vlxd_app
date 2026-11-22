VLXD APP - MOBILE UI (Android APK, iPhone Safari Web/PWA)
Ban va UI: 18/11/2026. Nguon: GitHub dangchibao/vlxd_app main + patch Hang Hoa V2.

NOI DUNG:
- Ban hang tren man hinh <600px: 6 icon mot hang, tim + quet ma, loc danh muc goi y.
- Danh sach san pham nho gon: anh, ma, quy cach, ton, gia, tang/giam so luong.
- Nut Them goi lai confirmProduct dang dung (khong chot don truc tiep), co menu Sua/Ngung kinh doanh.
- Gio hang co dinh o duoi danh sach, mo CartPanel hien tai.
- Hang hoa: tim, loc thu gon trong sheet, giu quan ly/ma vach/nhap kho/khoi phuc.
- Hoa don: mobile list cards va bo loc an/hien; vao chi tiet va in nhu cu.
- Tong quan: mobile 2 cot khi du rong; trang danh sach phan trang gon; title gon.
- Desktop Windows, Web man hinh >=600: de nguyen luong giao dien truoc.
- KHONG thay doi Domain, Firebase Auth/Rules, Outbox, SQLite, so tien/ton, invoice, local data.

CAI BAN VA: Giai nen ZIP vao D:\app\vlxd_app\.vlxd_mobile_patch
cd D:\app\vlxd_app
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\.vlxd_mobile_patch\install-safe.ps1' -ProjectPath 'D:\app\vlxd_app'

KIEM TRA TREN MAY CO FLUTTER:
dart format lib/ui/app.dart lib/ui/sales.dart lib/ui/mobile_sales.dart lib/ui/mobile_products.dart lib/ui/catalog.dart lib/ui/shell.dart lib/ui/pagination.dart lib/ui/invoices.dart lib/ui/history.dart test/mobile_responsive_sales_test.dart
flutter analyze --no-pub
flutter test --no-pub test/mobile_responsive_sales_test.dart
flutter test --no-pub

BUILD ANDROID (sau khi test dat):
flutter build apk --release --no-pub
APK: build\app\outputs\flutter-apk\app-release.apk

BUILD iPhone Safari Web/PWA (khong phai native IPA):
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tools\build-web-offline.ps1'
Kiem tra build\web\offline-manifest.js, service worker va cac giao dich dang cho.
Chi khi ban san sang cap nhat web moi: firebase.cmd deploy --only hosting --project vlxd-bay-hai
Tren iPhone: Safari > Chia se > Them vao man hinh chinh.
IPA native iOS can macOS/Xcode, khong build duoc tren Windows.

AN TOAN:
- Trinh cai kiem tra SHA256 cua code goc (bo qua CRLF/LF), backup, khong ghi de file khac.
- Neu code tren may da khac, chay collect-current-for-merge.ps1 va gui ZIP sinh ra.
- Co script restore-backup.ps1, yeu cau cung cap duong dan backup duoc in sau khi cai.
- Khong tu deploy, khong push, khong reset du lieu.

KIEM THU:
Chua chay Flutter/Dart analyzer, widget tests, Android build, iPhone Safari test trong
moi truong tao patch (khong co SDK); phai chay tren Windows cua ban truoc khi phat hanh.
