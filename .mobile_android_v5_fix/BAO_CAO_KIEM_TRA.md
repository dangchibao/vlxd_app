# Báo cáo rà soát Mobile Web/PWA V4

## Nguồn
- Dựa trên 6 file UI thực tế người dùng gửi 21/11/2026 và overlay đã cài thành công bản UI V3 (255 tests theo log người dùng).
- Đối chiếu ảnh Safari iPhone: nút thêm màu xanh trùng nền; menu dấu ba chấm chứa các câu quá dài, thiếu icon; hành động nhập kho có ký hiệu chưa phân biệt tốt.

## Những thay đổi thực tế của bản ZIP
- `mobile_products.dart`: nút thêm sản phẩm nền xanh rất nhạt, icon xanh đậm; bộ lọc xám đậm; nhập kho có khung sáng và icon kiện hàng có dấu cộng.
- Popup menu của Hàng hóa: menu có độ rộng giới hạn 196–232 px và bo góc; mọi mục đều có icon màu/nhãn ngắn: Chi tiết, Đính chính, Sửa, Mã vạch & In, Ngừng bán; khôi phục/hiện lại/bán lại vẫn giữ nguyên hành động.
- `debt.dart`: trên điện thoại nút thêm khách là icon có tooltip; menu khách có icon Sửa/Xóa với nhãn ngắn. Desktop vẫn nút chữ như cũ.
- Chỉ đổi widget/hình thức hiển thị; toàn bộ `value`, `onSelected`, callbacks và kiểm tra quyền Admin được giữ nguyên.

## Phạm vi chưa xác thực
- 6 file UI người dùng gửi không phải toàn bộ source hiện hành. Không thay đổi mobile_sales.dart, delivery, invoice, reports, settings vì không có snapshot mới nhất của các file này.
- Mã nguồn chỉnh trong ZIP chưa được biên dịch Flutter tại môi trường tạo ZIP; chính script người dùng chạy sẽ kiểm tra/analyze/test/rollback. Test pass không thay thế kiểm tra trực quan trên 320px/390px/430px.
- Cần kiểm tra PWA qua HTTPS, đăng nhập Firebase Auth, đồng bộ offline và camera/print phù hợp thiết bị. Không khuyên xóa cache PWA khi còn outbox chưa đồng bộ.

## Kiểm thử thủ công trước LIVE
1. Trên iPhone: Hàng hóa → thêm, lọc, nhập kho, menu icon; đối chiếu không tràn 320–430px.
2. Mỗi mục menu mở đúng hành động; nhân viên không nhìn thấy Đính chính khi không có quyền Admin.
3. Công nợ trên mobile: thêm khách, sửa, xóa (không xác nhận xóa thử dữ liệu thật).
4. Windows laptop không bị mất nút/nhãn dài; mobile không phát sinh scroll ngang.
5. Kiểm tra offline/outbox sau preview: không dùng dữ liệu thật để thử nghiệp vụ phá hủy.
