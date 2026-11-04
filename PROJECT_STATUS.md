# Trạng thái dự án VLXD Bảy Hải

Cập nhật: 04/11/2026 (Asia/Saigon). Tài liệu được khởi tạo qua rà soát có chọn lọc; các tác vụ tiếp theo được ghi tại mục 8. Không tự coi kết quả kiểm thử cũ là kiểm tra của lượt mới.

## 1. Kết luận hiện tại

- Đã có ứng dụng Flutter/GetX với nghiệp vụ bán hàng, kho, công nợ, hóa đơn và tài khoản; không phải dự án khởi tạo mới.
- Production hiện dùng Firebase Auth + Firestore trực tiếp. **Chưa có SQLite hoặc offline-first cho dữ liệu thật.** SharedPreferences chỉ phục vụ bản demo và một số cấu hình.
- Mục tiêu mới: Windows/Android/iOS, SQLite cục bộ + đồng bộ Firestore, ưu tiên Spark. Đây là hướng cần thiết kế và duyệt trước, chưa phải kiến trúc đã triển khai.
- Chưa đủ căn cứ xác nhận sẵn sàng vận hành production trên cả ba nền tảng. Chưa nghiệm thu iPhone, máy in và mất mạng thực tế.
- Không thay database, schema, phân quyền hoặc viết lại module đang hoạt động trong lượt lập kế hoạch.
- Phạm vi mới đã xác nhận: giữ sync engine cho đơn hàng/kho/công nợ cùng các phần hoàn thiện đã đề xuất; **không thêm khách trả/đổi hàng hoặc xuất kho không bán**. SQLite và Firestore cần được đánh giá như hai tầng local/cloud trong G0, không thay thế tùy tiện hoặc kết nối trực tiếp từ widget. Lượt sửa giao diện không triển khai sync engine/migration.
- Đánh giá sơ bộ cho G0: UI đọc dữ liệu local qua repository/GetX; SQLite lưu chứng từ/nháp/outbox, sync engine đối soát và chuyển thay đổi với Firestore. Không cho widget tự quyết định ghi SQLite hay Firestore theo từng ô nhập. Đây là phương án đề xuất cần chốt cơ chế xung đột và migration, không phải sync engine đã hoàn tất.

## 2. Bản đồ đọc mã theo nhiệm vụ

| Phần | Điểm vào / trách nhiệm hiện tại |
| --- | --- |
| Khởi động | `lib/main.dart`: Firebase, chọn demo/live/emulator, cửa sổ desktop |
| Đăng nhập / phiên | `lib/controllers/session_controller.dart`, `lib/ui/authentication.dart`, `lib/ui/accounts.dart` |
| Trạng thái nghiệp vụ | `lib/controllers/shop_controller.dart`: giỏ, lưu giao dịch, nhận snapshot, chuyển trang |
| Lưu dữ liệu | `lib/data/demo_repository.dart`: interfaces + demo SharedPreferences; `lib/data/firestore_repository.dart`: đọc/ghi live |
| Domain | `lib/domain/shop.dart`: sản phẩm/lô, tiền, xuất nhập, giữ đơn, thu nợ, chỉnh sổ/lương; `invoice_filter.dart` |
| UI dùng chung | `lib/ui/app.dart` và các file `part`: theme, dialog, bố cục; `shell.dart`: điều hướng |
| Sản phẩm / bán hàng | `catalog.dart`, `sales.dart` |
| Công nợ / lương | `debt.dart`, `finance_settings.dart`, các dialog trong `operations.dart` / `history.dart` |
| Kho / giao / báo cáo / nhật ký | `operations.dart`, `audit_text.dart` |
| Hóa đơn / PDF | `invoices.dart`, `print_service.dart`, `history.dart` |
| Quyền máy chủ | `firestore.rules`, `firebase.emulator.json`, `tools/security-tests/` |
| Kiểm thử | `test/` theo tính năng; `integration_test/firebase_sync_test.dart` |

UI hiện chia bằng `part of 'app.dart'`; domain còn dùng `Json` cho nhiều chứng từ. Đây là hiện trạng cần tôn trọng, không tự đổi toàn bộ sang kiến trúc/model khác.

## 3. Tính năng và mức hoàn thiện

“Có mã + test” nghĩa là có bằng chứng triển khai và kiểm thử tương ứng, không đồng nghĩa nghiệm thu trên thiết bị thật.

| Nhóm | Trạng thái | Bằng chứng / phần còn thiếu |
| --- | --- | --- |
| Đăng nhập Auth, hồ sơ quyền, khóa phiên, đổi mật khẩu | Có mã + test | SessionController, accounts, shop_test, integration test. Reset mật khẩu người khác mới có công cụ Admin SDK, chưa có luồng UI hoàn chỉnh |
| Sản phẩm, giá, ảnh, Lưu ý, quy đổi tùy chọn | Có mã + test | catalog, shop.saveProduct, product_notes_test, sales_product_actions_test. Ảnh nhỏ đang nằm trong Firestore; chưa có kho ảnh offline |
| Bán hàng, giỏ, khách mới tại đơn, đơn vị m²/m³ | Có mã + test | sales, shop.checkout, cart_customer_test/cart_refresh_test. Chưa có giỏ bền vững qua khởi động lại |
| Giữ đơn/cọc, xuất/hủy giữ, chống chốt trùng | Có mã + test | ShopData, requestId/revision và Rules; shop_test, integration test. Chưa có idempotency/outbox bền vững offline |
| Kho, nhập lô, kiểm kê có ảnh, tồn thấp/tồn lâu | Có mã + test nghiệp vụ một phần | domain + InventoryPage; tuổi lô/ngưỡng đã có. Sửa/xóa lô, đối soát lô âm, kiểm kê nhiều thiết bị còn cần hoàn thiện/nghiệm thu |
| Khách, công nợ, thu/sửa lần thu, chỉnh tổng sổ | Có mã + test | customer_book_test, finance_settings_test, debt_view_test. Chứng từ cũ giữ nguyên; chưa có test đồng bộ offline |
| Lương | Có tạo/sửa tổng kỳ và số đã ứng | setSalary/createPayroll. Chưa có sổ từng lần chi/đảo chi lương riêng |
| Giao hàng | Có tạo/sửa, ảnh, phí chuyến, hoàn tất | DeliveriesPage/editDelivery/finishDelivery. Tiêu đề DH-* và tài xế đã chỉnh. Chưa có tính giá theo km |
| Hóa đơn và bộ lọc | Có mã + test | invoices, invoice_filter, invoices_test. Đọc từ đơn đã bán, có chi tiết và PDF; chưa nghiệm thu in thật |
| Barcode | Có sinh Code128/PDF, nhập mã/quét và xác nhận giỏ | sales/print_service/widget_test. Camera và máy in KV804 chưa nghiệm thu thiết bị thật |
| Báo cáo | Một phần | ReportsPage: top m² và khách nợ; chưa đủ ngày/tuần/tháng, giá vốn/lãi lỗ, tổng kết đêm |
| Nhật ký dễ đọc | Có mã + test | audit_text + audit_text_test; định dạng lịch sử tại UI, bản gốc bất biến, log mới lưu tên người thao tác |
| Xuất sao lưu | Có CSV/JSON | exportData. Chưa có restore tổng quát, kiểm tra toàn vẹn/diễn tập phục hồi |
| Đồng bộ | Có giao dịch online so revision + audit | FirestoreRepository. Tải toàn cửa hàng; chưa tối ưu đọc tăng dần và chưa offline-first |
| Messenger / Zalo | Chưa tích hợp tự động | Sự kiện nội bộ ghi chưa gửi; PDF có thể chia sẻ thủ công. Không được báo đã gửi khi chưa có xác nhận |
| Phát hành Windows/Android/iOS | Chưa nghiệm thu đầy đủ | Có build cũ Windows/Android/Web; iOS cần Mac. Chưa có bằng chứng release mới nhất trên thiết bị thật |

## 4. Bằng chứng kiểm tra và môi trường thật

- Lượt sửa nhật ký gần nhất trong chat: `flutter test --no-pub` **65/65 đạt**, `flutter analyze --no-pub` không có vấn đề. Lượt này không chạy lại; không coi là kiểm thử offline-first hoặc iOS.
- Rules emulator gần nhất: **15/15 đạt**, project giả `demo-vlxd-tests`, trước thay đổi hiển thị nhật ký/tên người thao tác. Xem `tools/security-tests/rules.test.mjs`, `docs/cong-no-luong.md`.
- Integration Windows từng thành công theo `docs/ket-qua-kiem-tra-firebase.md`. Assertion payroll đã cập nhật theo quyền mới; chưa có kết quả chạy lại toàn kịch bản cho bản hiện tại. Không dùng kết quả cũ chứng minh quyền payroll mới đã qua integration.
- Build Web gần nhất thành công trước hai lượt sửa khách tại đơn và nhật ký. Build Android/Windows là kết quả cũ, chưa chứng minh mã hiện tại build được trên các nền tảng đó. Chưa build/ký iOS.
- Rules đã phát hành lên `vlxd-bay-hai` ngày 04/11/2026 sau xác nhận riêng; SHA256: `95717C540EED3F2D2A0806007ED31A49DF8A5BD70E91314846F9D4A1E442573A`. Nguồn: `docs/cong-no-luong.md` và kết quả CLI trong chat. Không truy cập lại project thật ở lượt lập kế hoạch này.
- Project thật đã có tài khoản và 4 sản phẩm MAU-* được nhập theo yêu cầu trước đó; người dùng đã thao tác tạo dữ liệu. **Không coi kho là trống, không tự seed/reset/migrate.**
- `git status` cho thấy nhiều thư mục mã còn untracked; không tự clean/reset/checkout hoặc diễn giải mọi file untracked là do tác vụ hiện tại tạo.

## 5. Phát hiện có bằng chứng

Phân biệt thiếu tính năng/giới hạn thiết kế với lỗi đã tái hiện; lượt này không chạy app để tái hiện lỗi mới.

| ID | Loại / ưu tiên | Bằng chứng rõ ràng | Ảnh hưởng / hướng xử lý |
| --- | --- | --- | --- |
| F01 | Khoảng cách kiến trúc / P0 | pubspec chưa có SQLite; main tắt native persistence; repository dùng Source.server; controller chặn khi lỗi đồng bộ | Dữ liệu thật chưa hoạt động offline; thiết kế local DB/outbox trước khi lập trình |
| F02 | Chi phí/hiệu năng / P0 | FirestoreRepository._read đọc toàn bộ 8 collection cùng meta trước/sau; watch gọi load khi meta đổi; transact đọc lại | Reads/băng thông và bộ nhớ tăng theo lịch sử, ảnh, số máy; cần baseline đo và đồng bộ tăng dần có checkpoint |
| F03 | Rủi ro mất nháp / P1 | cart/requestId trong bộ nhớ ShopController; clearSession xóa, chưa có lưu nháp production | Giỏ và mã thử lại không bền qua restart. Chưa thấy lỗi mất chứng từ đã commit; cần draft/outbox durable cho offline |
| F04 | Phụ thuộc mạng / P1 | PrintService.theme tải PdfGoogleFonts Noto; ảnh base64 nằm cùng tài liệu đồng bộ | PDF lần đầu chưa bảo đảm offline; cần font đóng gói và thiết kế cache ảnh |
| F05 | Sai lệch tài liệu xác nhận / P0 | README còn nói Rules chưa deploy, chưa có dữ liệu thật và NV không sửa lương; docs/cong-no-luong ghi trạng thái mới | Dùng trạng thái mới ở đây và quyết định người dùng; lên tác vụ sửa các tài liệu cũ, không sửa âm thầm quyền theo README |
| F06 | Quy tắc cần xác nhận / P0 | shop.checkout hiện cho staff bán vượt tồn nếu có lý do; yêu cầu ban đầu chỉ Chủ duyệt âm, yêu cầu sau cho NV cùng quyền nghiệp vụ | Chưa kết luận là bug phân quyền. Chốt riêng quyền bán âm và duyệt đơn lớn trước khi sửa |
| F07 | Giới hạn tin cậy / P0 | Rules bảo vệ hồ sơ/envelope/audit/immutable fields nhưng không chứng minh toàn bộ phép tính lô/thu tiền; cờ đổi mật khẩu do client cập nhật | Cần xác định mô hình đe dọa và mức tin cậy NV; không tuyên bố client validation là bảo vệ máy chủ tuyệt đối |
| F08 | Thiếu phục hồi / P1 | exportData có xuất; importLocalDemo chỉ nhập vào kho trống, không phải restore tổng quát | Chưa có quy trình phục hồi đầy đủ, đặc biệt Auth không nằm trong JSON |
| F09 | Thiếu đối soát / P1 | Bán âm sinh lô AM-* cost=0 và allocation cost=null | Chưa có giá vốn đáng tin cho phần âm; phải hiển thị chưa xác định, không báo lãi giả |
| F10 | Kiểm chứng nền tảng / P0 | Tài liệu Firebase hiện có cảnh báo Windows native; chưa có Mac/iPhone/hardware QA | Xác minh hỗ trợ chính thức của phiên bản đang khóa trước khi cam kết Windows production; kế hoạch không tự chuyển REST/SDK/database |

## 6. Các quyết định phải chốt trước thay đổi kiến trúc

1. Offline cho phép xem, giữ giỏ hay cả ghi sổ bán/thu nợ/kiểm kê? Đăng nhập lần đầu và cấp/thu hồi quyền offline được xử lý thế nào?
2. Hai máy cùng offline không thể biết tồn mới nhất của nhau. Chọn hạn mức tồn theo thiết bị, đơn tạm chờ duyệt/đồng bộ hoặc chỉ chốt khi online; không hứa vừa chốt offline tự do vừa chống bán vượt tồn toàn cửa hàng tuyệt đối.
3. Định danh đơn liên thiết bị, thời điểm nghiệp vụ, replay, xung đột giá/lô/thu tiền, trạng thái pending/rejected/confirmed và nghiệp vụ đảo bút toán.
4. SQLite adapter/schema version/migration, ranh giới repository và bảo vệ dữ liệu cục bộ; native là ưu tiên. Web đang dùng được: giữ tương thích hay tách lộ trình, không tự bỏ Web.
5. Trần tài nguyên/ngân sách đọc ghi, kích thước dữ liệu/máy dự kiến; Spark là ưu tiên, không phải cam kết miễn phí vô hạn. Không tự bật billing/backend trả phí.
6. Chốt quyền bán âm/duyệt đơn lớn; quyền sửa công nợ/lương đã chốt thì giữ nguyên.

## 7. Nhóm công việc còn lại theo thứ tự

Mỗi nhóm là một đợt có ranh giới, có thể chia bước nhỏ; không triển khai đồng loạt. P0 trước nghiệp vụ mới, P1 trước vận hành, P2 là hoàn thiện có thể hoãn.

| Nhóm | Phụ thuộc / ưu tiên | Nội dung liên quan | Tiêu chí nghiệm thu |
| --- | --- | --- | --- |
| G0 — Chốt nền tảng và baseline | P0, bước tiếp theo | Quyết định mục 6, xác minh hỗ trợ Firebase Windows từ nguồn chính thức, làm rõ tài liệu mâu thuẫn; ADR + đo đọc/ghi mẫu | Có phương án được duyệt, ma trận online/offline/quyền/xung đột và giới hạn miễn phí; baseline đo lại được; chưa migrate dữ liệu |
| G1 — SQLite và dữ liệu bền vững | P0, sau G0 | Adapter local dưới interface phù hợp hiện có, migration/version, transaction local, nháp giỏ, cache ảnh/font | Dữ liệu còn sau kill/restart; ghi tiền+tồn+outbox nguyên tử nếu cho phép ghi offline; test migration lỗi/rollback trên bản sao; không chuyển demo thành live; không sửa kho thật |
| G2 — Đồng bộ, idempotency, hiệu năng | P0, sau G1 | Outbox/inbox, trạng thái pending, checkpoint/tombstone, retry/backoff, IDs offline, auth/revocation, đối soát với server | Test hai thiết bị, mất mạng giữa ack, gửi lại, crash, máy bị khóa; không trừ tồn/thu hai lần; xung đột theo chính sách G0; số reads tăng theo dữ liệu thay đổi sau lần tải đầu, có đo ảnh và pagination; không bỏ revision hiện tại khi chưa có thay thế được chứng minh |
| G3 — Hoàn thiện bán/kho/công nợ/lương | P1, sau G0; dùng G2 khi offline | Xác nhận ngoại lệ bán âm, chỉnh lô an toàn, sổ từng lần chi lương, nghiệp vụ điều chỉnh đã có; không thêm trả/đổi hàng hoặc xuất kho không bán | Chứng từ truy được lô/lần thu/lần chi; không sửa lịch sử để làm khớp; nhập/bán/giữ/hủy/kiểm kê đối chiếu số dư; số tiền âm/sai đơn vị bị chặn; đồng thời không ghi đè |
| G4 — Sao lưu và phục hồi | P1, sau schema G1; trước migrate thật | Versioned export/import, ảnh, manifest/checksum, dry-run, quyền và quy trình restore, backup trước migration | Diễn tập export → DB trống → so khớp tồn/nợ/đơn/ảnh; từ chối file hỏng/sai schema; retry không nhân đôi; không ghi đè dữ liệu thật; nêu rõ Auth/credential không thuộc backup nghiệp vụ |
| G5 — PDF, barcode, giao hàng | P1 | Font offline, logo/thông tin cửa hàng, phí theo km/chuyến, KV804/camera và chia sẻ | PDF tiếng Việt offline đúng số liệu; quét phải xác nhận trước giỏ; in test trên KV804, Android/iPhone theo kết nối được hỗ trợ; hoàn tất chuyến lặp không phát sinh thu/chi mới |
| G6 — Báo cáo và đối soát | P1, sau G3 | Ngày/tuần/tháng, doanh thu khác thực thu, giá vốn FIFO/lô âm, chi vận chuyển/lương, tổng kết | Bộ dữ liệu có đáp án đối chiếu; cọc/thu nợ không tính doanh thu hai lần; hiển thị giá vốn chưa rõ; biên ngày múi giờ cửa hàng đúng; truy được chứng từ |
| G7 — Thông báo nội bộ | P2, sau xác minh API và quyền | Xác minh kênh Messenger qua Fanpage bằng tài liệu chính thức; queue chống trùng, tổng kết đêm khi có hạ tầng phù hợp | Chỉ nhóm nội bộ đã được phép; không đọc hội thoại/nhắn khách; không báo gửi thành công trước ack; lỗi gửi không mất đơn; phương án không thêm phí phải chứng minh, không hứa tác vụ đêm luôn chạy trên thiết bị đang tắt |
| G8 — Nghiệm thu và phát hành | P1, sau nhóm bắt buộc | Android/Windows build hiện tại, iOS ký trên Mac, kiểm tra offline/phục hồi/hiệu năng/quyền/hardware; checklist bản phát hành | Mỗi nền tảng có phiên bản, kết quả và artifact; backup/rollback dùng được; test theo vai trò và mất mạng; không suy build thành công = sản phẩm đã nghiệm thu |

## 8. Theo dõi tác vụ

| Tác vụ | Trạng thái | Kết quả |
| --- | --- | --- |
| Rà soát chọn lọc và tạo hai tài liệu gốc | Hoàn tất lượt kế hoạch | PROJECT_STATUS.md + AGENTS.md; không đổi source/config/data |
| Cập nhật số lượng không cần mất focus | Hoàn tất | `confirmProduct` trước đây chỉ đọc qty khi xác nhận, thiếu phần hiển thị tiền theo thay đổi controller. Test trước sửa thất bại ở 390/1440; thêm ValueListenableBuilder cho số lượng quy đổi/thành tiền/tổng tiền hàng dự kiến. Không ghi giỏ/kho/Firestore theo phím; giữ controller, selection, composing, Lưu ý. 5 test mới đạt; toàn bộ `flutter test --no-pub` đạt 70/70; `flutter analyze --no-pub` không có vấn đề. File: `lib/ui/sales.dart`, `test/sales_live_quantity_test.dart`, tài liệu này |
| G0 | Chưa bắt đầu triển khai | Đề nghị là tác vụ tiếp theo; chưa có ADR được duyệt |
| G1–G8 | Chưa triển khai theo kế hoạch mới | Không diễn giải các nhóm là cam kết đã làm |

Sau mỗi tác vụ: cập nhật đúng hàng/phát hiện/bằng chứng liên quan; ghi file đổi, kiểm tra đã chạy, giới hạn và bước tiếp. Chỉ đọc thêm module khi có dependency thực sự.

Ghi chú điều tra UI: đã kiểm tra field helper, controller, sự kiện và GetBuilder tại sales/shell. Không tìm thấy nhánh onFocusChange/onEditingComplete trì hoãn tính tiền; onSubmitted chỉ dùng kết thúc nhập mã vạch. Chọn sản phẩm sau xác nhận, nút +/- và phí giao hàng có kiểm thử cập nhật ngay; không khẳng định đã tái hiện một lỗi blur chung của mọi màn hình. Thay đổi lần này bổ sung phản hồi trực tiếp cho số lượng đang soạn, không tự thêm sản phẩm khi người dùng chưa xác nhận. Chưa kiểm tra thủ công thiết bị thật/build release cho lượt sửa này.

