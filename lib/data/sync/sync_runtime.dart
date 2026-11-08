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
  Future<void> initialize() async {
    if (_running) return;

    _running = true;

    try {
      await outbox.quarantineInterrupted();

      final pending = await outbox.getPending();

      for (final operation in pending) {
        await reconciler.reconcile(operation.id);
      }
    } finally {
      _running = false;
    }
  }

  /// Xử lý các thao tác pending.
  ///
  /// Chỉ gọi sau khi hoàn thành bước khôi phục
  /// và xác định được điều kiện gửi an toàn.
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
