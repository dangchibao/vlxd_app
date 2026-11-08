import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'firebase_request_verifier.dart';
import 'offline_checkout_command.dart';
import 'outbox_repository.dart';

enum ReconcileResult { confirmed, notFound, uncertain, unsupported }

typedef RequestVerifier = Future<RequestVerification> Function(
  String requestId,
);

class OutboxReconciler {
  final OutboxRepository outbox;
  final RequestVerifier verifyRequest;

  OutboxReconciler({required this.outbox, required this.verifyRequest});

  Future<ReconcileResult> reconcile(String operationId) async {
    final db = outbox.db;

    final operation = await (db.select(
      db.pendingOperations,
    )..where((t) => t.id.equals(operationId))).getSingleOrNull();

    if (operation == null) {
      return ReconcileResult.notFound;
    }

    // Không tác động các bản ghi đã xác nhận.
    if (operation.status == 'synced') {
      return ReconcileResult.confirmed;
    }

    // Không can thiệp thao tác đang được worker xử lý.
    if (operation.status == 'syncing') {
      return ReconcileResult.uncertain;
    }

    if (operation.operationType != 'checkout.v1') {
      return ReconcileResult.unsupported;
    }

    late OfflineCheckoutCommand command;

    try {
      command = OfflineCheckoutCommand.decode(operation.payloadJson);
    } catch (_) {
      return ReconcileResult.uncertain;
    }

    // ID Outbox phải khớp ID yêu cầu tạo đơn.
    if (command.requestId != operation.id) {
      return ReconcileResult.uncertain;
    }

    RequestVerification verification;

    try {
      verification = await verifyRequest(command.requestId);
    } catch (_) {
      return ReconcileResult.uncertain;
    }

    switch (verification.status) {
      case RequestVerificationStatus.confirmed:
        if (verification.orderId == null || verification.orderId!.isEmpty) {
          return ReconcileResult.uncertain;
        }

        // Chỉ chuyển bản ghi chưa được xác nhận.
        await (db.update(db.pendingOperations)..where(
              (t) =>
                  t.id.equals(operationId) &
                  t.status.isIn(['pending', 'failed']),
            ))
            .write(
              const PendingOperationsCompanion(
                status: Value('synced'),
                lastError: Value(null),
              ),
            );

        return ReconcileResult.confirmed;

      case RequestVerificationStatus.notFound:
        // Chưa thấy trên server.
        // Không tự gửi lại giao dịch.
        return ReconcileResult.notFound;

      case RequestVerificationStatus.uncertain:
        // Chưa rõ kết quả, giữ nguyên Outbox.
        return ReconcileResult.uncertain;
    }
  }
}
