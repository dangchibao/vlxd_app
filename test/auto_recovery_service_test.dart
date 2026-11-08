import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/auto_recovery_service.dart';
import 'package:vlxd_app/data/sync/firebase_request_verifier.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_reconciler.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late Map<String, RequestVerificationStatus> server;
  late Map<String, int> checks;
  late AutoRecoveryService recovery;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    server = {};
    checks = {};
    final reconciler = OutboxReconciler(
      outbox: outbox,
      verifyRequest: (id) async {
        checks[id] = (checks[id] ?? 0) + 1;
        final status = server[id] ?? RequestVerificationStatus.uncertain;
        return RequestVerification(
          status: status,
          orderId: status == RequestVerificationStatus.confirmed
              ? 'order-$id'
              : null,
        );
      },
    );
    recovery = AutoRecoveryService(outbox: outbox, reconciler: reconciler);
  });

  tearDown(() async => db.close());

  Future<void> insert(
    String id, {
    String actor = 'employee-A',
    String status = 'failed',
  }) async {
    final command = OfflineCheckoutCommand(
      requestId: id,
      actorId: actor,
      customerId: 'customer',
      lines: const [
        OfflineCheckoutLine(
          productId: 'tile',
          area: 10000,
          note: '',
          quotedPrice: 100000,
          quotedRatio: 10000,
        ),
      ],
      paid: 100000,
      ship: 0,
      hold: false,
      negativeReason: '',
      createdAt: DateTime.utc(2026, 11, 8),
    );
    await outbox.enqueueCheckout(command);
    if (status == 'failed') {
      await outbox.markFailed(id, 'unknown outcome');
    } else if (status == 'synced') {
      await outbox.markSynced(id);
    }
  }

  test('confirmed failed order is automatically marked synced', () async {
    await insert('one');
    server['one'] = RequestVerificationStatus.confirmed;
    expect(await recovery.sweep(actorId: 'employee-A'), 1);
    expect((await outbox.getById('one'))!.status, 'synced');
  });

  test('notFound is never re-sent, reset or approved', () async {
    await insert('missing');
    server['missing'] = RequestVerificationStatus.notFound;
    expect(await recovery.sweep(actorId: 'employee-A'), 0);
    final row = (await outbox.getById('missing'))!;
    expect(row.status, 'failed');
    expect(row.lastError, 'unknown outcome');
  });

  test(
    'uncertain outcome can later become confirmed without dispatch',
    () async {
      await insert('interrupted');
      expect(await recovery.sweep(actorId: 'employee-A'), 0);
      expect((await outbox.getById('interrupted'))!.status, 'failed');
      server['interrupted'] = RequestVerificationStatus.confirmed;
      expect(await recovery.sweep(actorId: 'employee-A'), 1);
      expect((await outbox.getById('interrupted'))!.status, 'synced');
      expect(checks['interrupted'], 2);
    },
  );

  test('other employees and already synced records are not queried', () async {
    await insert('another', actor: 'employee-B');
    await insert('done', status: 'synced');
    server['another'] = RequestVerificationStatus.confirmed;
    expect(await recovery.sweep(actorId: 'employee-A'), 0);
    expect(checks, isEmpty);
    expect((await outbox.getById('another'))!.status, 'failed');
  });

  test(
    'round-robin checks subsequent batches when older items stay unresolved',
    () async {
      recovery = AutoRecoveryService(
        outbox: outbox,
        reconciler: OutboxReconciler(
          outbox: outbox,
          verifyRequest: (id) async {
            checks[id] = (checks[id] ?? 0) + 1;
            return const RequestVerification(
              status: RequestVerificationStatus.notFound,
            );
          },
        ),
        batchSize: 2,
      );
      for (var i = 0; i < 5; i++) {
        await insert('batch-$i');
      }
      expect(await recovery.sweep(actorId: 'employee-A'), 0);
      expect(await recovery.sweep(actorId: 'employee-A'), 0);
      expect(await recovery.sweep(actorId: 'employee-A'), 0);
      expect(checks.length, 5);
    },
  );
}
