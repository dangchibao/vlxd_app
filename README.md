# VLXD Bảy Hải
Ứng dụng quản lý bán hàng gạch men tại Gò Dầu, Tây Ninh.

Cửa hàng Gò Dầu — Tây Ninh.

Bản chốt tính năng và tiêu chí nghiệm thu: [docs/yeu-cau-va-nghiem-thu.md](docs/yeu-cau-va-nghiem-thu.md).

Đã tích hợp Flutter/Dart, GetX, Firebase Authentication và Cloud Firestore cho project `vlxd-bay-hai`. Mặc định dùng tài khoản thật, vai trò từ Firestore và giao dịch kiểm tra phiên bản để đồng bộ. Security Rules mới chỉ có ở máy, chưa triển khai; chưa tạo chủ hoặc ghi dữ liệu thật. Hướng dẫn hiện hành: [docs/firebase-van-hanh.md](docs/firebase-van-hanh.md).

Năm tính năng bổ sung đã chọn: [docs/tinh-nang-bo-sung-da-chon.md](docs/tinh-nang-bo-sung-da-chon.md).

## Chạy ứng dụng

Yêu cầu Flutter 3.47 / Dart 3.13 trở lên.

```powershell
flutter pub get
flutter run -d chrome
```

Mặc định cần tài khoản Auth, hồ sơ `users/UID` và Rules được chủ duyệt triển khai. Không có mật khẩu mặc định. Muốn dùng lại dữ liệu mẫu cục bộ, chạy `flutter run -d chrome --dart-define=DEMO_MODE=true` rồi chọn vai trò thử. Dữ liệu mẫu SharedPreferences được giữ nguyên, không tự nhập lên Firestore. Không lưu mật khẩu tại đây.

```powershell
flutter analyze
flutter test
flutter build web --release
```

Windows native cần Developer Mode và Visual Studio Desktop development with C++. Đã build và chạy integration test Windows với emulator; Firebase ghi hỗ trợ Windows chỉ dành cho phát triển, nên vận hành trên Windows dùng Web/PWA. iOS/macOS cần máy Mac/Xcode và chưa được biên dịch tại đây. Bản web có manifest để thêm vào màn hình chính iPhone qua HTTPS; camera/in cần kiểm thử thiết bị thật và không bảo đảm vận hành ngoại tuyến.

## Chức năng đã có trong mã

- Điều hướng đáp ứng điện thoại/máy tính, cửa sổ desktop đặt tối thiểu 1000×700.
- Sản phẩm: thêm/sửa/ngừng kinh doanh, ảnh đại diện và ảnh chi tiết, ngày nhập lô, quy đổi và ngưỡng tồn tối thiểu.
- Tạo Code 128, in PDF khổ 80 mm qua hộp thoại hệ thống; nhập mã từ đầu đọc USB hoặc quét camera trên nền tảng được hỗ trợ rồi xác nhận thêm giỏ.
- Bán theo thùng hoặc m², tính gạch theo phòng, chốt đơn, cọc/giữ hàng, xuất đơn đã giữ, phân bổ lô cũ trước, tiền thu và công nợ. Bán âm cần lý do và xác nhận; chưa đối soát giá vốn lô âm.
- Chống trùng theo mã yêu cầu, chỉ mục yêu cầu duy nhất và transaction Firestore so sánh phiên bản. Tiền VND và diện tích dùng số nguyên; dữ liệu nguồn được đọc lại từ máy chủ trước ghi, không ghi đè toàn bộ từ bản cục bộ.
- Nhập hàng, kiểm kê có ảnh và chứng từ điều chỉnh; tạo/sửa chuyến, ảnh giao hàng và xác nhận hoàn tất.
- Khách hàng, thu tiền, sửa/hủy lần thu bằng bản ghi điều chỉnh; giữ lại chứng từ gốc. Hủy đơn giữ có xác nhận hoàn cọc và giải phóng hàng. Chủ tạo kỳ lương và sửa lương; nhân viên được xem nhưng không sửa.
- Tổng quan, top sản phẩm theo m², top khách nợ, nhật ký có tìm/lọc và phân trang; xuất CSV và JSON dữ liệu mẫu trên web/desktop.
- Tài khoản/mật khẩu hoặc alias số điện thoại, tạo nhân sự bằng Auth phụ để không đăng xuất chủ, cấp quyền/khóa người khác chỉ cho chủ; buộc đổi mật khẩu tạm và theo dõi thu hồi quyền phiên đang mở.
- Nhập dữ liệu cục bộ một lần vào namespace cửa hàng trống, có xác nhận và không ghi đè. Security Rules bảo vệ nhật ký, bảng lương và hồ sơ quyền; đã có bộ kiểm thử emulator riêng.
- Sự kiện thông báo lưu nội bộ và luôn ghi chưa gửi. Không nhắn khách hoặc đọc hội thoại.

PDF dùng font Noto tải từ Google Fonts ở lần sử dụng đầu; cần mạng. Logo và thông tin liên hệ chính thức chưa cung cấp. In thật trên KV804 và quét camera cần kiểm thử phần cứng.

## Còn lại trước khi vận hành

- Chủ xác nhận triển khai Rules và tạo tài khoản/hồ sơ chủ đầu tiên, sau đó mới kiểm thử project thật. Không có dữ liệu kinh doanh nào đã được chuyển bằng công cụ trong phiên này.
- Ảnh nhỏ hiện đồng bộ trực tiếp Firestore (40 KB/ảnh, 700 KB/chứng từ); Cloudinary là tùy chọn cần cấu hình nếu dùng ảnh lớn. Không bật Storage/Blaze hoặc thanh toán.
- Đặt lại mật khẩu người khác đã có công cụ Admin SDK ở `tools/admin/reset-password.mjs`, cần ADC tin cậy; chưa có endpoint quản trị để thực hiện ngay trong UI. Không nhúng credential vào Flutter.
- Hoàn thiện lịch sử chi lương riêng từng lần, chỉnh/xóa lô theo ràng buộc và phí ship theo km. Nhật ký ghi lại thay đổi tổng lương/đã ứng hiện tại.
- Báo cáo ngày/tuần/tháng, lãi/lỗ theo giá vốn, tổng kết đêm, logo báo giá, chia sẻ và in từ điện thoại qua máy quầy.
- Xác minh Graph API có hỗ trợ gửi vào đúng nhóm Messenger qua Fanpage. Chưa cam kết tích hợp này.
- Khôi phục từ bản xuất chưa có; CSV không bao gồm ảnh, mật khẩu, Firebase Auth và cấu hình hệ thống. JSON cho nhân viên loại dữ liệu bảng lương, nhật ký vẫn hiển thị thông tin thay đổi theo quyền đã thống nhất.

Không bật thanh toán hoặc triển khai Rules/Hosting trong phiên này. Các giới hạn, schema và bước cần người dùng tiếp theo xem [docs/firebase-van-hanh.md](docs/firebase-van-hanh.md). Bản yêu cầu ban đầu được giữ làm lịch sử; quy định quyền và nền tảng hiện hành trong tài liệu này thay thế các mục cũ mâu thuẫn.
