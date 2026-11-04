# Thiết kế giao diện VLXD Gò Dầu

## Bố cục đã đưa vào Flutter ngày 04/11/2026

Khung máy tính đã đổi sang menu ngang, khu vực nhận diện bên trái và trạng thái đồng bộ. Màn Công nợ có bảng khách hàng, tìm kiếm, chọn khách xem các lần thanh toán, bảng lương và trạng thái trống. Màn hẹp xếp dọc, bảng cuộn ngang. Những màn khác hiện dùng khung mới nhưng nội dung chưa được đối chiếu hoàn chỉnh với toàn bộ ảnh ý tưởng bên dưới.

`07-cong-no-flutter-thuc-te.png` là ảnh render widget Flutter với dữ liệu trống trong kiểm thử, không phải ảnh ImageGen hay ảnh dữ liệu Firebase thật. Khi tạo ảnh trên Windows, kiểm thử nạp Segoe UI thay font mặc định kiểm thử và Material Icons để đọc được nội dung. Không nhập dữ liệu mẫu lên Firebase để làm đầy giao diện.

Bộ ảnh ý tưởng giao diện dựa trên danh sách tính năng đã chốt và ảnh KiotViet do người dùng cung cấp. Tạo bằng công cụ ImageGen tích hợp. Đây là ảnh thiết kế, chưa có mã giao diện hoặc bản cài đặt.

- 01-dang-nhap-tong-quan.png: đăng nhập và tổng quan trên máy tính.
- 02-hang-hoa-ban-hang.png: quản lý gạch, chi tiết ảnh và bán hàng trên máy tính.
- 03-giao-dien-dien-thoai.png: đăng nhập, tổng quan, bán hàng, giao hàng trên điện thoại.

Định hướng: máy tính có bảng và khung đơn hàng cạnh nhau; điện thoại dùng thẻ sản phẩm, nút lớn và thanh đơn hàng cố định. Thiết kế dành cho triển khai thích ứng trên Android, iOS, Windows 11 và macOS; ảnh không chứng minh khả năng chạy thực tế.

Quy tắc khi triển khai: cảnh báo tồn trên 60 ngày; quy đổi riêng từng sản phẩm; chủ duyệt bán âm và xác nhận hoàn tất giao hàng; đặt cọc mặc định 30%.

Giới hạn ảnh tạo tự động: ảnh điện thoại còn ghi 90 ngày ở ô tồn lâu, phải dùng 60 ngày khi lập trình. Một số số liệu minh họa và logo giữa các ảnh chưa đồng nhất; không dùng chúng làm dữ liệu hay nhận diện chính thức. 120 m² trong ảnh tổng quan không tương ứng 48 thùng ở hệ số 1,44; phần quy đổi này cần tính từ dữ liệu thực khi triển khai.
