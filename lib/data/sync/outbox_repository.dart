import 'package:drift/drift.dart';

import '../local/app_database.dart';

class OutboxRepository {
  final AppDatabase db;

  OutboxRepository(this.db);

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
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
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

  // Lấy một thao tác chờ và chuyển sang trạng thái đang đồng bộ.
  Future<PendingOperation?> claimNext() async {
    return db.transaction(() async {
      final items =
          await (db.select(db.pendingOperations)
                ..where((t) => t.status.equals('pending'))
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
                  lastError: const Value(null),
                ),
              );

      if (changed != 1) return null;

      return (db.select(
        db.pendingOperations,
      )..where((t) => t.id.equals(item.id))).getSingle();
    });
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
  Future<int> quarantineInterrupted() async {
    return (db.update(
      db.pendingOperations,
    )..where((t) => t.status.equals('syncing'))).write(
      const PendingOperationsCompanion(
        status: Value('failed'),
        lastError: Value(
          'Giao dịch bị gián đoạn. Cần xác minh server trước khi gửi lại.',
        ),
      ),
    );
  }
}
