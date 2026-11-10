# VLXD Bảy Hải — vá xác nhận in sau chốt đơn (v1)

## Đã làm
- Sau khi checkout trả về đơn **Đã bán** và lưu thành công, hỏi **In phiếu / Không in**.
- In sử dụng `Printing.layoutPdf` + `PrintService.invoicePdf` đang có.
- Đơn **Giữ hàng** tiếp tục hiển thị chi tiết, không in hóa đơn đã bán.
- Nếu lỗi in, đơn vẫn được lưu, người dùng có thể in lại tại Hóa đơn đã bán.
- Không thay đổi Outbox, Firebase, tồn kho, công nợ, database hoặc mã đơn.

## Chưa làm — quan trọng với bàn giao khách mới
- Không xóa hóa đơn/demo/deliveries/tồn kho cũ trên Firebase; không xóa dữ liệu cục bộ.
- Cửa hàng mới trống chỉ khi trỏ tới **dữ liệu cửa hàng mới được phân quyền riêng**, hoặc Firebase project riêng; bản hiện tại mặc định dùng `stores/bay-hai` trên Firebase `vlxd-bay-hai`.
- Nếu tiếp tục dùng cùng Firebase/store, dữ liệu thử cũ vẫn hiện. Không giao khách bản này trước khi hoàn tất phân lập cửa hàng, bảo mật Firestore, đăng nhập và QA.
- Cơ chế in mở hộp thoại in của hệ điều hành, **chưa tự chọn máy KV804**. Nếu cần in nhiệt 80mm, phải thêm cấu hình khổ giấy riêng.

## Cài (PowerShell)
1. Đóng ứng dụng. Sao lưu code trước khi chép.
2. Chạy tại `D:\app\vlxd_app`:
   `Copy-Item .\lib\ui\sales.dart .\lib\ui\sales.dart.before_print_patch -Force`
3. Giải nén ZIP ở gốc dự án, chép đè đúng `lib/ui/sales.dart`.
4. `dart format .\lib\ui\sales.dart`
5. `flutter analyze --no-fatal-infos`
6. `flutter test`
7. Chỉ build production nếu đã duyệt hàng đợi và cấu hình an toàn. Có thể kiểm tra giao diện trước qua `flutter run -d windows --dart-define=DEMO_MODE=true` (không dùng Firebase thật).

Lưu ý ZIP này được sửa từ `VLXD_Source_Print_Feature.zip` do người dùng gửi, chưa được chạy trên Windows Flutter SDK thực tế trong môi trường tạo bản vá.
