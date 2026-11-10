import 'package:drift/drift.dart';

import '../local/app_database.dart';

import 'offline_checkout_command.dart';
import 'offline_book_operation.dart';

String? offlineOperationOwner(PendingOperation row) {
  try {
    if (OfflineBookOperation.supports(row.operationType)) {
      return OfflineBookOperation.decode(row).actorId;
    }
    if (row.operationType == 'checkout.v1') {
      final command = OfflineCheckoutCommand.decode(row.payloadJson);
      if (command.requestId == row.id) return command.actorId;
    }
  } catch (_) {
    // Corrupt entries must not be dispatched or exposed to another user.
  }
  return null;
}

class OutboxRepository {
  final AppDatabase db;

  OutboxRepository(this.db);

  /// Tìm giao dịch theo requestId.
  ///
  /// Trả về null nếu giao dịch chưa có trong Outbox.
  /// Không thay đổi trạng thái hoặc gửi Firebase.
  Future<PendingOperation?> getById(String requestId) async {
    if (requestId.trim().isEmpty) {
      throw ArgumentError('requestId không được để trống.');
    }

    return (db.select(
      db.pendingOperations,
    )..where((t) => t.id.equals(requestId))).getSingleOrNull();
  }

  Future<bool> requeueReviewed(PendingOperation expected) async {
    if (expected.status != 'failed') return false;
    final count =
        await (db.update(db.pendingOperations)..where(
              (t) =>
                  t.id.equals(expected.id) &
                  t.status.equals('failed') &
                  t.attempts.equals(expected.attempts) &
                  t.payloadJson.equals(expected.payloadJson),
            ))
            .write(
              const PendingOperationsCompanion(
                status: Value('pending'),
                lastError: Value('manual-retry-verified'),
              ),
            );
    return count == 1;
  }

  static bool canCancel(PendingOperation row) =>
      (row.status == 'pending' && row.attempts == 0) ||
      (row.status == 'failed' &&
          row.lastError?.startsWith('permanent:') == true);

  Future<bool> cancelReviewed(PendingOperation expected) async {
    if (!canCancel(expected)) return false;
    final count =
        await (db.update(db.pendingOperations)..where(
              (t) =>
                  t.id.equals(expected.id) &
                  t.status.equals(expected.status) &
                  t.attempts.equals(expected.attempts) &
                  t.payloadJson.equals(expected.payloadJson),
            ))
            .write(
              const PendingOperationsCompanion(status: Value('cancelled')),
            );
    return count == 1;
  }

  /// Lưu lệnh checkout vào Outbox.
  /// Không tự gửi Firebase ở bước này.
  Future<void> enqueueCheckout(OfflineCheckoutCommand command) async {
    if (command.requestId.trim().isEmpty || command.requestId.contains('/')) {
      throw ArgumentError('Mã giao dịch không hợp lệ.');
    }

    if (command.actorId.trim().isEmpty) {
      throw ArgumentError('Thiếu tài khoản tạo đơn.');
    }

    if (command.lines.isEmpty) {
      throw ArgumentError('Không thể lưu đơn hàng trống.');
    }

    await enqueue(
      id: command.requestId,
      operationType: 'checkout.v1',
      payloadJson: command.encode(),
    );
  }

  // Thêm một thao tác mới vào hàng đợi.
  Future<void> enqueue({
    required String id,
    required String operationType,
    required String payloadJson,
  }) async {
    await db
        .into(db.pendingOperations)
        .insert(
          PendingOperationsCompanion.insert(
            id: id,
            operationType: operationType,
            payloadJson: payloadJson,
          ),
        );
  }

  // Lấy các thao tác đang chờ đồng bộ.
  Future<List<PendingOperation>> getPending() {
    return (db.select(db.pendingOperations)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  // Đánh dấu thao tác đã được máy chủ xác nhận.
  Future<void> markSynced(String id) async {
    await (db.update(
      db.pendingOperations,
    )..where((t) => t.id.equals(id))).write(
      const PendingOperationsCompanion(
        status: Value('synced'),
        lastError: Value(null),
      ),
    );
  }

  // Ghi nhận thao tác bị lỗi.
  Future<void> markFailed(String id, String error) async {
    await (db.update(
      db.pendingOperations,
    )..where((t) => t.id.equals(id))).write(
      PendingOperationsCompanion(
        status: const Value('failed'),
        lastError: Value(error),
      ),
    );
  }

  // Đưa thao tác lỗi trở lại hàng chờ.
  Future<void> retryFailed(String id) async {
    await (db.update(
      db.pendingOperations,
    )..where((t) => t.id.equals(id) & t.status.equals('failed'))).write(
      const PendingOperationsCompanion(
        status: Value('pending'),
        lastError: Value(null),
      ),
    );
  }

  /// Chỉ mở lại một lần gửi lỗi tạm thời ĐÃ được máy chủ kiểm tra là
  /// chưa tồn tại. Caller phải tự xác minh requestId bằng Source.server.
  /// Không chạm vào đơn uncertain / permanent và không xóa dữ liệu.
  Future<bool> requeueVerifiedTemporary({
    required String id,
    required int expectedAttempts,
    required String expectedError,
    int maxAttempts = 3,
  }) async {
    if (!expectedError.startsWith('temporary:') ||
        expectedAttempts < 1 ||
        expectedAttempts >= maxAttempts) {
      return false;
    }
    final changed =
        await (db.update(db.pendingOperations)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.equals('failed') &
                  t.attempts.equals(expectedAttempts) &
                  t.lastError.equals(expectedError),
            ))
            .write(
              const PendingOperationsCompanion(
                status: Value('pending'),
                lastError: Value('auto-retry-verified'),
              ),
            );
    return changed == 1;
  }

  // Lấy một thao tác chờ và chuyển sang trạng thái đang đồng bộ.
  Future<PendingOperation?> claimNext({String? expectedId}) async {
    return db.transaction(() async {
      final items =
          await (db.select(db.pendingOperations)
                ..where(
                  (t) =>
                      t.status.equals('pending') &
                      (expectedId == null
                          ? const Constant(true)
                          : t.id.equals(expectedId)),
                )
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ])
                ..limit(1))
              .get();

      if (items.isEmpty) return null;

      final item = items.first;

      final changed =
          await (db.update(db.pendingOperations)..where(
                (t) => t.id.equals(item.id) & t.status.equals('pending'),
              ))
              .write(
                PendingOperationsCompanion(
                  status: const Value('syncing'),
                  attempts: Value(item.attempts + 1),
                  lastError: Value(
                    'claim:${DateTime.now().millisecondsSinceEpoch}',
                  ),
                ),
              );

      if (changed != 1) return null;

      return (db.select(
        db.pendingOperations,
      )..where((t) => t.id.equals(item.id))).getSingle();
    });
  }

  /// Complete only the exact worker claim that performed the dispatch.
  /// A late response must never overwrite a newer reconciliation outcome.
  Future<bool> completeClaimed({
    required String id,
    required int attempts,
  }) async {
    final updated =
        await (db.update(db.pendingOperations)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.equals('syncing') &
                  t.attempts.equals(attempts),
            ))
            .write(
              const PendingOperationsCompanion(
                status: Value('synced'),
                lastError: Value(null),
              ),
            );
    return updated == 1;
  }

  /// Quarantine only the exact worker claim that failed.
  /// A verified synced order can never be demoted back to failed.
  Future<bool> failClaimed({
    required String id,
    required int attempts,
    required String error,
  }) async {
    final updated =
        await (db.update(db.pendingOperations)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.equals('syncing') &
                  t.attempts.equals(attempts),
            ))
            .write(
              PendingOperationsCompanion(
                status: const Value('failed'),
                lastError: Value(error),
              ),
            );
    return updated == 1;
  }

  // Khôi phục thao tác đang đồng bộ nhưng bị gián đoạn.
  // Chỉ gọi khi không còn worker đồng bộ cũ đang hoạt động.
  Future<int> recoverInterrupted() async {
    return (db.update(db.pendingOperations)
          ..where((t) => t.status.equals('syncing')))
        .write(const PendingOperationsCompanion(status: Value('pending')));
  }

  /// Cách ly các thao tác bị gián đoạn.
  /// Không tự động gửi lại khi chưa xác minh Firebase.
  Future<int> quarantineInterrupted({Duration? staleAfter}) async {
    final table = db.pendingOperations;
    final replacement = const PendingOperationsCompanion(
      status: Value('failed'),
      lastError: Value(
        'Giao dịch bị gián đoạn. Cần xác minh server trước khi gửi lại.',
      ),
    );
    if (staleAfter == null) {
      return (db.update(
        table,
      )..where((t) => t.status.equals('syncing'))).write(replacement);
    }
    final cutoff = DateTime.now().subtract(staleAfter).millisecondsSinceEpoch;
    final rows = await (db.select(
      table,
    )..where((t) => t.status.equals('syncing'))).get();
    var changed = 0;
    for (final row in rows) {
      final claim = row.lastError;
      final timestamp = claim?.startsWith('claim:') == true
          ? int.tryParse(claim!.substring(6))
          : null;
      if (timestamp != null && timestamp > cutoff) continue;
      changed +=
          await (db.update(table)..where(
                (t) =>
                    t.id.equals(row.id) &
                    t.status.equals('syncing') &
                    t.attempts.equals(row.attempts),
              ))
              .write(replacement);
    }
    return changed;
  }
}
