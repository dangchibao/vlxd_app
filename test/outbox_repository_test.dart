import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/data/local/app_database.dart';
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

  test('Thêm thao tác vào Outbox', () async {
    await outbox.enqueue(
      id: 'sale-001',
      operationType: 'sale',
      payloadJson: '{"orderId":"TEST001"}',
    );

    final pending = await outbox.getPending();

    expect(pending.length, 1);
    expect(pending.first.id, 'sale-001');
    expect(pending.first.status, 'pending');
  });

  test('Đồng bộ thành công thì hết chờ', () async {
    await outbox.enqueue(
      id: 'sale-002',
      operationType: 'sale',
      payloadJson: '{"orderId":"TEST002"}',
    );

    await outbox.markSynced('sale-002');

    final pending = await outbox.getPending();

    expect(pending, isEmpty);

    final all = await db.select(db.pendingOperations).get();
    expect(all.single.status, 'synced');
  });

  test('Lỗi đồng bộ có thể thử lại', () async {
    await outbox.enqueue(
      id: 'sale-003',
      operationType: 'sale',
      payloadJson: '{"orderId":"TEST003"}',
    );

    await outbox.markFailed('sale-003', 'Mất kết nối Firebase');

    final failed = await db.select(db.pendingOperations).get();

    expect(failed.single.status, 'failed');
    expect(failed.single.lastError, 'Mất kết nối Firebase');

    await outbox.retryFailed('sale-003');

    final pending = await outbox.getPending();

    expect(pending.length, 1);
    expect(pending.single.status, 'pending');
    expect(pending.single.lastError, isNull);
  });

  test('Không cho thêm trùng ID thao tác', () async {
    await outbox.enqueue(
      id: 'sale-004',
      operationType: 'sale',
      payloadJson: '{"orderId":"TEST004"}',
    );

    await expectLater(
      outbox.enqueue(
        id: 'sale-004',
        operationType: 'sale',
        payloadJson: '{"orderId":"TEST004"}',
      ),
      throwsA(isA<Exception>()),
    );

    final all = await db.select(db.pendingOperations).get();

    expect(all.length, 1);
  });

  test('claimNext chuyển pending sang syncing', () async {
    await outbox.enqueue(
      id: 'claim-001',
      operationType: 'checkout.v1',
      payloadJson: '{"requestId":"claim-001"}',
    );

    final claimed = await outbox.claimNext();

    expect(claimed, isNotNull);
    expect(claimed!.id, 'claim-001');
    expect(claimed.status, 'syncing');
    expect(claimed.attempts, 1);

    // Không lấy lại thao tác đang được xử lý.
    final secondClaim = await outbox.claimNext();
    expect(secondClaim, isNull);
  });

  test('recoverInterrupted khôi phục thao tác bị gián đoạn', () async {
    await outbox.enqueue(
      id: 'recover-001',
      operationType: 'checkout.v1',
      payloadJson: '{"requestId":"recover-001"}',
    );

    await outbox.claimNext();

    final recoveredCount = await outbox.recoverInterrupted();

    expect(recoveredCount, 1);

    final pending = await outbox.getPending();

    expect(pending.length, 1);
    expect(pending.single.id, 'recover-001');
    expect(pending.single.status, 'pending');
    expect(pending.single.attempts, 1);

    // Sau khi khôi phục, có thể nhận lại thao tác.
    final claimedAgain = await outbox.claimNext();

    expect(claimedAgain, isNotNull);
    expect(claimedAgain!.status, 'syncing');
    expect(claimedAgain.attempts, 2);
  });
}
