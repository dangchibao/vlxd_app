import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';

void main() {
  test('Lệnh bán hàng offline giữ nguyên dữ liệu', () {
    final command = OfflineCheckoutCommand(
      requestId: 'request-001',
      actorId: 'employee-001',
      customerId: 'customer-001',
      lines: const [
        OfflineCheckoutLine(
          productId: 'product-001',
          area: 10,
          note: 'Giao buổi sáng',
          quotedPrice: 150000,
          quotedRatio: 1,
        ),
      ],
      paid: 500000,
      ship: 50000,
      hold: false,
      negativeReason: '',
      createdAt: DateTime.utc(2026, 11, 8),
    );

    final restored = OfflineCheckoutCommand.decode(command.encode());

    expect(restored.requestId, 'request-001');
    expect(restored.actorId, 'employee-001');
    expect(restored.customerId, 'customer-001');
    expect(restored.lines.single.productId, 'product-001');
    expect(restored.lines.single.area, 10);
    expect(restored.lines.single.quotedPrice, 150000);
    expect(restored.paid, 500000);
    expect(restored.ship, 50000);
    expect(restored.lines.single.note, 'Giao buổi sáng');
  });

  test('Lệnh checkout được lưu vào Outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final outbox = OutboxRepository(db);

    final command = OfflineCheckoutCommand(
      requestId: 'request-002',
      actorId: 'employee-001',
      customerId: 'customer-001',
      lines: const [
        OfflineCheckoutLine(
          productId: 'product-001',
          area: 5,
          note: '',
          quotedPrice: 200000,
          quotedRatio: 1,
        ),
      ],
      paid: 1000000,
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

    final pending = await outbox.getPending();

    expect(pending.length, 1);

    final restored = OfflineCheckoutCommand.decode(pending.single.payloadJson);

    expect(restored.requestId, command.requestId);
    expect(restored.paid, 1000000);
    expect(restored.lines.single.area, 5);
  });
}
