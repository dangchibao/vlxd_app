# Bổ sung thiết kế VLXD Bảy Hải

- Chi tiết sản phẩm: chỉnh ngày nhập theo lô, hệ số thùng sang m², thêm/sửa/xóa lô và lưu thay đổi; không tự sửa lịch sử chứng từ khi đổi hệ số.
- Danh sách hàng hóa: chọn sản phẩm cạnh ô tìm mã/tên gạch, thêm/sửa/xóa sản phẩm. Sản phẩm đã có giao dịch cần ngừng kinh doanh hoặc xử lý chứng từ thay vì xóa mất lịch sử.
- Mã vạch: tự tạo mã duy nhất, in mã, in thử, chọn số bản, máy in và khổ giấy; quét bằng đầu đọc hoặc camera. Mã vạch trong ảnh là minh họa, không dùng làm mã thật. Chưa xác định được model máy in từ ảnh người dùng; cần kiểm tra driver, khổ giấy, giao thức và khả năng dùng giấy tem. Không mặc định in USB trực tiếp được từ mọi nền tảng.
- Kho: ảnh kho, thêm/đổi/xóa ảnh, nhập hàng, quét mã, kiểm kê và đối chiếu chênh lệch.
- Giao hàng: ảnh xe và bằng chứng giao, tạo/sửa/xóa chuyến theo quyền; chỉ chủ xác nhận hoàn tất.
- Công nợ: ảnh đại diện người nợ, tạo/sửa/xóa sổ nợ, ghi nhận từng lần trả tiền, sửa/xóa lần thu có nhật ký. Trạng thái chưa trả/trả một phần/đã trả tính từ số tiền thực thu. Không xóa dấu vết tài chính đã ghi sổ.
- Lương nhân viên nằm trong mục Công nợ nhưng là tab riêng: nhân viên, kỳ lương, lương, ứng lương, đã trả, còn phải trả; tạo/sửa/xóa dữ liệu theo quyền, ghi nhận chi lương.
- Thông báo: yêu cầu gửi qua Fanpage VLXD Bảy Hải vào nhóm nội bộ “Đơn mới — Ai cũng đọc”, gồm sự kiện đơn mới và chuyến đã được chủ xác nhận xong. Không gửi tự động cho khách và không đọc hội thoại nhóm. Chưa xác minh API hỗ trợ đích nhóm Messenger này nên chưa cam kết tích hợp; không coi trạng thái cấu hình là gửi thành công.

Ảnh tạo bằng ImageGen tích hợp, là thiết kế tĩnh chưa có chức năng chạy thực tế. Các ngày, số tiền, ảnh người và số lượng là dữ liệu minh họa. Công tắc gửi khách trong ảnh phải bị khóa tắt khi triển khai theo yêu cầu chỉ gửi nội bộ.
