import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/data/sync/sync_engine.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> enqueue(String id) =>
      outbox.enqueue(id: id, operationType: 'checkout.v1', payloadJson: '{}');

  test('Successful dispatch completes only its claimed operation', () async {
    await enqueue('success');
    final engine = SyncEngine(outbox: outbox, dispatcher: (_) async {});
    expect(await engine.processNext(), SyncAttemptResult.synced);
    final item = (await outbox.getById('success'))!;
    expect(item.status, 'synced');
    expect(item.attempts, 1);
  });

  test(
    'Failed dispatch is quarantined and never automatically retried',
    () async {
      await enqueue('failed');
      var count = 0;
      final engine = SyncEngine(
        outbox: outbox,
        dispatcher: (_) async {
          count++;
          throw StateError('unknown Firebase outcome');
        },
      );
      expect(await engine.processNext(), SyncAttemptResult.failed);
      expect((await outbox.getById('failed'))!.status, 'failed');
      expect(await engine.processNext(), SyncAttemptResult.idle);
      expect(count, 1);
    },
  );

  test(
    'Late worker exception cannot demote externally confirmed order',
    () async {
      await enqueue('verified');
      final engine = SyncEngine(
        outbox: outbox,
        dispatcher: (operation) async {
          await outbox.markSynced(operation.id); // Simulates verified result.
          throw StateError('late network exception');
        },
      );
      expect(await engine.processNext(), SyncAttemptResult.failed);
      expect((await outbox.getById('verified'))!.status, 'synced');
    },
  );

  test(
    'Late success cannot override an externally quarantined order',
    () async {
      await enqueue('quarantined');
      final engine = SyncEngine(
        outbox: outbox,
        dispatcher: (operation) async {
          await outbox.markFailed(operation.id, 'verification required');
        },
      );
      expect(await engine.processNext(), SyncAttemptResult.failed);
      final item = (await outbox.getById('quarantined'))!;
      expect(item.status, 'failed');
      expect(item.lastError, 'verification required');
    },
  );

  test('Stale attempts token cannot finalize a newer claim', () async {
    await enqueue('stale');
    final first = (await outbox.claimNext())!;
    expect(first.attempts, 1);
    await outbox.markFailed(first.id, 'quarantined');
    // Simulate a MANUAL reset followed by a new claim.
    await outbox.retryFailed(first.id);
    final second = (await outbox.claimNext())!;
    expect(second.attempts, 2);
    expect(
      await outbox.completeClaimed(id: first.id, attempts: first.attempts),
      isFalse,
    );
    expect(
      await outbox.failClaimed(
        id: first.id,
        attempts: first.attempts,
        error: 'stale failure',
      ),
      isFalse,
    );
    expect((await outbox.getById('stale'))!.status, 'syncing');
    expect(
      await outbox.completeClaimed(id: second.id, attempts: second.attempts),
      isTrue,
    );
    expect((await outbox.getById('stale'))!.status, 'synced');
  });
}
