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
}
