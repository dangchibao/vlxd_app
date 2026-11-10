import 'package:drift/drift.dart';

import '../local/app_database.dart';
import 'firebase_request_verifier.dart';
import 'offline_checkout_command.dart';
import 'offline_book_operation.dart';
import 'outbox_repository.dart';

enum ReconcileResult { confirmed, notFound, uncertain, unsupported }

typedef RequestVerifier = Future<RequestVerification> Function(
  String requestId,
);

class OutboxReconciler {
  final OutboxRepository outbox;
  final RequestVerifier verifyRequest;
  final Future<RequestVerification> Function(OfflineBookOperation)? verifyBook;

  OutboxReconciler({
    required this.outbox,
    required this.verifyRequest,
    this.verifyBook,
  });

  Future<RequestVerification> verifyOperation(
    PendingOperation operation,
  ) async {
    try {
      if (OfflineBookOperation.supports(operation.operationType) &&
          verifyBook != null) {
        return await verifyBook!(OfflineBookOperation.decode(operation));
      }
      if (operation.operationType == 'checkout.v1') {
        final command = OfflineCheckoutCommand.decode(operation.payloadJson);
        if (command.requestId == operation.id) {
          return await verifyRequest(command.requestId);
        }
      }
    } catch (_) {}
    return const RequestVerification(
      status: RequestVerificationStatus.uncertain,
    );
  }

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
    if (operation.status == 'cancelled') return ReconcileResult.unsupported;

    // Không can thiệp thao tác đang được worker xử lý.
    if (operation.status == 'syncing') {
      return ReconcileResult.uncertain;
    }

    if (operation.operationType != 'checkout.v1' &&
        !(verifyBook != null &&
            OfflineBookOperation.supports(operation.operationType))) {
      return ReconcileResult.unsupported;
    }
    final verification = await verifyOperation(operation);

    switch (verification.status) {
      case RequestVerificationStatus.confirmed:
        if (verification.orderId == null || verification.orderId!.isEmpty) {
          return ReconcileResult.uncertain;
        }

        // Chỉ chuyển bản ghi chưa được xác nhận.

        // Chỉ xác nhận thành công nếu SQLite thực sự
        // chuyển được bản ghi sang trạng thái synced.
        final updated =
            await (db.update(db.pendingOperations)..where(
                  (t) =>
                      t.id.equals(operationId) &
                      t.payloadJson.equals(operation.payloadJson) &
                      t.attempts.equals(operation.attempts) &
                      t.status.isIn(['pending', 'failed']),
                ))
                .write(
                  const PendingOperationsCompanion(
                    status: Value('synced'),
                    lastError: Value(null),
                  ),
                );

        if (updated != 1) {
          // Bản ghi có thể đã được worker khác nhận xử lý.
          // Không báo thành công khi chưa cập nhật được.
          return ReconcileResult.uncertain;
        }

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
