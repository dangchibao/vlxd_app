# Tiến độ VLXD Hai Sóc – Bảy Hải

Cập nhật: **22/11/2026**, Asia/Saigon. Đây là điểm tiếp tục công việc; kết quả cũ không thay thế kiểm tra mới.

## In hóa đơn — Giai đoạn B, 22/11/2026

- Cập nhật sau duyệt: chỉ ẩn `lines[].note` khi in A4/K80 tại `lib/ui/print_service.dart`, đổi tiêu đề cột thành `Hàng hóa`. Không xóa ghi chú gốc hoặc sửa ghi chú giao hàng/đơn hàng. Test in/hóa đơn **10/10 đạt**, analyze sạch; render và xem lại hai khổ, trích xuất PDF xác nhận không còn ghi chú sản phẩm và số lượng/đơn vị/tổng tiền giữ nguyên. Log `.qa/print-hide-notes-{tests,analyze}.log`; chưa in trên KV804.
- Đã triển khai theo duyệt mới nhất: `saleQuantity` (chuỗi thập phân chính xác) đi từ ô nhập → giỏ/nháp/Outbox → checkout; dòng đơn mới lưu thêm `salePrice` (đơn giá theo đơn vị bán, đủ phần lẻ). Cả hai tùy chọn; payload cũ không bị bổ sung trường khi đọc/ghi lại. Không nâng version DB, không migration hoặc sửa dữ liệu lịch sử.
- Giữ nguyên `area`, giá cơ sở, phân bổ lô, quy tắc làm tròn theo sản phẩm và thành tiền đã chốt. In sử dụng snapshot gốc; đơn giá quy đổi không làm tròn về VND trước khi hiển thị. Chênh lệch làm tròn/phân bổ ở từng dòng được ghi rõ `Làm tròn: ±… đ`, không ghi lại tiền vào chứng từ. Phiếu tạm áp dụng cùng phân bổ phần dư như checkout để tổng dòng khớp tổng phiếu.
- Dòng cũ thiếu snapshot: cảnh báo trong ứng dụng/kiểm tra trước in trực tiếp; để trống SL/ĐVT/đơn giá chưa xác định. Không suy từ lượng kho hoặc sản phẩm hiện tại, không in cảnh báo kỹ thuật lên phiếu khách. Thiếu tên khách gốc thì dùng nhãn chung; không lấy hồ sơ khách hiện tại để in lại.
- K80/A4 dùng chung formatter/tổng tiền và có lựa chọn khổ trong preview. Ghi `Tổng đã thanh toán`, `Còn nợ đơn này`; không gán thành tổng nợ khách. Dữ liệu hiện chưa có snapshot đáng tin cậy cho phương thức thanh toán/tiền khách đưa/tiền thừa/từng loại cọc, nên không tự dựng các mục này.
- File nghiệp vụ: `lib/domain/{shop,unit_rules}.dart`, `lib/controllers/shop_controller.dart`, `lib/data/sync/{offline_checkout_command,firebase_checkout_dispatcher}.dart`; UI/in: `lib/ui/{sales,invoices,print_service}.dart`. Tận dụng font offline và bố cục đã sửa ở lượt trước; không thay Rules, Auth hoặc kiến trúc đồng bộ trong lượt in này.
- Regression: thêm `test/invoice_snapshot_test.dart`; cập nhật `test/{print_layout,cart_draft_controller,sales_live_quantity,sales_offline_button}_test.dart`. Toàn suite **273/273 đạt**; sau đó bổ sung ca từ chối snapshot không hợp lệ, tên cửa hàng Hai Sóc và assertion đi qua UI/Outbox: **19/19 test liên quan đạt**. Analyze và diff whitespace đạt. Log: `.qa/invoice-snapshot-{suite,extra,analyze-final}.log`.
- Đã render và xem A4/K80: tiếng Việt, đơn vị phụ/chính, số lẻ, đơn giá quy đổi, dòng cũ thiếu đơn vị và làm tròn; A4 60 dòng chia 4 trang có header/footer, không tràn/cắt. Đối chiếu PDF bằng pypdf: snapshot, giảm giá/phí giao, đã thu/nợ trùng nhau giữa hai khổ; Hai Sóc không mang tên/điện thoại Bảy Hải. Mẫu tại `output/pdf/`, PNG kiểm tra tại `.qa/print-preview/` (không đưa lên Hosting).
- Chưa nghiệm thu máy in KV804, driver/lề thực tế hoặc điện thoại; chưa chạy lại integration hai client cho trường tùy chọn (unit/widget/serialization đã kiểm tra). Không tạo giao dịch thật, sửa đơn cũ, deploy, build setup hay push. Các mục rà soát bên dưới là kết quả theo thời điểm, không thay thế kết quả in mới này.

## Hiện trạng đã đối chiếu với source

- Flutter/GetX; SessionController quản lý Firebase Auth/hồ sơ, ShopController điều phối ShopData và repository. UI dùng part của lib/ui/app.dart, giữ nguyên kiến trúc.
- Firestore là nguồn xác nhận chứng từ thật. Drift/SQLite đã triển khai cho nháp, cache theo UID có hạn 48 giờ và Outbox bán hàng/nhập kho/thu nợ. Không phải mọi nghiệp vụ đều ghi offline.
- Auto-sync foreground kiểm tra 20 giây, yêu cầu phiên hợp lệ và xác minh server; lỗi/xung đột/bán âm cần xử lý theo luồng sẵn có. Khi đóng app không cam kết đồng bộ.
- Chọn Hai Sóc/Bảy Hải trước đăng nhập. Bảy Hải: stores/bay-hai + users; Hai Sóc: stores/hai-soc + members. Auth persistence, local DB/outbox và dữ liệu nghiệp vụ tách theo cửa hàng/generation.
- Đã có sản phẩm/ảnh/đơn vị tự nhập/quy đổi phụ, bán hàng/cọc/giảm giá, kho/lô, công nợ, giao hàng, hóa đơn A4/80mm, barcode và báo cáo. Source hiện còn có trả toàn bộ đơn; đây là mã có trước lượt rà soát, không tự thêm hoặc xóa.
- ProcurementDraftBook mới là domain thử nghiệm, chỉ được import từ test; chưa nối UI/kho/công nợ nhà cung cấp. Không coi là tính năng đã phát hành.
- Không suy test/build thành công thành nghiệm thu iPhone, máy in hoặc nghiệp vụ thực tế.

## Lượt rà soát 22/11

Phạm vi: entry point, tài khoản/phân quyền, giao dịch/revision, Outbox/cache/nháp, luồng tiền/đơn vị, PDF, scripts/build và bản đồ source/test. Giả định vài nhân viên đồng thời tại hai cửa hàng. Không đọc từng dòng mọi màn hình, SDK, binary hoặc các bản sao lịch sử.

| Việc | Kết quả |
| --- | --- |
| Xóa lùi/xóa tiến tại dấu cách phân nhóm tiền | Tái hiện bằng test thất bại; sửa formatter dùng chung, giữ con trỏ/IME và xóa vùng chọn |
| Đơn vị quá giới hạn Firestore 40 ký tự | Chặn giá trị thực sự được serialize tại saveProduct, trước khi thay shop/audit; kiểm tra cả alias có nhiều khoảng trắng |
| Script kiểm tra Web báo auto-sync tắt nhưng build bật | Thêm DisableAutoSync vào builder; verify-offline truyền cờ đúng; không đổi mặc định auto-sync của app |
| RunBrowserQa trỏ script .qa không có trong Git | Dừng trước build, báo rõ và hướng sang integration test hiện có |
| Rác bộ vá/source sao chép | Xóa 206 file overlay/script cũ đã có lịch sử Git và 8 bản sao/README vá/metadata thừa; không xóa tính năng đang được gọi |
| Sắp xếp | Gom thư mục bản sao còn giữ vào backup/legacy-patches; giữ APK tại release/packages; không chia lại UI/domain hoặc tạo framework |
| Cấu hình | VS Code dùng workspaceFolder; analyzer bỏ qua backup; gitignore chặn bản vá/bản sao/bộ cài mới. File release đã được theo dõi trước vẫn thuộc Git cho đến khi xử lý riêng |
| Tài liệu | README viết lại theo dự án thật; AGENTS sửa thông tin SQLite, hai cửa hàng và đường dẫn SDK/JDK đã lỗi thời |
| Cache | Dùng flutter clean, sau đó pub get --offline; giữ nguyên lockfile, không nâng dependency. Dung lượng build trước dọn khoảng 11.0 GiB, .dart_tool khoảng 642 MiB |

Bản sao dữ liệu, .qa, assets/design, generated app_database.g.dart và bộ cài đã giữ. Không commit/push, deploy, seed/reset/migrate, truy cập dữ liệu production hay đổi mật khẩu trong lượt này.

## Kiểm tra của lượt này

- Baseline: analyze đạt, 255/255 Flutter test đạt.
- Test tái hiện trước sửa: 3 ca thất bại đúng lỗi; sau sửa formatter/đơn vị: 9/9 ca liên quan đạt. Kiểm tra alias đơn vị được bổ sung cùng test giới hạn.
- Regression toàn suite ở lượt sửa đầu: 262/262 đạt. Sau khi bổ sung kiểm tra đơn vị theo đúng chuỗi serialize, chạy lại 9/9 test liên quan và analyze đều đạt. Kết quả ở các log bên dưới.
- Rules Emulator: **17/18 đạt**, duy nhất ca nhân viên sửa lương thất bại. Không đổi test để che lỗi và không tự đổi chính sách quyền.
- PowerShell scripts parse đạt; builder được kiểm tra bằng stub cho cờ bật/tắt và tổ hợp cờ sai, không chạy build/deploy thật.
- Chưa chạy integration Windows, build release, điện thoại/máy in, đo tải/quota hoặc restore thực tế trong lượt này. Không đổi giao thức Auth/sync/schema.
- Bằng chứng cục bộ: .qa/review-20261122-{analyze-final,tests-final,targeted-final,rules,clean,pub-get}.log; không đưa .qa lên Hosting/Git.

## Vấn đề và nâng cấp cần duyệt

| ID / ưu tiên | Bằng chứng và tình huống cụ thể | Hướng xử lý / nghiệm thu |
| --- | --- | --- |
| R1 / P1 | AGENTS ghi Chủ và Nhân viên được sửa lương; domain setSalary, UI history/finance_settings/debt và Rules payroll hiện chỉ cho Chủ. Rules test nhân viên bị từ chối | Chốt một chính sách trước; sửa đồng bộ UI/domain/Rules/test, kiểm thử cả hai cửa hàng và vai trò bị chặn; deploy phải duyệt riêng |
| F02 / P1 | FirestoreRepository._read tải đủ 8 collection + meta trước/sau; watch/load/transact lặp lại khi revision đổi. Lịch sử/ảnh càng nhiều, càng nhiều reads mỗi thiết bị | Đo baseline hai máy, rồi đề xuất đồng bộ tăng dần/phân trang có checkpoint; giữ revision/idempotency, chưa tự đổi repository |
| F04 / P1 | PrintService.theme gọi PdfGoogleFonts qua mạng. Thiết bị chưa có font có thể không in PDF lần đầu khi offline | Duyệt đóng gói font có giấy phép; test PDF tiếng Việt với mạng tắt và máy KV804 |
| F07 / P1 | Rules kiểm tra vai trò/envelope và một số trường; không chứng minh toàn bộ phép tính lô/thu tiền như domain | Chốt mức tin cậy nhân viên; bổ sung test ghi trực tiếp giả số dư/lô trước thiết kế gia cố. Không coi client validation là bảo mật server tuyệt đối |
| F08 / P1 | Có công cụ backup/verify/restore-staging ở tools/vlxd_backup_safe, nhưng lượt này chưa diễn tập khôi phục và Auth không thuộc JSON nghiệp vụ | Duyệt diễn tập trên staging trống, so khớp tồn/nợ/chứng từ, ảnh và tài khoản; không restore vào kho thật |
| R2 / P1 | .firebaserc mặc định open-loyalty-app, trong khi firebase_options trỏ vlxd-bay-hai; chạy Firebase thiếu --project có thể nhắm nhầm project | Mọi lệnh phải chỉ rõ project; cần duyệt việc sửa alias mặc định. Lượt này giữ nguyên IDs/config thật |
| R3 / P2 | pubspec version 1.0.0+1; nhiều bộ cài đặt tên 1.0.x ở release, Android cấu hình ký debug | Duyệt version/build number và khóa ký release, thử nâng cấp giữ DB trên thiết bị; không tự tạo khóa hay ký phát hành |
| R4 / P2 | ProcurementDraftBook chỉ có test; material_ui là dependency trực tiếp chưa thấy import trong lib/test/integration, nhưng có thể còn dependency bắc cầu của SDK | Chốt giữ/xóa phần thử nghiệm và dependency sau dependency audit/build. Không xóa cả package chỉ vì không thấy một import |

F06: source hiện yêu cầu Chủ cho bán âm; không tự thay quyền này hoặc thêm luồng duyệt đơn lớn. Các nhận định F01/F03 “chưa có SQLite/nháp bền vững” từ 04/11 đã lỗi thời, được thay bằng hiện trạng trên.

## Tools, skills và MCP hiện có

- Kiểm kê metadata của **300 tool** được cung cấp trong phiên: built-in 13; Codex desktop 50; GitHub 89; Ad Superpowers 51; ChatGPT Space 39; Sites 25; Pets 11; Plugin Management 6; Safety 5; Artifact Session 3; Document Control 3; Node REPL 3; Search 1; Hotline 1.
- Config cục bộ .codex/config.toml có MCP node_repl; gọi JavaScript tối thiểu đã chạy được. Danh sách tool khả dụng không chứng minh quyền đăng nhập hay sức khỏe mọi dịch vụ; không gọi API quảng cáo/email/ghi GitHub chỉ để thử.
- Skills có nhóm Dart/Flutter (test, analyze, layout, integration, dependency...), Ponytail (audit/review/lean), computer-use, tài liệu/PDF/bảng tính/slide, visualize, plugin-management, Sites/Pages, cloud-environment, OpenAI docs và Ad Superpowers/Pets. Chỉ đọc/áp dụng skill liên quan, không cài thêm.
- Dùng Ponytail cho rà soát/sửa gọn, Plugin Management để kiểm kê; Dart unit-test và static-analysis để kiểm tra. Dart/Flutter MCP, LSP runtime tools, Graphify và Superpowers chuyên lập trình không xuất hiện trong tool inventory, nên dùng CLI có sẵn.
- Flutter 3.50.0 / Dart 3.14.0 ở D:/development/flutter; JDK 21 ở D:/jdk21. PATH terminal chưa sẵn Flutter/Firebase nên truyền PATH tạm theo README; không sửa cài đặt máy/global permissions.

## Tiếp tục lần sau

1. Đọc tài liệu này và git diff hiện tại; có nhiều xóa bộ vá lịch sử, không nhầm là xóa runtime.
2. Chốt R1 quyền lương và R2 alias Firebase trước; không tự deploy bản sửa này.
3. Với nhiệm vụ nhỏ chỉ đọc module/test trong bảng README. Source: main → controllers → domain/data → UI; không đọc backup/build/Pub cache để tìm code đang chạy.
4. Giữ tiền nguyên VND, lượng 1/10.000, snapshot hóa đơn và revision/requestId. Không xóa Outbox hoặc reset DB để giải quyết test.
5. Các lần phát hành/reset trước (10–14/11) là lịch sử; không suy ra production hiện còn dữ liệu như lúc đó. Source/tài liệu 15–22/11 có bản vá mới hơn; lượt này không xác minh lại dữ liệu thật.
