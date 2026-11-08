import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/firebase_request_verifier.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_reconciler.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';

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

  Future<void> addCheckout() async {
    final command = OfflineCheckoutCommand(
      requestId: 'request-001',
      actorId: 'staff-001',
      customerId: 'customer-001',
      lines: const [
        OfflineCheckoutLine(
          productId: 'product-001',
          area: 10,
          note: '',
          quotedPrice: 150000,
          quotedRatio: 1,
        ),
      ],
      paid: 500000,
      ship: 0,
      hold: false,
      negativeReason: '',
      createdAt: DateTime.utc(2026, 11, 8),
    );

    await outbox.enqueue(
      id: command.requestId,
      operationType: 'checkout.v1',
      payloadJson: command.encode(),
    );
  }

  test('Firebase xác nhận đơn thì Outbox được xác nhận', () async {
    await addCheckout();

    // Giả lập gửi thất bại vì mất phản hồi.
    await outbox.markFailed('request-001', 'uncertain: Mất phản hồi');

    var verifyCount = 0;

    final reconciler = OutboxReconciler(
      outbox: outbox,
      verifyRequest: (requestId) async {
        verifyCount++;
        expect(requestId, 'request-001');

        return const RequestVerification(
          status: RequestVerificationStatus.confirmed,
          orderId: 'DH-1',
        );
      },
    );

    final result = await reconciler.reconcile('request-001');

    expect(result, ReconcileResult.confirmed);
    expect(verifyCount, 1);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'synced');
    expect(rows.single.lastError, isNull);
  });

  test('Firebase chưa có đơn thì giữ nguyên Outbox', () async {
    await addCheckout();
    await outbox.markFailed('request-001', 'uncertain: Mất phản hồi');

    final reconciler = OutboxReconciler(
      outbox: outbox,
      verifyRequest: (_) async {
        return const RequestVerification(
          status: RequestVerificationStatus.notFound,
        );
      },
    );

    final result = await reconciler.reconcile('request-001');

    expect(result, ReconcileResult.notFound);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'failed');
  });

  test('Mất mạng khi xác minh thì không xác nhận đơn', () async {
    await addCheckout();

    final reconciler = OutboxReconciler(
      outbox: outbox,
      verifyRequest: (_) async {
        throw StateError('Mất mạng');
      },
    );

    final result = await reconciler.reconcile('request-001');

    expect(result, ReconcileResult.uncertain);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'pending');
  });

  test('Không đối chiếu khi worker đang xử lý', () async {
    await addCheckout();

    await outbox.claimNext();

    var called = false;

    final reconciler = OutboxReconciler(
      outbox: outbox,
      verifyRequest: (_) async {
        called = true;
        return const RequestVerification(
          status: RequestVerificationStatus.confirmed,
          orderId: 'DH-1',
        );
      },
    );

    final result = await reconciler.reconcile('request-001');

    expect(result, ReconcileResult.uncertain);
    expect(called, isFalse);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'syncing');
  });
}
