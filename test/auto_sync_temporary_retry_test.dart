import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/auto_sync_coordinator.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';

void main() {
  final command = OfflineCheckoutCommand(
    requestId: 'retry-001',
    actorId: 'staff-1',
    customerId: 'KH001',
    lines: const [OfflineCheckoutLine(
      productId: 'PR6060VD', area: 10000, note: '',
      quotedPrice: 100000, quotedRatio: 10000,
    )],
    paid: 100000, ship: 0, hold: false, negativeReason: '',
    createdAt: DateTime.utc(2026, 11, 9),
  );

  test('temporary failure is eligible only after identity/preflight', () {
    expect(AutoSyncCoordinator.canRetryTemporary(
      command: command, operationId: 'retry-001',
      status: 'failed', lastError: 'temporary: unavailable',
      attempts: 1, actorId: 'staff-1',
    ), isTrue);
    for (final kind in ['uncertain:', 'permanent:']) {
      expect(AutoSyncCoordinator.canRetryTemporary(
        command: command, operationId: 'retry-001',
        status: 'failed', lastError: '$kind error',
        attempts: 1, actorId: 'staff-1',
      ), isFalse);
    }
  });

  test('verified retry is bounded and preserves the original payload', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await outbox.enqueueCheckout(command);
    final first = await outbox.claimNext();
    expect(first!.attempts, 1);
    await outbox.failClaimed(
      id: command.requestId, attempts: 1, error: 'temporary: unavailable',
    );
    expect(await outbox.requeueVerifiedTemporary(
      id: command.requestId, expectedAttempts: 1,
      expectedError: 'uncertain: unavailable',
    ), isFalse);
    expect(await outbox.requeueVerifiedTemporary(
      id: command.requestId, expectedAttempts: 1,
      expectedError: 'temporary: unavailable',
    ), isTrue);
    var row = (await outbox.getById(command.requestId))!;
    expect(row.status, 'pending');
    expect(row.payloadJson, command.encode());
    expect(AutoSyncCoordinator.canAttempt(
      command: command, operationId: row.id,
      status: row.status, attempts: row.attempts,
      actorId: command.actorId, lastError: row.lastError,
    ), isTrue);
    final second = await outbox.claimNext();
    expect(second!.attempts, 2);
    await outbox.failClaimed(
      id: command.requestId, attempts: 2, error: 'temporary: unavailable',
    );
    expect(await outbox.requeueVerifiedTemporary(
      id: command.requestId, expectedAttempts: 2,
      expectedError: 'temporary: unavailable',
    ), isTrue);
    final third = await outbox.claimNext();
    expect(third!.attempts, 3);
    await outbox.failClaimed(
      id: command.requestId, attempts: 3, error: 'temporary: unavailable',
    );
    expect(await outbox.requeueVerifiedTemporary(
      id: command.requestId, expectedAttempts: 3,
      expectedError: 'temporary: unavailable',
    ), isFalse);
    row = (await outbox.getById(command.requestId))!;
    expect(row.status, 'failed');
    expect(row.attempts, 3);
  });
}
