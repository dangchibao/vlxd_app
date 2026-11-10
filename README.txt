VLXD BẢY HẢI - BẢN VÁ HÓA ĐƠN TRẮNG ĐEN V6

Chỉ thay lib/ui/print_service.dart, dựa trên file từ ZIP mã nguồn người dùng đã cung cấp và bản vá hóa đơn v3.

- Chỉ chữ, không logo / biểu tượng gây lỗi font.
- Địa chỉ: Ấp Bàu Vừng, Xã Phước Trạch, Huyện Gò Dầu, Tỉnh Tây Ninh.
- SĐT: 0343 744 091.
- Khung khách hàng dài ngang tới khổ nội dung giấy, ba dòng Khách hàng / Địa chỉ / ĐT.
- Giữ 5 cột STT, Tên hàng hóa, SL, Đơn giá, Thành tiền.
- Chừa 76pt giữa bảng và tổng tiền để viết tay.
- Luôn có ba dòng Tổng tiền hàng / Giảm giá / Phí vận chuyển; cuối là Tổng thanh toán.
- Loại bỏ Cảm ơn quý khách, không thêm chữ ký hoặc mã vạch.
- Dữ liệu động lấy từ đơn lưu, không dùng số của ảnh mẫu.
- Với đơn đang chờ đồng bộ, tiêu đề ghi PHIẾU TẠM - CHỜ ĐỒNG BỘ vì đây chưa phải hóa đơn đã bán xác nhận.
- Không thay đổi SQLite, Firebase, nghiệp vụ bán hàng.

Cài: sao lưu bản gốc bên ngoài thư mục dự án, sau đó giải nén vào gốc dự án.
Kiểm thử: dart format lib/ui/print_service.dart; flutter analyze --no-fatal-infos; flutter test.
Phải xem trước và in thử (A4 và máy KV804 nếu sử dụng).
Chưa chạy Flutter trong môi trường tạo patch, không bảo đảm 100% khớp ảnh trên mọi máy in / trình xem PDF.
