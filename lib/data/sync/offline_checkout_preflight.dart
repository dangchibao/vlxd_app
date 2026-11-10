import 'offline_checkout_command.dart';
import '../../domain/shop.dart';

/// Pure local validation. This does not authorize a sale or replace the
/// server-side price, inventory, role and idempotency checks.
class OfflineCheckoutPreflight {
  static String? invalidReason(OfflineCheckoutCommand command) {
    if (command.requestId.trim().isEmpty ||
        command.requestId != command.requestId.trim() ||
        command.requestId.contains('/')) {
      return 'Mã giao dịch không hợp lệ.';
    }
    if (command.actorId.trim().isEmpty) {
      return 'Thiếu tài khoản.';
    }
    if (command.lines.isEmpty) {
      return 'Đơn không có sản phẩm.';
    }
    if (command.paid < 0 || command.ship < 0 || command.discount < 0) {
      return 'Số tiền, phí giao hàng và giảm giá không được âm.';
    }
    if (command.createdAt.isAfter(
      DateTime.now().toUtc().add(const Duration(days: 1)),
    )) {
      return 'Ngày tạo đơn nằm quá xa trong tương lai.';
    }
    final quantities = <String, int>{};
    final prices = <String, int>{};
    for (final line in command.lines) {
      if (line.productId.trim().isEmpty || line.area <= 0) {
        return 'Mã sản phẩm hoặc số lượng không hợp lệ.';
      }
      if (!line.quotedPrice.isFinite ||
          line.quotedPrice < 0 ||
          line.quotedPrice % 1 != 0 ||
          !line.quotedRatio.isFinite ||
          line.quotedRatio < 0) {
        return 'Giá hoặc quy đổi không hợp lệ.';
      }
      final price = line.quotedPrice.toInt();
      if (prices.containsKey(line.productId) &&
          prices[line.productId] != price) {
        return 'Cùng sản phẩm có nhiều đơn giá.';
      }
      prices[line.productId] = price;
      quantities.update(
        line.productId,
        (n) => n + line.area,
        ifAbsent: () => line.area,
      );
    }
    final goods = quantities.entries.fold<int>(
      0,
      (total, line) => total + lineMoney(line.value, prices[line.key]!),
    );
    if (command.discount > goods ||
        command.paid > goods - command.discount + command.ship) {
      return 'Giảm giá hoặc số tiền đã thu không hợp lệ.';
    }
    if (command.customerId.trim().isEmpty &&
        (command.hold ||
            command.paid != goods - command.discount + command.ship)) {
      return 'Chọn khách hàng khi giữ đơn hoặc còn phải thu.';
    }
    return null;
  }

  static bool isValid(OfflineCheckoutCommand command) =>
      invalidReason(command) == null;
}
