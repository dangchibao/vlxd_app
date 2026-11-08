import 'offline_checkout_command.dart';

/// Pure local validation. This does not authorize a sale or replace the
/// server-side price, inventory, role and idempotency checks.
class OfflineCheckoutPreflight {
  static String? invalidReason(OfflineCheckoutCommand command) {
    if (command.requestId.trim().isEmpty ||
        command.requestId != command.requestId.trim() ||
        command.requestId.contains('/')) {
      return 'Mã giao dịch không hợp lệ.';
    }
    if (command.actorId.trim().isEmpty || command.customerId.trim().isEmpty) {
      return 'Thiếu tài khoản hoặc khách hàng.';
    }
    if (command.lines.isEmpty) {
      return 'Đơn không có sản phẩm.';
    }
    if (command.paid < 0 || command.ship < 0) {
      return 'Số tiền hoặc phí giao hàng không được âm.';
    }
    if (command.createdAt.isAfter(
      DateTime.now().toUtc().add(const Duration(days: 1)),
    )) {
      return 'Ngày tạo đơn nằm quá xa trong tương lai.';
    }
    for (final line in command.lines) {
      if (line.productId.trim().isEmpty || line.area <= 0) {
        return 'Mã sản phẩm hoặc số lượng không hợp lệ.';
      }
      if (!line.quotedPrice.isFinite ||
          line.quotedPrice < 0 ||
          !line.quotedRatio.isFinite ||
          line.quotedRatio <= 0) {
        return 'Giá hoặc quy đổi không hợp lệ.';
      }
    }
    return null;
  }

  static bool isValid(OfflineCheckoutCommand command) =>
      invalidReason(command) == null;
}
