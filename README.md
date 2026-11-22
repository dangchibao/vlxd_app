# VLXD Hai Sóc – Bảy Hải

Quản lý bán hàng, sản phẩm/lô kho, công nợ, giao hàng, hóa đơn PDF và tài khoản. Chọn cửa hàng trước đăng nhập; dữ liệu hai cửa hàng tách riêng.

Đọc [PROJECT_STATUS.md](PROJECT_STATUS.md) để xem kết quả kiểm tra và phần chờ duyệt; [AGENTS.md](AGENTS.md) là quy tắc phát triển.

## Công nghệ và offline

Flutter/Dart + GetX, Firebase Authentication và Cloud Firestore. Drift/SQLite lưu giỏ nháp, cache theo tài khoản và Outbox. Firestore xác nhận chứng từ chính thức; bán hàng, nhập kho và thu nợ có luồng Outbox. Không phải mọi thao tác đều ghi được offline.

Tự đồng bộ kiểm tra mỗi 20 giây khi ứng dụng đang mở, có phiên hợp lệ và xác minh được máy chủ. Lỗi/xung đột cần đối chiếu; không chạy khi đóng app.

Bảy Hải dùng `stores/bay-hai` và hồ sơ `users/{uid}`; Hai Sóc dùng `stores/hai-soc` và `stores/hai-soc/members/{uid}`. Local DB tách theo cửa hàng/generation. Mật khẩu thuộc Firebase Auth, không đặt trong source.

## Chạy bằng VS Code

Môi trường đã xác minh 22/11/2026: Windows, Flutter 3.50.0 / Dart 3.14.0; JDK 21 dùng cho Android/Emulator. Giữ dependency trong `pubspec.lock`, không tự chạy `pub upgrade`.

Mở thư mục chứa `pubspec.yaml`, chạy PowerShell:

```powershell
cd D:\app\vlxd_app
# Chỉ thêm vào terminal hiện tại nếu PATH thiếu:
$env:Path = "D:\development\flutter\bin;C:\Program Files\Git\cmd;$env:Path"
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
# Windows cần Visual Studio + Desktop development with C++:
flutter run -d windows --dart-define=DEMO_MODE=true
```

Demo dùng dữ liệu mẫu cục bộ, không ghi Firestore. Có thể dùng `flutter pub get --offline` khi cache đã đủ. Android cần Android SDK và thiết bị/emulator trong `flutter devices`; iOS/macOS cần Mac/Xcode. iPhone có thể dùng Web/PWA.

Chạy dữ liệu thật bằng cách bỏ cờ DEMO_MODE, chọn cửa hàng rồi đăng nhập. Bản hiện tại bật auto-sync mặc định: đối chiếu hàng đợi trước khi thử bằng tài khoản thật. Test dùng demo hoặc Emulator.

## Bản đồ mã nguồn

| Đường dẫn | Vai trò |
| --- | --- |
| `lib/main.dart` | Khởi động, chọn cửa hàng, lắp service |
| `lib/controllers/` | Phiên đăng nhập, giỏ và điều phối nghiệp vụ |
| `lib/domain/` | Tiền, đơn vị, kho, đơn hàng, công nợ |
| `lib/data/local/`, `lib/data/sync/` | SQLite, cache, nháp, Outbox và đồng bộ |
| `lib/data/firestore_repository.dart` | Giao dịch có revision/requestId |
| `lib/ui/` | Màn hình, mobile, dialog và PDF; giữ cách chia part của app.dart |
| `test/`, `integration_test/` | Logic/widget và tích hợp Emulator |
| `tools/` | Kiểm tra/build/quản trị; không tự chạy script seed/sửa dữ liệu |
| `docs/`, `design/`, `assets/` | Tài liệu, thiết kế, ảnh mẫu |
| `release/` | Bộ cài/gói phát hành cục bộ |
| `backup/`, `.qa/` | Bản sao và bằng chứng kiểm thử, không đưa lên Hosting |

Giữ `app_database.g.dart` để biên dịch. Bộ vá chép đè cũ đã dọn; bản sao cần giữ gom ở `backup/legacy-patches/`. Không áp lại overlay cũ.

## Kiểm tra

```powershell
flutter analyze --no-pub
flutter test --no-pub
$env:JAVA_HOME = 'D:\jdk21'
$env:Path = "$env:JAVA_HOME\bin;C:\Users\HOA\AppData\Roaming\npm;$env:Path"
firebase emulators:exec --only firestore,auth --project demo-vlxd-tests --config firebase.emulator.json "node --test tools/security-tests/rules.test.mjs"
# Khi đổi Auth/repository/sync và có Windows toolchain:
firebase emulators:exec --only firestore,auth --project demo-vlxd-tests --config firebase.emulator.json "flutter test integration_test/store_selection_sync_test.dart -d windows"
```

Rules test cần dependency tại `tools/security-tests`. Quyền lương đang không khớp giữa AGENTS và mã/Rules, xem PROJECT_STATUS trước khi thay quyền.

## Build, phát hành và dọn cache

- `tools/build-web-offline.ps1` tạo Web có manifest/cache offline. Thêm `-DisableAutoSync` cho bản chẩn đoán; `tools/verify-offline.ps1 -BuildWeb` dùng chế độ này.
- `-RunBrowserQa` cần script QA riêng không có trong Git; thiếu script thì dừng ngay. Dùng integration test đã có thay thế.
- Build native release sau integration cần Flutter tái tạo plugin registrant; không dùng `--no-pub` cho lượt build đó, không sửa generated registrant bằng tay.
- Windows phải phân phối cả Release gồm DLL/data. Android đang ký debug, chưa phải gói ký Play Store.
- `.firebaserc` mặc định đang trỏ `open-loyalty-app`, khác project ứng dụng. Chưa tự đổi project ID. Lệnh Firebase cho app phải ghi rõ `--project vlxd-bay-hai`; deploy Rules/Hosting cần duyệt riêng cho bản sắp triển khai.
- PDF còn tải font qua PdfGoogleFonts; lần in đầu offline, máy in KV804 và điện thoại thật chưa được nghiệm thu ở lượt này.
- `flutter clean` dọn cache/đầu ra build, sau đó chạy `flutter pub get`. Không xóa DB người dùng, Outbox, backup hoặc bộ cài để chữa lỗi đồng bộ.
