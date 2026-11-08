import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;
  AppDatabase? database;
  OutboxRepository? outbox;

  Future<void> openDatabase() async {
    final next = AppDatabase.forTesting(NativeDatabase(databaseFile));
    database = next;
    outbox = OutboxRepository(next);
  }

  Future<void> restartDatabase() async {
    await database!.close();
    database = null;
    outbox = null;
    await openDatabase();
  }

  OfflineCheckoutCommand command(String id) => OfflineCheckoutCommand(
    requestId: id,
    actorId: 'employee-001',
    customerId: 'KH001',
    lines: [
      OfflineCheckoutLine(
        productId: 'PR6060VD',
        area: 14400,
        note: 'Giao buổi sáng',
        quotedPrice: 199000,
        quotedRatio: 14400,
      ),
    ],
    paid: 0,
    ship: 0,
    hold: false,
    negativeReason: '',
    createdAt: DateTime.utc(2026, 11, 8),
  );

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'vlxd_outbox_restart_test_',
    );
    databaseFile = File('${temporaryDirectory.path}/outbox.sqlite');
    await openDatabase();
  });

  tearDown(() async {
    await database?.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('Đơn pending còn nguyên sau khi đóng và mở lại database', () async {
    const id = 'restart-pending-001';
    await outbox!.enqueueCheckout(command(id));

    await restartDatabase();

    final stored = await outbox!.getById(id);
    expect(stored, isNotNull);
    expect(stored!.status, 'pending');
    expect(stored.attempts, 0);

    final decoded = OfflineCheckoutCommand.decode(stored.payloadJson);
    expect(decoded.requestId, id);
    expect(decoded.lines.single.productId, 'PR6060VD');
    expect(decoded.lines.single.area, 14400);
    expect(decoded.customerId, 'KH001');
    expect((await outbox!.getPending()).map((item) => item.id), contains(id));
  });

  test('Syncing sau khi mở lại được cách ly, không tự gửi lại', () async {
    const id = 'restart-syncing-001';
    await outbox!.enqueueCheckout(command(id));
    final claimed = await outbox!.claimNext();
    expect(claimed, isNotNull);
    expect(claimed!.id, id);
    expect(claimed.status, 'syncing');
    expect(claimed.attempts, 1);

    await restartDatabase();
    expect((await outbox!.getById(id))!.status, 'syncing');

    final quarantined = await outbox!.quarantineInterrupted();
    expect(quarantined, 1);

    final stored = await outbox!.getById(id);
    expect(stored!.status, 'failed');
    expect(stored.attempts, 1);
    expect(stored.lastError, contains('xác minh server'));
    expect(await outbox!.claimNext(), isNull);
    expect(await outbox!.getPending(), isEmpty);
  });

  test('Đơn failed không tự trở thành pending khi mở lại', () async {
    const id = 'restart-failed-001';
    await outbox!.enqueueCheckout(command(id));
    await outbox!.markFailed(id, 'Chưa xác minh trên Firebase');

    await restartDatabase();

    final stored = await outbox!.getById(id);
    expect(stored!.status, 'failed');
    expect(stored.lastError, 'Chưa xác minh trên Firebase');
    expect(await outbox!.getPending(), isEmpty);
    expect(await outbox!.claimNext(), isNull);
    expect(await outbox!.quarantineInterrupted(), 0);
  });

  test('Đơn synced vẫn được lưu để nhận diện requestId cũ', () async {
    const id = 'restart-synced-001';
    await outbox!.enqueueCheckout(command(id));
    await outbox!.markSynced(id);

    await restartDatabase();

    expect((await outbox!.getById(id))!.status, 'synced');
    expect(await outbox!.getPending(), isEmpty);
    expect(await outbox!.claimNext(), isNull);
  });

  test('Không ghi đè requestId cũ sau khi mở lại', () async {
    const id = 'restart-duplicate-001';
    final original = command(id);
    await outbox!.enqueueCheckout(original);
    await restartDatabase();

    await expectLater(outbox!.enqueueCheckout(command(id)), throwsA(anything));

    final pending = await outbox!.getPending();
    expect(pending, hasLength(1));
    expect(pending.single.id, id);
    expect(pending.single.payloadJson, original.encode());
  });
}
