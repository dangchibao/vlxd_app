import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firestore_repository.dart';
import '../local/app_database.dart';
import '../../domain/shop.dart';
import 'firebase_request_verifier.dart';
import 'offline_checkout_command.dart';
import 'offline_checkout_preflight.dart';

/// Xử lý một lệnh checkout.v1 đã được SyncEngine lấy từ Outbox.
///
/// Chưa được đăng ký chạy tự động trong ứng dụng.
///
/// Nguyên tắc:
/// - Chỉ xử lý lệnh hợp lệ.
/// - Không tin actorId do client gửi lên.
/// - Không âm thầm thay đổi giá đã báo cho khách.
/// - Không tự gửi lại khi kết quả Firebase không rõ ràng.
/// - Chỉ trả về thành công sau khi xác minh server.
class FirebaseCheckoutDispatcher {
  final FirebaseAuth auth;
  final FirestoreRepository repository;
  final FirebaseRequestVerifier verifier;

  FirebaseCheckoutDispatcher({
    required this.auth,
    required this.repository,
    required this.verifier,
  });

  Future<void> dispatch(PendingOperation operation) async {
    if (operation.operationType != 'checkout.v1') {
      throw StateError(
        'Loại thao tác chưa được hỗ trợ: '
        '${operation.operationType}',
      );
    }

    if (operation.status != 'syncing') {
      throw StateError('Outbox chưa được claim để đồng bộ.');
    }

    final OfflineCheckoutCommand command;

    try {
      command = OfflineCheckoutCommand.decode(operation.payloadJson);
    } catch (error) {
      throw FormatException('Không đọc được lệnh checkout: $error');
    }

    final invalidReason = OfflineCheckoutPreflight.invalidReason(command);
    if (invalidReason != null) {
      throw StateError('Đơn offline không hợp lệ: $invalidReason');
    }

    if (command.requestId.isEmpty ||
        command.requestId != operation.id ||
        command.requestId.contains('/')) {
      throw StateError('requestId không khớp với Outbox.');
    }

    if (command.lines.isEmpty) {
      throw StateError('Hóa đơn không có sản phẩm.');
    }

    // Không sử dụng actorId trong JSON để tự cấp quyền.
    final currentUser = auth.currentUser;

    if (currentUser == null || currentUser.uid != command.actorId) {
      throw StateError('Tài khoản đăng nhập không khớp người tạo đơn.');
    }

    // Đọc hồ sơ từ server, không dựa vào cache.
    final profileSnapshot = await repository.firestore
        .collection('users')
        .doc(currentUser.uid)
        .get(const GetOptions(source: Source.server));

    final profile = profileSnapshot.data();

    if (!profileSnapshot.exists ||
        profile == null ||
        profile['active'] != true ||
        profile['mustChangePassword'] != false) {
      throw StateError('Tài khoản không còn quyền đồng bộ.');
    }

    final role = switch (profile['role']) {
      'owner' => Role.owner,
      'sales' => Role.sales,
      _ => null,
    };

    if (role == null) {
      throw StateError('Vai trò nhân viên không được phép bán hàng.');
    }

    final actor = Actor(
      currentUser.uid,
      role,
      displayName: profile['displayName'] as String?,
    );

    actor.requireAccess();

    // Kiểm tra server trước khi tạo giao dịch.
    final before = await verifier.verify(command.requestId);

    switch (before.status) {
      case RequestVerificationStatus.confirmed:
        // Không tự xác nhận lệnh cũ chỉ dựa vào requestId.
        // OutboxReconciler chịu trách nhiệm đối chiếu.
        throw StateError(
          'Request đã tồn tại trên server. '
          'Cần đối chiếu Outbox trước khi xác nhận.',
        );

      case RequestVerificationStatus.uncertain:
        throw StateError(
          'Chưa xác định được trạng thái request. '
          'Không gửi giao dịch.',
        );

      case RequestVerificationStatus.notFound:
        break;
    }

    // Repository sẽ đọc trạng thái server và thực hiện
    // transaction theo cơ chế revision hiện có.
    //
    // Nếu kết quả transaction không rõ ràng, không retry
    // tại đây. Cần đối chiếu trước khi gửi lại.
    final transaction = await repository.transact<Json>((
      data,
      transactionActor,
    ) {
      final lines = <CartLine>[];

      for (final line in command.lines) {
        if (line.productId.isEmpty || line.area <= 0) {
          throw StateError('Thông tin sản phẩm offline không hợp lệ.');
        }

        final product = data.product(line.productId);

        if (product.price != line.quotedPrice ||
            product.ratio != line.quotedRatio) {
          throw StateError(
            'Giá hoặc quy đổi của ${product.name} '
            'đã thay đổi. Cần nhân viên xác nhận lại.',
          );
        }

        lines.add(CartLine(line.productId, line.area, note: line.note));
      }

      return data.checkout(
        requestId: command.requestId,
        lines: lines,
        customerId: command.customerId,
        paid: command.paid,
        ship: command.ship,
        hold: command.hold,
        negativeReason: command.negativeReason,
        actor: transactionActor,
      );
    }, actor);

    final order = transaction.result;

    if (order['requestId'] != command.requestId ||
        order['actor'] != currentUser.uid) {
      throw StateError('Hóa đơn trả về không khớp yêu cầu ban đầu.');
    }

    // Xác minh server sau transaction.
    final after = await verifier.verify(command.requestId);

    if (after.status != RequestVerificationStatus.confirmed ||
        after.orderId == null ||
        after.orderId != order['id']) {
      throw StateError(
        'Firebase chưa xác nhận đầy đủ hóa đơn. '
        'Giữ Outbox để đối chiếu.',
      );
    }

    // Chỉ lúc này dispatcher mới hoàn thành.
    // SyncEngine có thể đánh dấu bản ghi là synced.
  }
}
