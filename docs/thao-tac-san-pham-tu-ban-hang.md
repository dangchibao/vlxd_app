# Sửa sản phẩm ngay trên màn Bán hàng

Ngày 04/11/2026: thêm Tạo sản phẩm ở thanh công cụ, nút Sửa và Xóa trên từng thẻ. Dùng chung biểu mẫu/logic lưu với Hàng hóa; sửa được giá, tên, ảnh, quy đổi và các trường hiện có. Chủ và nhân viên bán hàng được thao tác theo quyền đã chốt.

Xóa có xác nhận, dùng ngừng kinh doanh (active=false), giữ nguyên sản phẩm, tồn và các hóa đơn cũ. Không xóa vật lý dữ liệu thật. Bị chặn nếu còn lượng giữ cho khách. Sau khi lưu ngừng bán thành công, loại dòng sản phẩm khỏi giỏ nháp trên thiết bị thao tác. Không thay tài khoản/Rules/dữ liệu thật khi phát triển tính năng này.

Đã sửa khung trang để tạo lại widget với key ổn định sau cập nhật controller: thẻ giá và danh sách cập nhật sau lưu/xóa, trạng thái của trang đang mở vẫn giữ. Kiểm thử thao tác bằng repository bộ nhớ xác nhận tạo, sửa giá, giữ tổng tiền hóa đơn cũ, hủy xác nhận xóa và ngừng bán thành công.
