# Quy tắc làm việc — VLXD Bảy Hải

## Bắt đầu tác vụ

- Đọc `PROJECT_STATUS.md` trước; đây là bản đồ điều hướng, không phải yêu cầu đọc lại mọi tài liệu liên kết.
- Xác định phạm vi, tiêu chí nghiệm thu, module bị ảnh hưởng và kiểm tra cần chạy; chỉ dùng `rg`/đọc các file liên quan. Không quét build, Pub cache, node_modules, .tools hoặc toàn bộ repository khi không cần.
- Yêu cầu người dùng mới nhất có ưu tiên hơn mô tả lịch sử. Không tự sửa code khi lượt hiện tại chỉ yêu cầu kế hoạch/tài liệu.
- Không tạo agent/tác vụ phụ trừ khi người dùng yêu cầu hoặc có hướng dẫn áp dụng yêu cầu rõ ràng. Gom thay đổi cùng nghiệp vụ; không mở rộng sang lỗi ngoài phạm vi, ghi nhận vào PROJECT_STATUS.md.

## Kiến trúc hiện tại và hướng dự kiến

- Flutter/Dart + GetX. `SessionController` quản lý Auth/hồ sơ; `ShopController` điều phối giỏ và repository; `ShopData` trong domain chứa nghiệp vụ.
- Interface `ShopRepository`/`TransactionalShopRepository` nằm trong `lib/data/demo_repository.dart`. Live là `FirestoreRepository`; demo là SharedPreferences, tách bằng DEMO_MODE.
- UI là thư viện `lib/ui/app.dart` với các file `part`. Tận dụng field/panel/dialog/theme, model và service hiện có. Không tách/rewrite toàn UI, thay GetX hoặc đưa framework mới vào để làm một tính năng nhỏ.
- SQLite/offline-first mới là hướng dự kiến, **chưa triển khai**. Không thêm package SQLite, đổi schema hoặc chuyển production repository nếu chưa có tác vụ/thiết kế được duyệt rõ ràng. Đọc mục G0–G2 trong PROJECT_STATUS khi thực hiện nhóm đó.
- Không coi Firestore cache hoặc demo SharedPreferences là offline-first production. Không bỏ cơ chế revision/requestId hiện tại trước khi cơ chế thay thế được kiểm thử.

## Bất biến nghiệp vụ

- Tiền VND là số nguyên; lượng m²/m³ hiện dùng đơn vị 1/10.000. Dùng helper/domain hiện có, không chuyển sang double cho lưu tiền/số dư.
- Phân biệt tồn thực tế, đang giữ và khả dụng. Giá/đơn vị/quy đổi/phân bổ lô của hóa đơn đã chốt là snapshot; sửa sản phẩm không sửa hóa đơn cũ.
- Thu nợ/cọc không làm tăng doanh thu lần nữa. Điều chỉnh thu tiền, sổ nợ hoặc tồn phải giữ chứng từ và nhật ký; không xóa lịch sử để làm khớp số dư.
- Xóa sản phẩm/khách dùng ngừng sử dụng/ẩn theo điều kiện domain hiện tại. Tôn trọng các kiểm tra stale dialog và transactional commit, không dùng last-write-wins cho tài chính/kho.
- Chốt lại đơn do retry không được xuất kho/thu tiền thêm lần nữa. Khi làm offline, phải xác định trường hợp crash, ack bị mất và hai máy offline cùng bán trước khi cam kết an toàn.

## Quyền đã chốt

- Chủ và Nhân viên bán hàng được thao tác nghiệp vụ, gồm chỉnh công nợ/Phải thu/Đã thu và tạo/sửa/xuất lương; không yêu cầu mật khẩu admin để mở hai nút cài đặt công nợ/lương.
- Chỉ Chủ được cấp quyền/quản lý/khóa tài khoản khác. Không tự nâng quyền, bỏ Auth, khôi phục admin/admin hay hardcode mật khẩu.
- Driver/other, thiếu hồ sơ, tài khoản khóa không vào nghiệp vụ. Giữ kiểm tra client và Rules; kiểm tra client không thay kiểm tra server.
- Hoàn tất giao hàng hiện cho Chủ và Nhân viên theo yêu cầu sau. Tài liệu yêu cầu đầu tiên/README có điểm cũ; không phục hồi giới hạn cũ tự động.
- Bán âm/duyệt đơn lớn còn có mâu thuẫn yêu cầu: xem F06 trong PROJECT_STATUS, chốt trước khi thay. Không tự mở hoặc siết quyền.

## Dữ liệu thật, dịch vụ và dependency

- Firebase production: `vlxd-bay-hai`, namespace `stores/bay-hai`, hồ sơ `users`. Kho đã có dữ liệu; không tự seed, reset, xóa, import hoặc ghi đè.
- Không đưa service-account, ADC, mật khẩu hoặc token vào Flutter/Git/log/chat. Không in thông tin credential khi điều tra.
- Không tự bật Blaze/billing, Storage trả phí, SMS hay dịch vụ ngoài có phí. Spark là ưu tiên; không cam kết miễn phí vô hạn hoặc tự động đổi nhà cung cấp.
- Không tự thay Firebase project/app IDs, firebase_options, bundle/package IDs, schema/version, database hoặc auth flow. Migration cần thiết kế, kiểm tra bằng bản sao và phương án phục hồi; không chạy trên kho thật theo suy đoán.
- Deploy Rules/Hosting hoặc thay đổi dịch vụ thật cần xác nhận cụ thể cho bản sắp triển khai. Xác nhận cũ không mặc nhiên bao phủ bản mới. Hoàn thành mã, diff và kiểm tra trước khi hỏi duyệt cuối.
- Không gửi tin nhắn qua Messenger/Zalo/email cho người khác nếu chưa được yêu cầu rõ. Không báo sự kiện “đã gửi” khi chưa có ack.
- Không tự nâng Flutter/Gradle/Kotlin/Firebase SDK hoặc sửa cache/toolchain để né lỗi. Ưu tiên phiên bản đã khóa và ghi lại lỗi ngoài phạm vi.
- Không git clean/reset/checkout đè file, xóa untracked hoặc commit/push khi chưa có yêu cầu; workspace có nhiều file chưa được theo dõi từ trước.

## Kiểm tra theo phạm vi

Chọn test có thể bắt lỗi thật; không tạo test chỉ sao chép implementation. Không coi test cũ hoặc build cũ là kết quả mới.

| Loại thay đổi | Kiểm tra tối thiểu phù hợp |
| --- | --- |
| Chỉ tài liệu/kế hoạch | Đối chiếu nguồn, link/path, tính nhất quán và file thực sự đổi; không chạy Flutter build/test |
| UI một tính năng | Widget test liên quan, kích thước nhỏ/lớn khi đổi bố cục; analyze. Giữ kiểm tra tổng tiền/khách/đơn nếu UI tác động dữ liệu |
| Tiền/tồn/lô/cọc/công nợ/lương | Domain test gồm biên/điều chỉnh/idempotency/stale; widget test luồng bị ảnh hưởng; analyze |
| Auth/quyền/Rules | Test vai trò cho phép và từ chối; Rules emulator; integration khi thay giao thức hoặc phiên truy cập |
| Repository/sync/schema/migration | Test mất mạng/retry/đồng thời/crash/rollback và integration hai client; domain regressions liên quan, trước khi migration thật |
| Dependency/toolchain/nền tảng hoặc chuẩn bị release | Build nền tảng khả dụng, ghi rõ môi trường; iOS cần Mac/Xcode, không báo iOS đạt từ build Windows |

Chạy toàn bộ suite khi thay logic dùng chung nhiều module, repository/auth/schema hoặc có nghi ngờ regression cụ thể; không lặp lại suite/build sau khi đã đạt nếu không có thay đổi hay phát hiện mới. Với refactor tài chính lớn, bắt buộc regression rộng phù hợp.

## Lệnh tham khảo (PowerShell, tại D:\app\vlxd_app)

```powershell
flutter analyze --no-pub
flutter test --no-pub test/cart_customer_test.dart
flutter test --no-pub test/shop_test.dart test/customer_book_test.dart
# Khi cần suite rộng:
flutter test --no-pub
# Chỉ khi thay dependency mới cần pub get; không tự upgrade.
```

Rules và integration luôn dùng project demo, không dùng project thật:

```powershell
$env:JAVA_HOME = (Resolve-Path '.tools/jdk21/jdk-21.0.13+9').Path
$env:Path = "$env:JAVA_HOME/bin;$env:Path"
firebase emulators:exec --only firestore,auth --project demo-vlxd-tests --config firebase.emulator.json "node --test tools/security-tests/rules.test.mjs"
# Chạy riêng khi thay luồng đồng bộ/phiên và máy có Windows toolchain:
firebase emulators:exec --only firestore,auth --project demo-vlxd-tests --config firebase.emulator.json "flutter test integration_test/firebase_sync_test.dart -d windows"
```

Lệnh chạy/build chỉ khi nhiệm vụ cần:

```powershell
flutter run -d chrome --no-pub
flutter run -d chrome --dart-define=DEMO_MODE=true --no-pub
flutter build web --no-pub
flutter build apk --debug --no-pub
flutter build windows --release --no-pub
```

Flutter hiện có ở `C:\src\flutter\bin\flutter.bat` nếu PATH thiếu; Dart format ở `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe`. Không sửa biến môi trường hệ thống chỉ để chạy một lệnh. Công cụ chưa có/quyền bị chặn thì báo đúng giới hạn, không coi là kiểm tra thành công.

## Tài liệu và kết thúc tác vụ

- PROJECT_STATUS.md theo dõi trạng thái hiện tại, phát hiện, quyết định, nhóm việc và bằng chứng. Các báo cáo trong docs là bằng chứng theo từng thời điểm; khi mâu thuẫn phải ghi nguồn/ngày, không âm thầm coi báo cáo cũ là hiện trạng.
- Cập nhật đúng mục liên quan sau mỗi tác vụ; không đọc/viết lại toàn bộ tài liệu. Phân biệt: có mã, qua test, build được, deploy được, đã nghiệm thu thiết bị/thực tế.
- Báo cáo ngắn: đã làm gì; file thay đổi; kiểm tra đã chạy và kết quả; điều chưa kiểm tra/vấn đề còn lại/bước tiếp. Không suy đoán lỗi chưa tái hiện là lỗi đã xác nhận.
- Nếu gặp lỗi ngoài phạm vi: ghi bằng chứng, tác động và ưu tiên vào PROJECT_STATUS; tiếp tục phần độc lập, không tự đổi kiến trúc hoặc mở thêm tác vụ để sửa.
