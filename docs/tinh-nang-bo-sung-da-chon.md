# Các tính năng bổ sung đã chọn

Người dùng xác nhận ngày 03/11/2026. Đây là phạm vi yêu cầu, chưa phải chức năng đã lập trình. Chỉ bổ sung năm mục bên dưới từ danh sách đề xuất; các đề xuất đổi trả, hao hụt và cảnh báo khác lô chưa được chọn.

## 1 Tính gạch theo diện tích phòng

- Nhập chiều dài, chiều rộng theo mét và tỷ lệ hao hụt do người dùng chọn.
- Tính diện tích cần mua và số thùng theo hệ số m²/thùng của sản phẩm đã chọn.
- Làm tròn lên số thùng khi mua nguyên thùng; hiển thị diện tích thực mua và phần dư.
- Kết quả là gợi ý, chỉ thêm vào giỏ sau khi người dùng xác nhận. Chặn kích thước hoặc hệ số không hợp lệ.

## 2 Cảnh báo sắp hết hàng

- Đặt ngưỡng tồn tối thiểu cho từng sản phẩm, ghi rõ đơn vị.
- Cảnh báo trong app khi tồn khả dụng bằng hoặc thấp hơn ngưỡng; tồn khả dụng trừ lượng đang giữ.
- Không gửi SMS hoặc tự nhắn khách. Không cần dịch vụ thông báo trả phí.

## 3 Nhật ký thao tác

- Ghi người thực hiện, thời điểm, loại thao tác, đối tượng và nội dung thay đổi quan trọng: sản phẩm, giá, kho, đơn hàng, công nợ, lương và tài khoản.
- Có tìm/lọc và phân trang; không ghi mật khẩu, token hoặc khóa bí mật.
- Nhật ký được bảo vệ, không cho người dùng sửa/xóa trực tiếp; kiểm tra quyền ở phía máy chủ hoặc quy tắc dữ liệu.
- Chọn chính sách lưu và xuất nhật ký phù hợp hạn mức trước khi vận hành; chưa tự chốt thời hạn xóa.

## 4 Xuất dữ liệu sao lưu

- Cho tải CSV sản phẩm, lô/tồn kho, đơn hàng, khách hàng, công nợ và các lần thu tiền; dữ liệu lương/tài khoản xuất theo quyền.
- CSV dùng mã hóa hỗ trợ tiếng Việt, có mã liên kết giữa các bảng và thời điểm xuất.
- Đây là xuất dữ liệu, chưa bao gồm tính năng tự khôi phục hoặc bản sao đầy đủ ảnh, tài khoản Firebase Authentication và cấu hình hệ thống.
- Không xuất mật khẩu hay bí mật hệ thống; tải theo yêu cầu, không tự mua dịch vụ sao lưu.

## 5 Chống tạo đơn trùng

- Mỗi lần chốt đơn có mã yêu cầu duy nhất và được kiểm tra khi ghi dữ liệu.
- Bấm nhiều lần, mất phản hồi hoặc thử lại cùng yêu cầu chỉ tạo một đơn; không trừ tồn hoặc ghi thu tiền lần nữa.
- Khóa nút trong lúc xử lý để hỗ trợ giao diện; không chỉ dựa vào khóa nút để chống trùng.
- Đơn mới có chủ ý được cấp mã yêu cầu mới, không chặn chỉ vì có cùng khách và mặt hàng.

## Chi phí

Không thêm SMS, AI trả phí hoặc dịch vụ mua riêng cho năm mục này. Tính toán trên thiết bị khi phù hợp; các thao tác đọc/ghi/xuất dữ liệu vẫn tiêu thụ hạn mức dịch vụ miễn phí hiện có. Không cam kết mức dùng không giới hạn hoặc tự nâng gói trả phí.
