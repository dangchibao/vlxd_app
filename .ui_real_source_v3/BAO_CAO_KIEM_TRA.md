# Rà soát VLXD Bay Hai — bản cập nhật theo mã nguồn UI thực tế

**Nguồn nhận ngày 21/11/2026:** `.vlxd_ui_source_for_review_20261121_000225.zip`, gồm chính xác 6 file: `app.dart`, `catalog.dart`, `debt.dart`, `mobile_products.dart`, `operations.dart`, `vlxd_theme.dart`.

## Vì sao hai bản trước lỗi

`catalog.dart` hiện tại viết trường `secondary`, `ratio`, `newPrice` thành lời gọi `field(...)` có nhiều dòng và dấu phẩy cuối. Biểu thức tìm/thay trước đó dùng dấu nháy/kiểu xuống dòng khác nên không khớp, dù code vẫn hợp lệ. Phiên bản này **không chạy regex để sửa file trong PowerShell**: đã xây dựng 6 file UI đầu ra từ chính source ZIP trên, rồi kiểm tra SHA256 trước khi thay file.

## Thay đổi trong ZIP

1. `lib/ui/app.dart` — Form label floats only when focused/filled; less label overlap
2. `lib/ui/catalog.dart` — Add correction-specific compact input with separate label
3. `lib/ui/catalog.dart` — Correction main unit field no overlay
4. `lib/ui/catalog.dart` — Correction secondary unit field no overlay (multiline match)
5. `lib/ui/catalog.dart` — Correction conversion factor field no overlay
6. `lib/ui/catalog.dart` — Correction new price field no overlay
7. `lib/ui/catalog.dart` — Reason appears above text field; 3-word rule unchanged
8. `lib/ui/catalog.dart` — Lot quantity 0 label outside input
9. `lib/ui/catalog.dart` — Correction dialog responsive width and keyboard height
10. `lib/ui/catalog.dart` — Confirmation checkbox leading and compact
11. `lib/ui/mobile_products.dart` — Smaller product image on phone
12. `lib/ui/mobile_products.dart` — Condense mobile product card cost/note into Details
13. `lib/ui/mobile_products.dart` — Mobile detail dialog for price/cost/note/conversion
14. `lib/ui/mobile_products.dart` — Mobile menu handlers for detail & admin-only correction
15. `lib/ui/mobile_products.dart` — Mobile popup retains detailed info and admin correction
16. `lib/ui/operations.dart` — Responsive warehouse breakpoint
17. `lib/ui/operations.dart` — Hide redundant warehouse introduction on phones
18. `lib/ui/operations.dart` — Warehouse mobile receive action uses compact icon
19. `lib/ui/operations.dart` — Warehouse mobile inspection action uses compact icon
20. `lib/ui/operations.dart` — Collapse warehouse movement history on phone only
21. `lib/ui/debt.dart` — Customer debts list on narrow phone; full 6-column table desktop
22. `lib/ui/vlxd_theme.dart` — Narrow dialog margins for phone; desktop retains max constraints

## Chức năng được giữ

- Bút chì xanh, phiếu có tick cam, máy in xanh ngọc, biểu tượng cấm đỏ từ bộ icon V4.
- Mã vạch & In (Code128), in phiếu, sửa thông tin sản phẩm, điều chỉnh đơn vị có quyền Admin, bán hàng, nhập/kiểm kê/ẩn lô.
- Công nợ: chọn khách để xem chi tiết, sửa/xóa khách, lưu chứng từ; trên desktop bảng vẫn có đủ 6 cột.
- Giá vốn, nhà cung cấp, ghi chú không xóa dữ liệu; mobile chỉ ẩn bớt trên thẻ, mở chi tiết khi cần.
- Không thay đổi `lib/domain/`, `lib/controllers/`, `lib/data/`, Firebase config, Firestore Rules, SQLite, code in hoặc outbox.

## Các giới hạn và kiểm thử bắt buộc

- Môi trường tạo ZIP **không có Flutter SDK**, vì vậy chưa thể xác nhận `dart format`, `flutter analyze`, `flutter test` hoặc trải nghiệm thật. Script máy Windows sẽ thực hiện; thất bại thì tự hoàn nguyên.
- Thử màn 320, 390, 430 px, hiển thị bàn phím, bảng Công nợ; desktop 1366 px; phóng to font; thử click các icon V4, in và xem menu sản phẩm.
- Chỉ 6 file UI đã được cung cấp để chỉnh. Các màn như Bán hàng, Giao hàng, Kế toán, Hóa đơn nằm ở những file UI KHÁC và chưa có mã nguồn cập nhật trong ZIP này. Không thể xác nhận đã kiểm tra/sửa toàn bộ các màn đó. Cần đánh giá tiếp sau khi patch hiện tại chạy ổn định.
- Khi sửa unit của GM4 tồn 0, điều kiện kiểm tra chứng từ lịch sử vẫn là nghiệp vụ domain và **không bị nới lỏng bởi ZIP này**.
