# BÁO CÁO RÀ SOÁT UI VLXD BAY HAI — Desktop / Web / Điện thoại

**Nguồn:** ZIP dự án VLXD_Bay_Hai_REVIEW_CODE_20261120_222902.zip (bản gốc) cùng cấu trúc các bản vá đơn vị, tìm kiếm Kho và icon V4 đã triển khai. Bản vá được thiết kế để đối chiếu đúng mã nguồn đang có tại `D:\app\vlxd_app`; nếu cấu trúc không khớp, script **dừng trước khi sửa file**.

## Phạm vi đã đọc tĩnh

- 21 file `lib/ui/*.dart` — 12,650 dòng mã UI.
- Hộp thoại AlertDialog: **29** vị trí (đếm bằng mẫu văn bản, không tương đương lỗi thực tế).
- Bảng DataTable: **6** vị trí (đếm bằng mẫu văn bản, không tương đương lỗi thực tế).
- TextField: **24** vị trí (đếm bằng mẫu văn bản, không tương đương lỗi thực tế).
- Cuộn nội dung: **26** vị trí (đếm bằng mẫu văn bản, không tương đương lỗi thực tế).
- LayoutBuilder: **16** vị trí (đếm bằng mẫu văn bản, không tương đương lỗi thực tế).

- Đã kiểm tra các điểm kết nối từ Dashboard / Hàng hóa / Bán hàng / Kho / Giao hàng / Công nợ / Báo cáo / Hóa đơn / Nhật ký / Kế toán & Thuế / Cài đặt. Đánh giá tĩnh không thể chứng minh tất cả form đều đã được nhìn trực tiếp trên thiết bị thật.

## Các điểm cần xử lý và cách triển khai trong bản ZIP

| Mức ưu tiên | Vị trí | Phát hiện | Thay đổi đề xuất/đã đóng gói |
|---|---|---|---|
| Cao | Form Đính chính đơn vị | Text `Lý do sửa sai` và số lượng bị chồng viền, form cao và khó nhập trên điện thoại | Nhãn riêng trên ô; co chiều cao dialog theo phần còn lại sau bàn phím; checkbox đặt đầu dòng |
| Cao | Form nhập chung | Nhãn luôn nổi ở viền gây kẹt chữ với một số tỉ lệ zoom | Chuyển sang `FloatingLabelBehavior.auto`, vẫn giữ `labelText` để không làm hỏng test/nhập liệu |
| Cao | Hàng hóa — mobile | Một sản phẩm chiếm nhiều dòng và buộc cuộn nhiều | Chỉ hiện tên, mã, giá, tồn; giá vốn/ghi chú vẫn xem được từ menu **Chi tiết** |
| Cao | Hàng hóa — mobile | Thiếu lối vào Đính chính đơn vị từ menu mobile | Thêm mục riêng chỉ dành cho Admin, giữ xác minh nghiệp vụ ở domain |
| Cao | Kho — mobile | Nút Nhập hàng/Kiểm kê chiếm rộng; lịch sử 20 dòng kéo dài | Rút nút thành icon tooltip; lịch sử biến động gập/mở, vẫn xem được 20 dòng |
| Cao | Công nợ — mobile | Bảng 6 cột bắt buộc kéo ngang và khó chọn khách | Thay danh sách khách bằng dòng gọn gồm tên–điện thoại–còn nợ; menu sửa/xóa; desktop vẫn giữ bảng |
| Trung bình | Hộp thoại chung | Khoảng cách viền lớn trên màn hình rất nhỏ | Giảm inset cho dialog, không đổi font/kích thước bảng ở desktop |

## Những gì tuyệt đối không thay đổi

- Quy trình đặt hàng, giỏ hàng, thanh toán, xuất/nhập/kiểm kê kho, công nợ, in Code 128 và hóa đơn; các handler đã có vẫn được giữ lại.
- Không chạm `lib/domain`, `lib/controllers`, `lib/data`, cấu hình Firebase/Firestore, SQLite và offline outbox.
- Giữ bộ **4 icon V4** trong Hàng hóa: bút chì xanh, phiếu tick cam, máy in xanh ngọc, ngừng bán đỏ.
- Giữ quyền Admin cho đính chính đơn vị, không tự nới điều kiện nghiệp vụ.

## Kiểm tra trước khi phát hành

Script thực hiện: kiểm tra 22 vị trí mã nguồn; kiểm tra các handler quan trọng; sao lưu 6 file trước khi ghi; `dart format`, `flutter pub get`, `flutter analyze`, toàn bộ `flutter test`; thêm widget smoke test ở độ rộng 320 / 390 / 430 px. Bất kỳ bước nào không đạt => hoàn nguyên các file đã sửa. Không tự cài Setup hoặc đăng Firebase Hosting.

## Giới hạn kiểm chứng

Chưa chạy Flutter trong môi trường tạo ZIP này, vì Flutter SDK không sẵn có. Các test trên máy Windows là điều kiện phát hành bắt buộc; kết quả xanh không thay cho kiểm tra trực tiếp trên Android/iPhone, độ phóng đại, bàn phím ảo, thiết bị offline và máy in USB. Các bảng Kế toán & Thuế vẫn hỗ trợ cuộn ngang; nếu muốn trải nghiệm mobile giống ứng dụng hoàn toàn cho phần này, nên làm một vòng tối ưu riêng với dữ liệu và ảnh màn hình thực tế sau khi bản an toàn này đạt test.

**Mục tiêu sản phẩm:** Mobile = thông tin cần dùng ngay + icon thao tác, chi tiết mở theo yêu cầu; Desktop/Web màn hình rộng = bảng, số liệu và thao tác đầy đủ.


## V2 sửa lỗi khớp mã nguồn
- Bản cũ dừng ở `Correction secondary unit field (0 matches)` trước khi ghi file.
- V2 dùng tên controller duy nhất (`newUnit`, `secondary`, `ratio`, `newPrice`, `reason`) để tìm đúng trường thay vì chuỗi nhãn cố định.
- Kiểm tra lại tất cả 22 thay đổi trên 6 UI files trước khi ghi; nếu có trường hợp code biến thể không xác định, từ chối và chỉ dẫn lệnh xuất 6 file giao diện.
- Chưa kiểm thử thực tế trên Flutter SDK Windows; yêu cầu phân tích và test máy người dùng rồi xem giao diện thật 320/390/430px.
