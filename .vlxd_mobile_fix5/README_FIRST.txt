VLXD App Mobile UI - sua 5 loi trong test 2026-11-18

Pham vi: KHONG thay doi domain/ShopData, Firebase Rules, repository, Outbox.
Khong build/deploy/push. Ban nay sua 4 file:
- lib/ui/sales.dart: hien so nguyen 2 thay vi 2.0 trong hop thoai them gio
- lib/ui/mobile_products.dart: thay 3 nut ngang sang menu 3 cham, khong tran 320px, giu edit/barcode/archive/restore
- lib/ui/invoices.dart: hien so tien con no rieng tren the hoa don mobile
- test/product_notes_test.dart: dung dung nut add-to-cart mobile bang ValueKey, giu kiem thu luu y/so luong

Cach cai (PowerShell):
cd D:\app\vlxd_app
$zip = "$env:USERPROFILE\Downloads\VLXD_Mobile_UI_Fix_5_Loi_20261118.zip"
Expand-Archive -LiteralPath $zip -DestinationPath .\.vlxd_mobile_fix5 -Force
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\.vlxd_mobile_fix5\fix-mobile-tests-safe.ps1 -ProjectPath D:\app\vlxd_app

dart format lib/ui/sales.dart lib/ui/mobile_products.dart lib/ui/invoices.dart test/product_notes_test.dart
flutter analyze --no-pub
flutter test --no-pub test/mobile_responsive_sales_test.dart test/invoices_test.dart test/product_notes_test.dart test/widget_test.dart
flutter test --no-pub

Luu y: script xem cac doan code hien tai co khop mau khong, neu khong thi DUNG truoc khi ghi de.
Co backup trong .vlxd_patch_backups\Mobile_Fix5_... Duong dan in ra khi cai.
May tao ZIP khong co Flutter SDK nen chua the xac nhan test chay dat tren Windows.
