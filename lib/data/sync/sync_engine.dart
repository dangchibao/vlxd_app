import '../local/app_database.dart';
import 'outbox_repository.dart';
import 'sync_failure.dart';

enum SyncAttemptResult { idle, busy, synced, failed }

typedef SyncDispatcher = Future<void> Function(PendingOperation operation);

class SyncEngine {
  final OutboxRepository outbox;
  final SyncDispatcher dispatcher;

  bool _running = false;

  SyncEngine({required this.outbox, required this.dispatcher});

  Future<SyncAttemptResult> processNext() async {
    if (_running) {
      return SyncAttemptResult.busy;
    }

    _running = true;

    try {
      final operation = await outbox.claimNext();

      if (operation == null) {
        return SyncAttemptResult.idle;
      }

      try {
        await dispatcher(operation);

        // Chỉ đánh dấu khi bộ xử lý xác nhận thành công.
        await outbox.markSynced(operation.id);

        return SyncAttemptResult.synced;
      } catch (error) {
        final kind = SyncFailureClassifier.classify(error);

        await outbox.markFailed(operation.id, '${kind.name}: $error');

        return SyncAttemptResult.failed;
      }
    } finally {
      // Luôn mở khóa sau khi xử lý hoặc xảy ra lỗi.
      _running = false;
    }
  }
}
