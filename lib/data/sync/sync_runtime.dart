import 'outbox_repository.dart';
import 'outbox_reconciler.dart';
import 'sync_engine.dart';

/// Điều phối đồng bộ Outbox.
///
/// Không tự động retry các giao dịch có kết quả
/// chưa rõ ràng.
class SyncRuntime {
  final OutboxRepository outbox;
  final OutboxReconciler reconciler;
  final SyncEngine engine;

  bool _running = false;

  SyncRuntime({
    required this.outbox,
    required this.reconciler,
    required this.engine,
  });

  /// Chỉ gọi khi không còn worker đồng bộ cũ.
  ///
  /// Khôi phục trạng thái các thao tác bị gián đoạn,
  /// nhưng chưa tự gửi lại.

  Future<void> initialize({String? actorId, Duration? staleAfter}) async {
    if (_running) return;

    _running = true;

    try {
      // Cách ly các giao dịch đồng bộ bị gián đoạn.
      // Tuyệt đối không tự chuyển chúng về pending.
      await outbox.quarantineInterrupted(staleAfter: staleAfter);

      // Đọc cả pending và failed để đối chiếu với server.
      // Không gọi engine.processNext() hoặc drain().
      final operations = await outbox.db
          .select(outbox.db.pendingOperations)
          .get();

      for (final operation in operations) {
        if (actorId != null && offlineOperationOwner(operation) != actorId) {
          continue;
        }
        if (operation.status != 'pending' && operation.status != 'failed') {
          continue;
        }

        // Reconciler chỉ đánh dấu synced khi server xác nhận.
        // notFound hoặc uncertain không kích hoạt gửi lại.
        await reconciler.reconcile(operation.id);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> drain() async {
    if (_running) return;

    _running = true;

    try {
      while (true) {
        final result = await engine.processNext();

        switch (result) {
          case SyncAttemptResult.synced:
            continue;

          case SyncAttemptResult.idle:
          case SyncAttemptResult.busy:
          case SyncAttemptResult.failed:
            return;
        }
      }
    } finally {
      _running = false;
    }
  }
}
