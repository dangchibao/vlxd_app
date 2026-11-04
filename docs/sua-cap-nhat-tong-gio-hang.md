# Cập nhật tổng tiền giỏ hàng

Ngày 04/11/2026. Tái hiện bằng hai kiểm thử: bấm thêm sản phẩm, xác nhận xong controller đã có dòng hàng nhưng tổng tiền desktop chưa đổi; cộng số lượng trong giỏ compact cũng không cập nhật số tiền. Cả hai kiểm thử thất bại trước sửa và qua sau sửa.

Nguyên nhân: CartPanel có state để giữ phí giao hàng/tiền đã thu/khách/giữ hàng, nhưng chỉ đọc Get.find và được gắn bằng widget const, không đăng ký cập nhật từ ShopController. Đã đặt GetBuilder trực tiếp trong state của CartPanel để dựng lại nội dung mỗi lần controller thay đổi. Không tạo lại state hay controller nhập liệu.

Kiểm thử thao tác thêm bằng nút trên thẻ và xác nhận, cộng/bớt thùng, bỏ khỏi giỏ, tính tổng có phí giao hàng, giữ phí đã nhập và giỏ compact. Không ghi giao dịch lên Firebase thật trong khi kiểm tra.
