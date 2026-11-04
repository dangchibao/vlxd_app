# Kết quả tích hợp và kiểm tra Firebase

## Bộ lọc và sản phẩm mẫu ngày 04/11/2026

Đã bổ sung bộ lọc hóa đơn theo ngày bán, thanh toán, khoảng tổng tiền và sắp xếp; giữ dữ liệu đọc từ đơn đã bán. `flutter analyze --no-pub` sạch, `flutter test --no-pub` qua 41 kiểm thử, gồm bộ lọc kết hợp/reset, biên ngày địa phương, tiền thu đã điều chỉnh và đơn vị m³. Giao diện hóa đơn kiểm tra ở 320/390/1440 px.

Theo yêu cầu người dùng, đã tạo trực tiếp 4 sản phẩm MAU-* có ảnh AI, giá/tồn minh họa trên project vlxd-bay-hai. Tạo nguyên tử với điều kiện revision, không ghi đè sản phẩm có sẵn; Firebase xác nhận revision 1 và đọc lại đủ 4 sản phẩm. Lập kế hoạch lần hai thấy existingProducts=4, create=[], skipped=4. Không tạo đơn/khách/lương mẫu, không thay Rules/Hosting/thanh toán. Chi tiết ở `assets/sample-products/README.md`.

## Cập nhật triển khai 04/11/2026

Sau khi người dùng xác nhận "Đồng ý triển khai Rules", đã chạy `firebase deploy --only firestore:rules --project vlxd-bay-hai --non-interactive`. Firebase CLI xác nhận biên dịch thành công, phát hành Rules lên Cloud Firestore và `Deploy complete!` (exit code 0).

SHA256 file phát hành: `59DDB03860D13500B64DC8A568A1F8ECE556C1D59A17AAE61F82A5F9D5E8F7C1`. Đây là cùng bản Rules đã kiểm thử bên dưới. Không triển khai Hosting, không ghi/xóa dữ liệu nghiệp vụ, không bật thanh toán. Chưa kiểm thử đăng nhập tài khoản thật sau triển khai; người dùng tự nhập mật khẩu trong app. Các phần dưới ghi lại kết quả tại ngày 03/11 trước triển khai.

Ngày kiểm tra 03/11/2026, tại `D:\app\vlxd_app`, project cấu hình `vlxd-bay-hai`.

## Thay đổi

- Bổ sung firebase_auth và cloud_firestore thực tế còn thiếu trong pubspec, giữ nguyên firebase_options.dart do người dùng tạo.
- Khởi tạo Firebase theo nền tảng, đăng nhập Auth thật, đọc vai trò từ users/UID; không có tài khoản hoặc mật khẩu mặc định trong mã.
- Tách demo bằng DEMO_MODE; mặc định kho thật trống, không tự nạp mẫu. Nhập dữ liệu cục bộ chỉ qua xác nhận của chủ và kiểm tra đích trống trong giao dịch.
- Đồng bộ các collection sản phẩm, đơn, khách, giao hàng, bảng lương và sổ biến động; transaction so sánh phiên bản, phát lại nghiệp vụ khi tranh chấp, chỉ mục chống trùng request.
- Chặn ghi đè từ dialog đã cũ đối với sản phẩm/tồn kho, kiểm kê, khách, chuyến, lương. Số đơn tìm mã trống, không ghi đè chứng từ có mã không liên tiếp từ lịch sử nhập.
- Thêm lịch sử đơn, lần thu, sửa/hủy lần thu giữ bản cũ, hủy giữ/hoàn cọc và giải phóng lượng giữ. Sao lưu CSV có trạng thái điều chỉnh, tiền hoàn và thu ròng.
- Chủ tạo nhân sự, cấp quyền/khóa người khác; nhân viên chỉ xem bảng lương. Theo dõi thay đổi hồ sơ đang mở, đóng dữ liệu khi thu hồi quyền và buộc đổi mật khẩu tạm.
- Rules có phân quyền và nhật ký bất biến; emulator riêng dùng project demo-vlxd-tests. Không tự đăng ký vai trò chủ.

## Kiểm tra đã chạy

| Kiểm tra | Kết quả |
| --- | --- |
| flutter analyze --no-pub | Không có lỗi hoặc cảnh báo |
| flutter test --no-pub | 26 kiểm thử qua |
| Rules Emulator qua Node | 10 kiểm thử qua |
| Integration Windows với Auth/Firestore Emulator | 1 kịch bản qua, gồm hai client, cùng request, nhập kho đồng thời, chặn sửa lương phía máy chủ, đăng nhập, khóa tài khoản, đổi mật khẩu tạm và đăng xuất |
| flutter build apk --debug | Thành công, bản thử ký debug |
| flutter build windows --release | Thành công |
| flutter build web --release --no-wasm-dry-run | Thành công |
| git diff --check | Không có lỗi khoảng trắng trên phần diff được Git theo dõi |

Kiểm thử bố cục gồm chiều rộng 320, 390, 768 và 1440 px; kiểm tra cả đăng nhập Firebase, đổi mật khẩu tạm và các màn hình chính của bản mẫu. Đây không phải kiểm thử trực tiếp trên iPhone hoặc máy in thật.

## Các lỗi đã xử lý

- Tranh chấp revision có thể trả permission-denied trước khi SDK native báo aborted. Chỉ thử lại khi đọc máy chủ xác nhận revision thực sự đã đổi; lỗi quyền không có thay đổi phiên bản vẫn bị từ chối.
- Flutter doctor không tự tìm được JDK. Dùng JDK 21 portable trong .tools, không đổi JAVA_HOME hệ thống; Firebase Emulator hiện yêu cầu Java 21.
- Kotlin incremental cache không xử lý được Pub cache trên C: và source trên D:. Tắt Kotlin incremental, dùng compiler trong process và giảm Gradle worker/heap cho máy 8 GB RAM. Không sửa hoặc xóa mã trong Pub cache.
- Đóng hộp thoại phải chờ hết vòng đời route trước khi hủy bộ nhập liệu; luồng quét mã vẫn yêu cầu xác nhận trước khi thêm giỏ.

Android còn cảnh báo tương thích KGP của firebase_auth/firebase_core với các phiên bản Flutter tương lai. Không chặn build hiện tại. Một lần link SDK Windows có cảnh báo LNK4078; các bản build hoàn tất. Không nâng Gradle/Kotlin vượt cấu hình template hoặc chỉnh SDK của người dùng để che cảnh báo.

## Đầu ra

- Android: build/app/outputs/flutter-apk/app-debug.apk. APK debug chứa nhiều ABI nên lớn; chưa phải bản phát hành tối ưu hoặc đưa lên cửa hàng.
- Windows: build/windows/x64/runner/Release/vlxd_app.exe. Giữ nguyên DLL và thư mục data bên cạnh, không chỉ chép riêng EXE.
- Web: build/web. Chạy qua HTTP/HTTPS, không mở index.html bằng file://.
- iOS/macOS: đã đối chiếu config/bundle ID, target và quyền; chưa build/ký do máy hiện tại là Windows. Cần Mac/Xcode để xác nhận thực tế.

Firebase native Windows được nhà cung cấp giới hạn cho luồng phát triển, không dành cho production. Bản Web/PWA là lựa chọn vận hành trên Windows. Nguồn: https://firebase.google.com/docs/flutter/setup#available-plugins

## Phạm vi chưa thực hiện trên dịch vụ thật

Không triển khai Security Rules hoặc Hosting, không bật thanh toán, không tạo tài khoản Auth thật, không ghi/xóa/nhập dữ liệu kinh doanh trên project thật. Các thao tác trong kiểm thử đều chạy trên emulator demo với dữ liệu giả.

Cần chủ tạo/chọn tài khoản Auth đầu tiên, tạo hồ sơ users/UID và duyệt riêng file firestore.rules trước khi kết nối nghiệp vụ thật. Hướng dẫn chi tiết ở firebase-van-hanh.md.

Giới hạn còn lại: ảnh nhỏ 40 KB/ảnh trong Firestore; ảnh lớn cần cấu hình nơi lưu riêng. Đặt lại mật khẩu người khác có công cụ Admin SDK nhưng chưa có endpoint quản trị trong UI. Chưa kết nối Messenger, cầu nối in từ iPhone, kiểm thử máy in/camera thật, báo cáo lãi lỗ đầy đủ hoặc tổng kết đêm. Những tính năng này không được mô tả là đã hoạt động trên dịch vụ thật.
