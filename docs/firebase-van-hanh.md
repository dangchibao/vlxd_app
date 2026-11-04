# Kết nối Firebase VLXD Bảy Hải

Project được kiểm tra từ mã cấu hình là `vlxd-bay-hai`. Các file cấu hình client do FlutterFire tạo được giữ nguyên. Khóa API Firebase client trong file này không phải khóa Admin SDK. Không đặt Service Account hoặc mật khẩu trong ứng dụng.

## Chế độ chạy

Mặc định khởi tạo Firebase, hiện màn hình tài khoản/mật khẩu và mở dữ liệu thật chỉ sau khi hồ sơ người dùng hợp lệ. Kho Firestore bắt đầu trống; không tự sinh mẫu hoặc tự chuyển dữ liệu cục bộ.

```powershell
flutter run -d chrome
```

Bản thử cũ vẫn còn, tách khỏi Firebase và không có tài khoản thật:

```powershell
flutter run -d chrome --dart-define=DEMO_MODE=true
```

## Chủ cửa hàng đầu tiên

Trước khi đăng nhập thật, chủ tạo một người dùng ở Authentication → Users → Add user bằng email thật hoặc alias `admin@accounts.bayhai.invalid` và mật khẩu mạnh ít nhất 10 ký tự. Nếu dùng alias, nhập `admin` ở màn hình đăng nhập. Không dùng `admin/admin`.

Lấy UID của tài khoản vừa tạo. Bằng Firebase Console có quyền quản trị, tạo tài liệu `users/UID` với đúng các trường:

| Trường | Kiểu | Giá trị |
| --- | --- | --- |
| role | string | owner |
| active | boolean | true |
| displayName | string | Chủ cửa hàng Bảy Hải |
| mustChangePassword | boolean | false |

Không dùng tên đăng nhập làm document ID thay UID. Không có chức năng tự nâng quyền hoặc tự đăng ký chủ trong client. Tài khoản Auth không có hồ sơ này sẽ bị từ chối truy cập.

Nhân viên tạo trong app bằng số điện thoại/tên tài khoản/email sẽ có hồ sơ `sales`, `driver` hoặc `other`. Số điện thoại được chuẩn hóa về dạng 0xxxxxxxxx rồi ánh xạ sang email nội bộ có đuôi `@accounts.bayhai.invalid`. Đây là tên định danh, không gửi SMS/email và không xác minh sở hữu SIM. Khi nhập email thật thì đăng nhập bằng email đó. Nhân viên nhận mật khẩu tạm phải đổi trước khi vào nghiệp vụ.

Auth và Firestore không có giao dịch chung: nếu Auth tạo xong nhưng ghi hồ sơ thất bại, app báo UID để chủ đối chiếu. App không xóa tài khoản hoặc âm thầm cấp quyền khi có lỗi.

## Security Rules cần chủ xác nhận trước khi triển khai

Ngày 04/11/2026, sau xác nhận riêng của chủ, đã phát hành `firestore.rules` lên project `vlxd-bay-hai`; Firebase CLI xác nhận biên dịch và triển khai thành công. Hồ sơ chủ hợp lệ vẫn là điều kiện truy cập. App báo lỗi thay vì dùng dữ liệu mẫu thay thế khi bị từ chối quyền. Những lần triển khai tiếp theo vẫn cần xác nhận riêng.

- Chưa đăng nhập, tài khoản thiếu hồ sơ, bị khóa, tài xế và vị trí khác không được truy cập kho.
- Cập nhật theo yêu cầu ngày 04/11/2026: Chủ và Nhân viên bán hàng đều chỉnh được công nợ, Phải thu/Đã thu, tạo/sửa/xuất lương, không nhập lại mật khẩu admin. Chỉ Chủ quản lý quyền/khóa người khác; không khóa hoặc đổi quyền của chính mình trong app.
- Ngày 04/11/2026, sau xác nhận riêng cho bản cập nhật, đã triển khai thành công Rules mở quyền sửa công nợ/lương cho Chủ và Nhân viên, bổ sung trường Lưu ý sản phẩm và ratio=0. Firebase CLI xác nhận biên dịch và phát hành thành công. Chi tiết và SHA256 tại cong-no-luong.md. Những lần phát hành Rules tiếp theo vẫn cần xác nhận riêng.
- Nhật ký kho và nghiệp vụ chỉ được tạo, không được sửa/xóa. Thay đổi số tiền thu dùng bản ghi điều chỉnh, không làm mất bản gốc.
- Mỗi commit nghiệp vụ phải cập nhật phiên bản và có một nhật ký đồng bộ đi kèm. Đơn mới phải có bản ghi mã yêu cầu duy nhất. Không cho ghi thẳng từng tài liệu bỏ qua cơ chế này.
- Profile có `mustChangePassword=true` bị chặn nghiệp vụ; người dùng chỉ cập nhật cờ về false sau luồng đổi mật khẩu. Rules không tự kiểm chứng sự kiện thay mật khẩu bên Auth; người đang giữ mật khẩu tạm vẫn được xem là đã xác thực. Nếu cần cưỡng chế tuyệt đối chống client bị sửa, dùng backend quản trị phát hành phiên/token sau đổi mật khẩu.

Rules kiểm tra quyền, cấu trúc chính, phiên bản, dấu vết và tính bất biến chứng từ. Các công thức phân bổ lô và điều chỉnh chi tiết vẫn chạy trong lớp nghiệp vụ Flutter; không phải mọi phép tính trên danh sách lô/lần thu đều có thể chứng minh bằng Rules. Mô hình này tin cậy nhân viên được cấp quyền nghiệp vụ; nếu cần chống cả client bị sửa của nhân viên hợp lệ, phải chuyển lệnh nghiệp vụ sang backend tin cậy trước khi vận hành với yêu cầu đó.

Không chạy lệnh deploy khi chưa có xác nhận riêng của chủ. Lệnh dự kiến sau khi đã duyệt:

```powershell
firebase deploy --only firestore:rules --project vlxd-bay-hai
```

## Lưu trữ và đồng bộ

Dữ liệu có namespace riêng dưới `stores/bay-hai/`: `products`, `orders`, `customers`, `deliveries`, `payroll`, `audit`, `stockMoves`, `notifications`, `requests`. Tài liệu `meta/state` giữ phiên bản đồng bộ. Tài khoản ở `users`, nhật ký quản trị ở `accountAudit`. Các collection khác của project không bị sửa.

Trước khi ghi, repository tải bản mới từ máy chủ, chạy nghiệp vụ trên bản sao và so sánh phiên bản trong transaction. Tranh chấp được tải lại và tính lại; lỗi quyền thật không bị bỏ qua. Máy mất mạng không chốt đơn ngoại tuyến; giỏ được giữ trong phiên để thử lại. Mã yêu cầu chốt đơn giữ nguyên khi lỗi để không trừ tồn/thu tiền lần nữa.

Dialog sản phẩm, kiểm kê, khách hàng, chuyến và lương kiểm tra bản gốc trước khi sửa để tránh ghi đè thay đổi mới. Ảnh đang lưu trực tiếp dạng ảnh nhỏ trong tài liệu Firestore, không bật Storage hoặc thanh toán: giới hạn 40 KB sau nén/ảnh, tối đa 11 ảnh sản phẩm, mỗi chứng từ dưới 700 KB. Ảnh lớn cần Cloudinary hoặc nơi lưu phù hợp; không nhét file lớn vào Firestore.

Repository hiện tải toàn bộ dữ liệu cửa hàng cho mỗi lần đồng bộ nhất quán. Cách này đơn giản cho bản đầu cửa hàng nhỏ nhưng số lượt đọc và dung lượng truyền tăng theo dữ liệu; chưa cam kết miễn phí vô hạn. Cần theo dõi quota và tối ưu truy vấn/phân trang phía máy chủ khi dữ liệu tăng. Giao dịch lớn hơn 200 tài liệu bị từ chối; nhập lịch sử nhiều đơn còn chịu giới hạn lượt truy cập tài liệu của Security Rules.

## Nhập dữ liệu mẫu đã lưu

Chủ vào Cài đặt → Nhập dữ liệu mẫu đã lưu vào kho trống. App đọc đúng dữ liệu đã lưu trên thiết bị, hiện số lượng để xác nhận và chỉ nhập khi các collection đích đều trống. Không tự nhập khi đăng nhập, không trộn hoặc ghi đè kho đã có dữ liệu. Giao dịch nhập là nguyên tử; lỗi kích thước/quyền/quota không ghi một phần. Bản cục bộ giữ nguyên. Nhật ký nhập ghi nguồn mẫu và người chủ thực hiện; không coi tên nhân viên giả lập là danh tính Firebase thật.

## Khôi phục mật khẩu

Tự đổi mật khẩu trong app cần mật khẩu hiện tại. Nhân viên không đặt lại được cho người khác. Đặt mật khẩu tạm cho người quên cần Admin SDK ở môi trường tin cậy, không thể làm an toàn chỉ với Firebase client.

Đã chuẩn bị `tools/admin/reset-password.mjs`; chưa chạy trên tài khoản thật. Công cụ yêu cầu Application Default Credentials có quyền quản trị project và biến môi trường `BAYHAI_TEMP_PASSWORD`, không ghi hoặc in mật khẩu. Nó đặt cờ buộc đổi mật khẩu, đổi mật khẩu Auth, thu hồi refresh token và ghi nhật ký. Không đổi role hoặc trạng thái active. Nếu lỗi giữa chừng, quyền nghiệp vụ vẫn đóng và chủ phải đối chiếu/chạy lại. Không đưa credential này vào Flutter, Git hoặc chat. Triển khai endpoint quản trị riêng để chủ đặt lại ngay trong app là bước bổ sung chưa cấu hình dịch vụ.

## Nền tảng

- Android: cấu hình google-services và package name khớp; camera/Internet đã khai báo. APK debug chỉ để thử, chưa có chữ ký phát hành cửa hàng.
- iOS: cấu hình đúng bundle ID, deployment target 15.0, quyền camera/thư viện ảnh. Build/ký và kiểm thử thiết bị cần Mac/Xcode.
- macOS: target 12.0, khai báo camera, mạng, file/printing và Keychain Sharing; cần Mac để kiểm tra chữ ký thực tế.
- Web/iPhone qua Safari: dùng HTTPS/localhost; camera cần quyền trình duyệt. Có manifest màn hình chính. Chưa thử máy iPhone thật trong phiên này.
- Windows: Auth/Firestore native được Firebase ghi là beta, chỉ dành cho luồng phát triển tại máy, không dành cho production. Có banner trong app; khi vận hành cửa hàng trên Windows nên dùng bản Web/PWA. Nguồn: https://firebase.google.com/docs/flutter/setup#available-plugins

Máy in KV804 cần kiểm tra trên máy quầy; không tuyên bố đã in thành công chỉ dựa vào build. Facebook group, in qua cầu nối iPhone và tổng kết tự động chưa có kết nối dịch vụ thật.

## Kiểm thử tách khỏi project thật

`firebase.emulator.json` và project giả `demo-vlxd-tests` dùng cho kiểm thử. Không nạp file cấu hình Firebase thật trong integration test. JDK 21 portable được tải từ Eclipse Adoptium, kiểm tra SHA256 và lưu trong `.tools` bị Git bỏ qua, không thay đổi JAVA_HOME hệ thống.

```powershell
npm install --prefix tools/security-tests --ignore-scripts
$env:JAVA_HOME = (Resolve-Path '.tools/jdk21/jdk-21.0.13+9').Path
$env:Path = "$env:JAVA_HOME/bin;$env:Path"
firebase emulators:exec --only firestore,auth --project demo-vlxd-tests --config firebase.emulator.json "node --test tools/security-tests/rules.test.mjs"
firebase emulators:exec --only firestore,auth --project demo-vlxd-tests --config firebase.emulator.json "flutter test integration_test/firebase_sync_test.dart -d windows"
flutter analyze
flutter test
```
