# Nhập khách ngay tại đơn bán

Trong Bán hàng → Đơn hàng mới, bấm **Thêm khách hàng mới** ngay dưới ô Khách hàng. Điền tên và số điện thoại (có thể để trống số điện thoại), rồi bấm Lưu.

Khách được lưu vào danh sách khách hàng chung. Sau khi lưu thành công, đơn hiện tại tự chọn tên khách vừa nhập; hàng trong giỏ và phí giao hàng được giữ. Khách cũng xuất hiện trong danh sách chọn để dùng lại lần sau và ở Công nợ, kể cả khi đã thanh toán đủ.

Chốt đơn khi tên khách đã được chọn sẽ lưu mã khách vào đơn bán. Chi tiết hóa đơn/PDF dùng khách của đơn đó; bỏ trống Tiền đã thu vẫn có nghĩa thanh toán đủ. Nếu không cần ghi tên, vẫn chọn được Khách lẻ • thanh toán đủ.

Bấm Hủy hoặc lưu bị lỗi sẽ không tạo/chọn khách chưa lưu. Dùng chung luồng lưu khách hiện có và Firestore hiện tại, không đổi Rules hoặc tự thêm dữ liệu thật khi phát triển.

Kiểm tra: flutter analyze không có vấn đề; 61 kiểm thử Flutter đạt. Ca mới kiểm tra tạo/chọn khách và chốt hóa đơn trả đủ ở chiều rộng 390 và 1700, giữ giỏ/phí giao hàng, hủy và lỗi lưu. Chưa build lại bản phát hành hoặc triển khai Hosting cho thay đổi giao diện này.
