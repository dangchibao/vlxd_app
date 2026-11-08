import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/firebase_request_verifier.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_reconciler.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/data/sync/sync_engine.dart';
import 'package:vlxd_app/data/sync/sync_runtime.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late int dispatchCount;
  late int verifyCount;

  Future<void> insertCheckout(String id) async {
    await outbox.enqueueCheckout(
      OfflineCheckoutCommand(
        requestId: id,
        actorId: 'employee-001',
        customerId: 'KH001',
        lines: [
          OfflineCheckoutLine(
            productId: 'PR6060VD',
            area: 14400,
            note: 'Test restart',
            quotedPrice: 200000,
            quotedRatio: 14400,
          ),
        ],
        paid: 0,
        ship: 0,
        hold: false,
        negativeReason: '',
        createdAt: DateTime.utc(2026, 11, 8),
      ),
    );
  }

  SyncRuntime runtimeWith(RequestVerifier verifier) {
    final reconciler = OutboxReconciler(
      outbox: outbox,
      verifyRequest: (id) async {
        verifyCount++;
        return verifier(id);
      },
    );
    final engine = SyncEngine(
      outbox: outbox,
      dispatcher: (_) async {
        dispatchCount++;
        // Nếu initialize gọi dispatcher, bộ đếm sẽ phát hiện.
      },
    );
    return SyncRuntime(outbox: outbox, reconciler: reconciler, engine: engine);
  }

  const confirmed = RequestVerification(
    status: RequestVerificationStatus.confirmed,
    orderId: 'ORDER-001',
  );
  const notFound = RequestVerification(
    status: RequestVerificationStatus.notFound,
  );
  const uncertain = RequestVerification(
    status: RequestVerificationStatus.uncertain,
    message: 'Mất kết nối',
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    dispatchCount = 0;
    verifyCount = 0;
  });

  tearDown(() async {
    await db.close();
  });

  test('syncing bị cách ly thành failed khi server không xác nhận', () async {
    await insertCheckout('restart-syncing-unknown');
    final claimed = await outbox.claimNext();
    expect(claimed?.status, 'syncing');

    await runtimeWith((_) async => uncertain).initialize();

    final result = await outbox.getById('restart-syncing-unknown');
    expect(result, isNotNull);
    expect(result!.status, 'failed');
    expect(result.lastError, contains('Cần xác minh server'));
    expect(result.attempts, 1);
    expect(verifyCount, 1);
    expect(dispatchCount, 0);
  });

  test('syncing bị gián đoạn được xác nhận thì chuyển synced', () async {
    await insertCheckout('restart-syncing-confirmed');
    await outbox.claimNext();

    await runtimeWith((_) async => confirmed).initialize();

    final result = await outbox.getById('restart-syncing-confirmed');
    expect(result?.status, 'synced');
    expect(result?.lastError, isNull);
    expect(verifyCount, 1);
    expect(dispatchCount, 0);
  });

  test('failed được xác nhận trên server thì chuyển synced', () async {
    await insertCheckout('restart-failed-confirmed');
    await outbox.markFailed('restart-failed-confirmed', 'Lỗi trước đó');

    await runtimeWith((_) async => confirmed).initialize();

    final result = await outbox.getById('restart-failed-confirmed');
    expect(result?.status, 'synced');
    expect(result?.lastError, isNull);
    expect(verifyCount, 1);
    expect(dispatchCount, 0);
  });

  test(
    'pending không thấy trên server thì vẫn pending, không gửi lại',
    () async {
      await insertCheckout('restart-pending-notfound');

      await runtimeWith((_) async => notFound).initialize();

      final result = await outbox.getById('restart-pending-notfound');
      expect(result?.status, 'pending');
      expect(result?.attempts, 0);
      expect(verifyCount, 1);
      expect(dispatchCount, 0);
    },
  );

  test('failed gặp lỗi xác minh thì vẫn failed, không gửi lại', () async {
    await insertCheckout('restart-failed-uncertain');
    await outbox.markFailed('restart-failed-uncertain', 'Lỗi cũ');

    await runtimeWith((_) async => uncertain).initialize();

    final result = await outbox.getById('restart-failed-uncertain');
    expect(result?.status, 'failed');
    expect(result?.lastError, 'Lỗi cũ');
    expect(verifyCount, 1);
    expect(dispatchCount, 0);
  });

  test('synced không bị xác minh hoặc gửi lại khi initialize', () async {
    await insertCheckout('restart-already-synced');
    await outbox.markSynced('restart-already-synced');

    await runtimeWith((_) async => uncertain).initialize();

    final result = await outbox.getById('restart-already-synced');
    expect(result?.status, 'synced');
    expect(verifyCount, 0);
    expect(dispatchCount, 0);
  });
}
