# Hóa đơn bán hàng

Đã bổ sung ngày 04/11/2026. Vào menu Hóa đơn hoặc Bán hàng → Hóa đơn đã bán.

- Danh sách chỉ lấy đơn có trạng thái Đã bán từ dữ liệu bán hàng đang đồng bộ; đơn giữ hoặc đã hủy không xuất hiện. Không tạo collection hóa đơn riêng, không ghi lại doanh số/tồn kho khi xem/in.
- Hiện mã đơn làm mã hóa đơn, tên khách, ngày bán (soldAt nếu đơn giữ đã xuất, nếu không dùng at), tổng tiền, đã trả, còn nợ. Tìm theo mã hoặc tên khách.
- Bộ lọc kết hợp: ngày bán (toàn bộ, hôm nay, 7 ngày qua, tháng này, khoảng ngày tùy chọn); thanh toán (tất cả, còn nợ, chưa trả, trả một phần, đã trả hết); khoảng tổng tiền nguyên VND. Lọc hết ngày kết thúc theo giờ thiết bị. Sắp xếp mới nhất/cũ nhất/tổng tiền cao nhất/còn nợ nhiều nhất; nút Xóa bộ lọc trả về toàn bộ. Số hóa đơn, tổng tiền và nợ hiển thị theo kết quả lọc. Lọc trên dữ liệu đã tải, chưa phát sinh truy vấn Firestore mới theo mỗi lần gõ.
- Bấm hóa đơn mở chi tiết sản phẩm, mã hàng, diện tích, đơn giá lúc bán, thành tiền và các lần thu. Tiền đã trả bỏ qua lần thu bị hủy/điều chỉnh theo logic công nợ hiện có.
- Nút Xem / in PDF mở bản A4 với mã, khách, ngày, danh sách sản phẩm, tiền hàng, vận chuyển, tổng tiền, đã trả và còn nợ. Dùng nút in/chia sẻ của bản xem trước để in hoặc lưu PDF, tùy trình duyệt/nền tảng.
- PDF lấy giá/tên hàng/diện tích/thành tiền từ snapshot của đơn, không dùng giá sản phẩm hiện tại. Tên khách lấy từ hồ sơ khách hiện tại vì dữ liệu đơn cũ chưa lưu snapshot tên khách.
- Phông Noto Sans tiếng Việt dùng cùng cơ chế tải/cache của báo giá hiện có; lần đầu cần mạng. Đây là phiếu bán hàng nội bộ, không phải tích hợp hóa đơn thuế. Chưa thử in vật lý trên KV804.

Kiểm thử: danh sách trên 390/1440 px, loại đơn giữ, xem chi tiết và số tiền sau bán, giá sản phẩm thay đổi không sửa đơn cũ; tạo PDF ngoại tuyến với font thử, không làm thay đổi dữ liệu và từ chối đơn chưa bán.
