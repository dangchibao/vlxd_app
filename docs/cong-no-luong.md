# Công nợ và lương — cập nhật 04/11/2026

Chủ và Nhân viên bán hàng chỉnh trực tiếp, không có hộp thoại nhập mật khẩu admin hoặc phiên mở khóa. Tài xế, vị trí khác và tài khoản bị khóa vẫn không vào nghiệp vụ. Quản lý quyền và khóa tài khoản người khác vẫn chỉ dành cho Chủ.

- Nút ⚙ cạnh Thêm khách hàng: chọn khách, nhập tổng Phải thu/Đã thu và lý do điều chỉnh. Còn nợ = Phải thu − Đã thu. Chênh lệch được ghi vào sổ và nhật ký, không sửa hóa đơn hoặc tồn kho.
- Nút ⚙ cạnh Tạo kỳ lương: tạo kỳ mới hoặc chọn kỳ hiện có để sửa lương và tiền đã ứng/đã trả. Có thể bấm biểu tượng sửa tại dòng lương.
- Nút X đỏ cạnh sửa khách: hỏi xác nhận rồi ẩn khách khỏi danh sách. Không cho xóa khách còn nợ hoặc còn đơn giữ hàng. Hóa đơn và lịch sử vẫn được giữ; điều chỉnh thu tiền phát sinh nợ sẽ hiện lại khách.
- Từ chối số âm, Đã thu lớn hơn Phải thu và tiền ứng lớn hơn lương. Nếu dữ liệu đổi trên thiết bị khác trong lúc chỉnh, yêu cầu mở lại biểu mẫu.

Ngày 04/11/2026, sau xác nhận của Chủ, Rules mới đã triển khai thành công lên Firebase `vlxd-bay-hai`. Firebase CLI xác nhận biên dịch và phát hành thành công. Bản mới cho Chủ/Nhân viên ghi công nợ/lương và lưu trường Lưu ý sản phẩm, cho phép quy đổi chưa rõ `ratio=0`. Không sửa dữ liệu nghiệp vụ hoặc triển khai Hosting. SHA256 file phát hành: `95717C540EED3F2D2A0806007ED31A49DF8A5BD70E91314846F9D4A1E442573A`.

Kiểm tra: `flutter analyze` không có vấn đề; `flutter test` đạt 58/58; Rules emulator đạt 15/15 trên project giả `demo-vlxd-tests`. Kiểm thử giao diện xác nhận Nhân viên sửa được tổng sổ và lương qua ⚙, X đỏ có bước hủy/xác nhận; kiểm thử Rules xác nhận tài xế/tài khoản khóa vẫn bị chặn và Nhân viên không tự nâng quyền. Tất cả dùng dữ liệu giả.

`flutter build web --no-pub` đã thành công, đầu ra tại `build/web`. Chưa phát hành lên Hosting; bản Android/Windows chưa build lại cho thay đổi này.
