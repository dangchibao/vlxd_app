# Bước kết nối dịch vụ

## Firebase

1. Đăng nhập https://console.firebase.google.com bằng tài khoản của chủ.
2. Tạo project VLXD Bay Hai, giữ Spark miễn phí, chưa bật thanh toán.
3. Authentication: bật Email/Password, không bật Phone. Tên đăng nhập hoặc số điện thoại được ánh xạ ở lớp ứng dụng; không dùng SMS.
4. Firestore: Standard edition, database mặc định, Production mode, Singapore asia-southeast1 nếu có. Không nhập dữ liệu thật và không mở Test mode.
5. Gửi Project ID trong Project settings → General. Đây không phải mật khẩu.

Chưa cần tự tạo app Android/iOS/web hoặc tài khoản admin; cấu hình bằng FlutterFire sau khi chốt ID. Không gửi mật khẩu Google, private key hoặc Service Account vào chat. Khi CLI cần đăng nhập, người dùng thực hiện trên trình duyệt của mình.

## Dịch vụ miễn phí bổ sung

- Tạo Cloudinary Free để lưu ảnh; chưa nhập thẻ hoặc nâng gói. Cloud name là thông tin có thể gửi, API secret phải cất ở phía máy chủ.
- Tạo Cloudflare Free để triển khai Worker cho thao tác quản trị và ký yêu cầu ảnh. Chưa cần tự tạo API token hoặc gửi khóa.
- Dùng hạn mức miễn phí; không có cam kết miễn phí vô hạn hoặc tự nâng gói. Quá hạn mức có thể gián đoạn chức năng.

## Những quyết định đã thay thế yêu cầu cũ

- Thương hiệu VLXD Bảy Hải, Gò Dầu, Tây Ninh.
- Nhân viên có quyền nghiệp vụ như chủ kể cả duyệt bán âm và hoàn tất chuyến; không sửa lương, cấp quyền hoặc khóa người khác. Quyền đặt lại mật khẩu người khác chỉ thuộc admin. Tài xế/vị trí khác chưa được truy cập.
- Không dùng SMS/email khôi phục; admin đặt mật khẩu tạm, bắt buộc đổi khi đăng nhập tiếp. Mật khẩu khởi tạo thực tế phải tuân thủ độ dài Firebase; không sử dụng admin/admin trong dữ liệu thật.
- Giữ Firebase Auth/Firestore/Hosting Spark; Cloudinary thay Firebase Storage. Không dùng Cloud Functions trả phí.
- Máy in KV804, giấy 80 mm, USB + LAN, ESC/POS theo tem người dùng cung cấp. Chưa có bằng chứng máy hỗ trợ tem nhãn tự dính.
- Luồng mã vạch: tự tạo/in → quét → hiện sản phẩm và nhập số lượng → xác nhận thêm giỏ; không tự thêm khi quét.
- Thông báo chỉ đơn mới và chuyến xong vào nhóm nội bộ; API nhóm Messenger chưa xác minh.

## Windows và iPhone

- Bật Developer Mode trong cài đặt Windows để Flutter tạo symlink plugin; đây là thao tác người dùng tự làm. Nếu xuất EXE cần Visual Studio Desktop development with C++.
- Web dùng được trên iPhone qua HTTPS và thêm vào màn hình chính, không cần phát hành App Store. Chưa có bản iOS/macOS được kiểm thử trên phần cứng.
