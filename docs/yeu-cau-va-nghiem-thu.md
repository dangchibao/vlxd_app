# Bản chốt tính năng — Cửa hàng VLXD Gò Dầu, Tây Ninh

Ngày ghi nhận: 03/11/2026. Tài liệu này là phạm vi yêu cầu, chưa phải xác nhận các tính năng đã được lập trình.

## 1. Sản phẩm và tồn kho

- Thêm, sửa, xóa sản phẩm gạch: 30×60, 60×60, 80×80, gạch thẻ, gạch chống trơn và các loại khác.
- Mỗi sản phẩm có 1 ảnh đại diện và hỗ trợ 5–10 ảnh chi tiết (vân gạch, phòng mẫu). Bấm ảnh để thay hoặc xóa; có thể chọn lại ảnh đại diện.
- Quản lý tồn theo sản phẩm, lô, thùng và m². Lưu hệ số quy đổi trên từng sản phẩm/lô; mặc định 1 thùng = 1,44 m², không áp dụng cứng cho mọi loại gạch.
- Không cho nhân viên bán vượt tồn khả dụng. Chỉ chủ được duyệt ngoại lệ bán âm; ghi người duyệt, thời điểm và lý do.
- Gợi ý xả kho đối với lô còn tồn có tuổi trên 60 ngày tính từ ngày nhập.

Tiêu chí nghiệm thu:

- Thay/xóa ảnh ngay từ ảnh đã chọn; dữ liệu sau lưu và tải lại khớp với thao tác.
- Với hệ số 1,44: 10 thùng tương ứng 14,4 m². Lưu số thập phân chính xác và quy tắc làm tròn thống nhất.
- Hai người bán đồng thời không làm vượt tồn nếu chưa được chủ duyệt.
- Lô còn tồn ở ngày tuổi 61 được cảnh báo; lô đã hết không nằm trong danh sách xả kho.

## 2. Bán hàng, báo giá và công nợ

- Tạo đơn nhanh bằng quét mã hoặc tìm/chọn gạch; tính diện tích, thùng nguyên, phần lẻ và thành tiền.
- Lưu giá bán, đơn vị và hệ số quy đổi tại thời điểm lập đơn để lịch sử không thay đổi khi sửa sản phẩm.
- Xuất PDF báo giá có logo, thông tin cửa hàng và ảnh gạch; hỗ trợ nhân viên chia sẻ cho khách qua Zalo.
- Theo dõi công nợ khách lẻ và công trình, tổng phải trả, các lần thanh toán và số còn thiếu.
- Giữ đơn, nhận đặt cọc; mức cọc mặc định 30%. Ghi rõ hàng đã giữ để tránh bán trùng.
- Khi hủy đơn giữ hàng, giải phóng lượng giữ và ghi nhận cách xử lý tiền cọc.

Tiêu chí nghiệm thu:

- Tổng đơn và PDF khớp nhau về số lượng, đơn vị, đơn giá, giảm giá và tổng tiền.
- Đơn 10.000.000 đồng gợi ý cọc 3.000.000 đồng; cọc được trừ vào số phải thu, không tính thu hai lần.
- Mọi đợt thu tiền có thời điểm và người ghi nhận; số dư công nợ được đối chiếu từ giao dịch.
- PDF tiếng Việt hiển thị đúng dấu, logo và ảnh. Chia sẻ Zalo không được coi là đã gửi nếu người dùng chưa thực hiện hoặc hệ thống chưa xác nhận.

## 3. Vận chuyển

- Tạo chuyến, gán đơn hàng, tài xế, xe và tiền ship.
- Tính phí theo km hoặc mức cố định theo chuyến; lưu cách tính và mức phí đã chốt.
- Chuyến đang giao chỉ chuyển sang “Đã xong” khi chủ xác nhận. Nhân viên không có quyền hoàn tất.

Tiêu chí nghiệm thu:

- Chặn quyền hoàn tất tại máy chủ, kể cả khi nhân viên gọi trực tiếp API.
- Ghi người và thời điểm chủ xác nhận hoàn thành; thao tác lặp lại không tạo thêm khoản thu/phí.
- Phân biệt phí ship thu khách và chi phí trả tài xế khi tính lãi.

## 4. Nhập hàng và kiểm kê

- Quản lý NCC, ví dụ Prime, Đồng Tâm, Viglacera.
- Phiếu nhập ghi sản phẩm, lô, số lượng, đơn vị, giá nhập và ngày nhập.
- Xem lịch sử giá nhập theo lô để biết giá vốn và phát hiện bán dưới giá vốn.
- Phiếu kiểm kê lưu ảnh kho, tồn hệ thống, tồn thực tế, chênh lệch và lý do điều chỉnh.
- Ghi sổ biến động tồn; phiếu đã ghi sổ được xử lý bằng nghiệp vụ điều chỉnh/đảo thay vì xóa mất lịch sử.

Tiêu chí nghiệm thu:

- Nhập, bán, giữ hàng, hủy giữ và điều chỉnh kiểm kê đều truy ra chứng từ gốc.
- Kiểm kê không tự ghi đè tồn mà thiếu chứng từ điều chỉnh.
- Giá vốn đơn đã bán có thể truy về lô xuất tương ứng.

## 5. Thông báo nội bộ

- Đơn mới chỉ gửi vào nhóm Messenger cửa hàng, không tự động nhắn khách.
- Nhóm “Đơn mới — Ai cũng đọc” nhận thông báo đơn mới.
- Nhóm “Chỉ chủ đọc” nhận yêu cầu duyệt đơn giá trị lớn; ngưỡng giá trị cần cấu hình.
- Chỉ gửi thông báo: không đọc hoặc thu thập nội dung hội thoại nhóm.
- Tổng kết buổi tối theo múi giờ Asia/Ho_Chi_Minh: tổng m² bán, số tiền thực thu; giờ gửi do cửa hàng cấu hình.

Tiêu chí nghiệm thu:

- Mỗi sự kiện có mã chống gửi trùng, trạng thái gửi và cơ chế thử lại khi lỗi.
- Đơn cần duyệt không được tiếp tục xử lý vượt quyền trước khi có quyết định của chủ.
- Chỉ đánh dấu gửi thành công khi kênh tích hợp xác nhận; lỗi gửi không làm mất đơn hàng.
- Tích hợp Messenger cần kiểm tra kênh/API được hỗ trợ và quyền truy cập thực tế trước khi cam kết gửi tự động vào nhóm. Không mặc định dùng tài khoản cá nhân hoặc đọc tin nhắn làm giải pháp.

## 6. Báo cáo cho chủ

- Doanh thu theo ngày, tuần, tháng.
- Lãi/lỗ theo loại gạch dựa trên doanh thu và giá vốn lô xuất; trình bày riêng ảnh hưởng phí vận chuyển.
- Top 10 gạch bán chạy, có thể đối chiếu theo m² và doanh thu.
- Top 10 khách còn nợ nhiều nhất.
- Tách doanh thu bán hàng và tiền thực thu; trừ trả hàng/hủy đơn theo nghiệp vụ tương ứng.

Tiêu chí nghiệm thu:

- Báo cáo đối chiếu được với chứng từ; cọc và thu nợ không làm tăng doanh thu lần nữa.
- Khách thanh toán hết không xuất hiện trong danh sách còn nợ.
- Các khoảng ngày và tổng kết đêm dùng cùng múi giờ cửa hàng.

## 7. Phân quyền tối thiểu

| Thao tác | Chủ | Nhân viên |
| --- | --- | --- |
| Lập đơn, báo giá, ghi nhận cọc/thu tiền | Có | Có theo quyền được cấp |
| Duyệt bán âm | Có | Không |
| Duyệt đơn vượt ngưỡng | Có | Không |
| Xác nhận chuyến “Đã xong” | Có | Không |
| Xem báo cáo lãi/lỗ toàn cửa hàng | Có | Theo quyền được cấp |

Tài khoản tài xế và quyền của tài xế cần xác định nếu tài xế sử dụng app. Mọi kiểm tra quyền phải thực hiện phía máy chủ.

## 8. Các quyết định cần xác nhận khi triển khai

1. Nền tảng bản đầu: web dùng trên điện thoại/máy tính hay Android.
2. Tên, địa chỉ, số điện thoại, logo cửa hàng để in báo giá.
3. Bán lẻ theo viên hay theo m²; số viên/thùng, quy tắc làm tròn và giá phần lẻ từng loại.
4. Ngưỡng đơn cần duyệt, thời hạn giữ hàng, cách xử lý cọc khi hủy và giờ tổng kết.
5. Tồn đầu kỳ, công nợ đầu kỳ, danh sách sản phẩm/NCC và người dùng.
6. Kênh thông báo khả thi sau khi kiểm tra khả năng tích hợp Messenger; cách chia sẻ Zalo thủ công hay tích hợp được cấp quyền.
7. Quy tắc xuất lô và giá vốn (đề xuất xuất lô cũ trước), thuế, chiết khấu, trả hàng và chi phí cần đưa vào lãi/lỗ.

## 9. Thứ tự triển khai đề xuất

1. Nền dữ liệu, đăng nhập/phân quyền, sản phẩm/ảnh, lô hàng, nhập kho và sổ tồn.
2. Bán hàng, quy đổi đơn vị, chặn bán âm, giữ hàng/cọc, công nợ và duyệt đơn.
3. Báo giá PDF, vận chuyển và kiểm kê.
4. Báo cáo, tồn lâu, tổng kết đêm và tích hợp thông báo đã xác minh.

Mỗi giai đoạn cần chạy được trên dữ liệu mẫu và đạt tiêu chí nghiệm thu liên quan trước khi sử dụng với dữ liệu thật.
