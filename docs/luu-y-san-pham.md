# Lưu ý và số lượng tự tính

Trạng thái: code, kiểm thử và build Web đã hoàn tất. Ngày 04/11/2026, sau xác nhận riêng của Chủ, Rules mới đã biên dịch và phát hành thành công lên `vlxd-bay-hai`, hỗ trợ lưu note và ratio=0. Không sửa dữ liệu nghiệp vụ trong lần phát triển/triển khai này.

Theo yêu cầu ngày 04/11/2026: thêm ô Lưu ý tùy chọn trong sửa/tạo sản phẩm. Người bán tự ghi số tấm, kích thước hay cách ước tính; app không phân tích nội dung để suy ra diện tích/số lượng/giá. Giá và số lượng nhập là căn cứ tính tiền.

Kích thước, nhà cung cấp, ngưỡng sắp hết và quy đổi thùng có thể để trống. Quy đổi chưa rõ lưu ratio=0, ngưỡng bỏ trống là 0. Chỉ hiện bán theo thùng khi đã có quy đổi dương; trường hợp khác nhập trực tiếp theo m² hoặc m³. Mã, tên, giá bán hợp lệ vẫn cần để tạo sản phẩm và bán hàng.

Lưu ý sản phẩm được điền sẵn khi thêm vào giỏ, có thể chỉnh riêng cho lần bán. Giới hạn 1.000 ký tự. Cộng hàng giữ các nội dung khác nhau, loại nội dung trùng; cộng/bớt số lượng giữ lưu ý. Chốt đơn chụp lại lưu ý vào từng dòng, hiển thị trên chi tiết hóa đơn và PDF/báo giá. Sửa lưu ý của sản phẩm sau này không đổi hóa đơn cũ. CSV sản phẩm có cột Lưu ý; bản sao lưu JSON giữ trường note.

Tương thích dữ liệu cũ: note thiếu được hiểu là chuỗi rỗng; quy đổi cũ dương vẫn giữ nguyên. Không cập nhật hàng loạt sản phẩm thật hoặc thay tồn kho khi thêm tính năng.

Phần Rules cho sản phẩm bổ sung trường note tùy chọn (string, tối đa 1.000 ký tự) và cho phép ratio=0. Bản Rules đã phát hành còn bao gồm cập nhật quyền công nợ/lương theo yêu cầu mới, xem cong-no-luong.md. Kiểm thử đơn vị bao gồm bán 3,6 m² do người bán tự tính và trừ đúng số lượng, lưu lịch sử notes, từ chối notes quá dài và quy đổi âm. Bộ kiểm thử mới nhất: 58 kiểm thử Flutter và 15 kiểm thử Rules emulator đều đạt; flutter analyze không có lỗi.
