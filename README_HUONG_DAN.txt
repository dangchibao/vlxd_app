VLXD BẢY HẢI — SỬA NHÃN LÔ TRONG KIỂM KÊ / ẢNH KHO

Mục tiêu: khi bấm "Kiểm kê / ảnh kho" rồi chọn Lô hàng, nhãn hiển thị
thành "Lô 001", "Lô 002" ... giống khu vực Kho thay cho LO-<UUID>.

Dữ liệu: không đổi ID, không chỉnh số lượng, không đổi logic kiểm kê,
không tự kết nối, ghi, hay xóa Firebase.

CÀI:
1. Đóng chương trình VLXD đang chạy.
2. Đặt ZIP tại D:\app\vlxd_app.
3. Mở PowerShell rồi chạy:
   cd D:\app\vlxd_app
   Expand-Archive -Path '.\VLXD_Bay_Hai_Kiem_Ke_Chon_Lo_Ngan_Gon_v1.zip' -DestinationPath '.' -Force
   node .\tools\fix-kiem-ke-ma-lo.cjs
   dart format .\lib\ui\operations.dart
   flutter analyze --no-fatal-infos
   flutter test
4. Chạy thử: flutter run -d windows --dart-define=DEMO_MODE=true

Script tự tạo backup ở D:\VLXD_Backup, nếu chạy từ Windows.
Nếu chưa có hàm _inventoryLotLabel từ bản Kho v2 hoặc cấu trúc code khác,
script dừng an toàn và KHÔNG sửa file.

Lưu ý: ZIP chỉ chứa script sửa phần giao diện trên CODE MỚI NHẤT CỦA BẠN,
không chép đè toàn bộ operations.dart từ bản cũ. Phải build lại Windows
hoặc Web để phiên bản phát hành hiển thị thay đổi.
