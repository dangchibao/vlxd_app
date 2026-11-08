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

  Future<void> addCheckout({String requestId = 'reconcile-test-001'}) async {
    await outbox.enqueueCheckout(
      OfflineCheckoutCommand(
        requestId: requestId,
        actorId: 'employee-001',
        customerId: 'KH001',
        lines: [
          const OfflineCheckoutLine(
            productId: 'PR6060VD',
            area: 14400,
            note: 'Giao buổi sáng',
            quotedPrice: 180000,
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

  OutboxReconciler reconciler(
    Future<RequestVerification> Function(String) verify,
  ) => OutboxReconciler(outbox: outbox, verifyRequest: verify);

  test(
    'Server xác nhận request và hóa đơn: chuyển pending thành synced',
    () async {
      await addCheckout();
      var calls = 0;
      final r = reconciler((id) async {
        calls++;
        expect(id, 'reconcile-test-001');
        return const RequestVerification(
          status: RequestVerificationStatus.confirmed,
          orderId: 'ORDER-001',
        );
      });

      expect(
        await r.reconcile('reconcile-test-001'),
        ReconcileResult.confirmed,
      );
      expect((await outbox.getById('reconcile-test-001'))!.status, 'synced');
      expect(calls, 1);
    },
  );

  test('Server báo notFound: giữ pending, không tự gửi lại', () async {
    await addCheckout();
    final r = reconciler(
      (_) async =>
          const RequestVerification(status: RequestVerificationStatus.notFound),
    );

    expect(await r.reconcile('reconcile-test-001'), ReconcileResult.notFound);
    final operation = (await outbox.getById('reconcile-test-001'))!;
    expect(operation.status, 'pending');
    expect(operation.attempts, 0);
  });

  test('Mất mạng/lỗi xác minh: giữ pending', () async {
    await addCheckout();
    final r = reconciler((_) async => throw StateError('Mất kết nối'));

    expect(await r.reconcile('reconcile-test-001'), ReconcileResult.uncertain);
    expect((await outbox.getById('reconcile-test-001'))!.status, 'pending');
  });

  test('Server xác nhận nhưng thiếu orderId: không đánh dấu synced', () async {
    await addCheckout();
    final r = reconciler(
      (_) async => const RequestVerification(
        status: RequestVerificationStatus.confirmed,
      ),
    );

    expect(await r.reconcile('reconcile-test-001'), ReconcileResult.uncertain);
    expect((await outbox.getById('reconcile-test-001'))!.status, 'pending');
  });

  test(
    'Đang syncing: không gọi verifier và không thay đổi trạng thái',
    () async {
      await addCheckout();
      final claimed = await outbox.claimNext();
      expect(claimed!.status, 'syncing');
      var called = false;
      final r = reconciler((_) async {
        called = true;
        return const RequestVerification(
          status: RequestVerificationStatus.confirmed,
          orderId: 'ORDER-001',
        );
      });

      expect(
        await r.reconcile('reconcile-test-001'),
        ReconcileResult.uncertain,
      );
      expect(called, isFalse);
      expect((await outbox.getById('reconcile-test-001'))!.status, 'syncing');
    },
  );

  test('Đơn failed được server xác nhận: chuyển synced', () async {
    await addCheckout();
    await outbox.markFailed('reconcile-test-001', 'Mất kết nối');
    final r = reconciler(
      (_) async => const RequestVerification(
        status: RequestVerificationStatus.confirmed,
        orderId: 'ORDER-001',
      ),
    );

    expect(await r.reconcile('reconcile-test-001'), ReconcileResult.confirmed);
    final operation = (await outbox.getById('reconcile-test-001'))!;
    expect(operation.status, 'synced');
    expect(operation.lastError, isNull);
  });

  test('Đơn đã synced: không xác minh hoặc gửi lại', () async {
    await addCheckout();
    await outbox.markSynced('reconcile-test-001');
    var called = false;
    final r = reconciler((_) async {
      called = true;
      return const RequestVerification(
        status: RequestVerificationStatus.notFound,
      );
    });

    expect(await r.reconcile('reconcile-test-001'), ReconcileResult.confirmed);
    expect(called, isFalse);
    expect((await outbox.getById('reconcile-test-001'))!.status, 'synced');
  });

  test('ID không tồn tại: không gọi verifier', () async {
    var called = false;
    final r = reconciler((_) async {
      called = true;
      return const RequestVerification(
        status: RequestVerificationStatus.notFound,
      );
    });

    expect(await r.reconcile('missing'), ReconcileResult.notFound);
    expect(called, isFalse);
  });
}
