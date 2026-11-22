VLXD — Nâng cấp đơn vị chính + đơn vị phụ (Beta, 2026-11-20)
=================================================================

YÊU CẦU: Đã cài bản ReviewUnits Beta 13 file từ VLXD_Source_Review.zip.
Nếu bản vá báo file đã thay đổi thì DỪNG; không ép ghi đè. Gửi thông báo lỗi và ZIP mới nhất.

CÁC THAY ĐỔI
- Mỗi sản phẩm có đơn vị chính (tồn kho và giá vốn) và đơn vị phụ tùy chọn.
- 1 đơn vị phụ = X đơn vị chính, hoặc bật "Nhập quy đổi chiều ngược" để nhập 1 đơn vị chính = X đơn vị phụ.
- Ví dụ sản phẩm Keo dán gạch 25 kg đang tính theo BAO, chọn đơn vị phụ KG,
  bật chiều ngược, nhập 25. Hệ số lưu là 1 kg = 0.04 bao; tồn kho vẫn tính theo bao.
- Theo cái/thùng, viên/hộp, kg/bao, m³/xe hoặc các cặp khác.
- Màn hình nhập Kho và Bán hàng chọn theo đơn vị đã khai báo.
- Hóa đơn mới giữ đơn vị tại thời điểm bán; hóa đơn cũ không bị đổi.
- Đơn đang có lịch sử và đơn vị quy đổi cũ KHÔNG được sửa trực tiếp hệ số hoặc tên đơn vị phụ.
- Thêm quy đổi lần đầu cho sản phẩm đang bán nhưng chỉ dùng một đơn vị trước đây KHÔNG thay đổi lô hoặc hóa đơn cũ.
- Kiểm soát đơn vị trong giao dịch nhập kho offline (giữ khả năng đọc lệnh cũ).

CẢNH BÁO KHI TRIỂN KHAI THẬT
- Bản vá có firestore.rules cập nhật schema. Chỉ build code mà KHÔNG cập nhật
  Firestore Rules sẽ khiến lưu sản phẩm có đơn vị phụ bị chặn PERMISSION_DENIED.
- Firestore Rules phải được rà soát, test với Firebase Emulator và triển khai riêng,
  KHÔNG tự động deploy trong script cài.
- Phải đồng bộ, xử lý Outbox chờ và cập nhật Windows + Web/PWA cùng lúc.
  Máy chạy client cũ có thể KHÔNG ghi được sản phẩm có đơn vị phụ mới;
  rules ngăn việc client cũ xóa trường secondaryUnit khi ghi giao dịch.
- Không xóa SQLite, Outbox, localStorage, dữ liệu Firebase, không tự nâng gói packages.
- Đây là BETA: Chưa chạy flutter analyze/test bằng SDK trên môi trường tạo ZIP.
  Các bài test sau khi cài trên máy Windows của bạn là bắt buộc.

CÀI: powershell -NoProfile -ExecutionPolicy Bypass -File .\.vlxd_generic_units\install-safe.ps1 -ProjectPath D:\app\vlxd_app
KIỂM TRA: dart format lib/domain/shop.dart lib/controllers/shop_controller.dart lib/ui/catalog.dart lib/ui/sales.dart lib/ui/operations.dart lib/ui/print_service.dart lib/ui/audit_text.dart lib/data/sync/offline_book_operation.dart test/secondary_unit_upgrade_test.dart
          flutter analyze --no-pub
          flutter test --no-pub test/secondary_unit_upgrade_test.dart
          flutter test --no-pub
Không triển khai bản beta lên production cho tới khi test thành công và đối soát đơn offline.
