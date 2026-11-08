import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/data/sync/sync_engine.dart';

import 'dart:async';

import 'package:vlxd_app/data/sync/sync_failure.dart';

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

  test('Không có thao tác thì Sync Engine nghỉ', () async {
    final engine = SyncEngine(outbox: outbox, dispatcher: (_) async {});

    final result = await engine.processNext();

    expect(result, SyncAttemptResult.idle);
  });

  test('Đồng bộ giả lập thành công', () async {
    await outbox.enqueue(
      id: 'sync-001',
      operationType: 'checkout.v1',
      payloadJson: '{"requestId":"sync-001"}',
    );

    var dispatched = 0;

    final engine = SyncEngine(
      outbox: outbox,
      dispatcher: (operation) async {
        expect(operation.id, 'sync-001');
        dispatched++;
      },
    );

    final result = await engine.processNext();

    expect(result, SyncAttemptResult.synced);
    expect(dispatched, 1);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'synced');
    expect(rows.single.attempts, 1);

    // Không gửi lại bản ghi đã xác nhận.
    expect(await engine.processNext(), SyncAttemptResult.idle);
    expect(dispatched, 1);
  });

  test('Lỗi gửi được ghi vào Outbox', () async {
    await outbox.enqueue(
      id: 'sync-002',
      operationType: 'checkout.v1',
      payloadJson: '{"requestId":"sync-002"}',
    );

    final engine = SyncEngine(
      outbox: outbox,
      dispatcher: (_) async {
        throw StateError('Mất kết nối giả lập');
      },
    );

    final result = await engine.processNext();

    expect(result, SyncAttemptResult.failed);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'failed');
    expect(rows.single.attempts, 1);
    expect(rows.single.lastError, contains('Mất kết nối'));
  });

  test('Không xử lý đồng thời hai lần trên cùng SyncEngine', () async {
    await outbox.enqueue(
      id: 'sync-concurrent-001',
      operationType: 'checkout.v1',
      payloadJson: '{"requestId":"sync-concurrent-001"}',
    );

    final started = Completer<void>();
    final release = Completer<void>();
    var dispatchCount = 0;

    final engine = SyncEngine(
      outbox: outbox,
      dispatcher: (_) async {
        dispatchCount++;
        started.complete();
        await release.future;
      },
    );

    // Lần gọi thứ nhất bắt đầu nhưng chưa hoàn tất.
    final first = engine.processNext();

    await started.future;

    // Lần thứ hai không được lấy cùng thao tác.
    final second = await engine.processNext();

    expect(second, SyncAttemptResult.busy);
    expect(dispatchCount, 1);

    // Cho lần thứ nhất hoàn thành.
    release.complete();

    expect(await first, SyncAttemptResult.synced);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'synced');
    expect(rows.single.attempts, 1);
  });

  test('Sync Engine ghi nhận lỗi tạm thời', () async {
    await outbox.enqueue(
      id: 'temporary-001',
      operationType: 'checkout.v1',
      payloadJson: '{"requestId":"temporary-001"}',
    );

    final engine = SyncEngine(
      outbox: outbox,
      dispatcher: (_) async {
        throw const SyncFailure(SyncFailureKind.temporary, 'Mất kết nối');
      },
    );

    expect(await engine.processNext(), SyncAttemptResult.failed);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'failed');
    expect(rows.single.lastError, startsWith('temporary:'));
  });

  test('Giao dịch chưa rõ kết quả không tự gửi lại', () async {
    await outbox.enqueue(
      id: 'uncertain-001',
      operationType: 'checkout.v1',
      payloadJson: '{"requestId":"uncertain-001"}',
    );

    var dispatchCount = 0;

    final engine = SyncEngine(
      outbox: outbox,
      dispatcher: (_) async {
        dispatchCount++;

        throw const SyncFailure(
          SyncFailureKind.uncertain,
          'Chưa rõ Firebase đã ghi giao dịch chưa',
        );
      },
    );

    expect(await engine.processNext(), SyncAttemptResult.failed);

    final rows = await db.select(db.pendingOperations).get();

    expect(rows.single.status, 'failed');
    expect(rows.single.lastError, startsWith('uncertain:'));

    // Không tự gửi lại giao dịch có kết quả chưa rõ.
    expect(await engine.processNext(), SyncAttemptResult.idle);

    expect(dispatchCount, 1);
  });
}
