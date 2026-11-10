import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/local/shop_snapshot_cache.dart';
import 'package:vlxd_app/data/sync/offline_book_operation.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';

const actor = Actor('operator', Role.sales);

void main() {
  test(
    'Cache isolates accounts and revocation removes data and lease',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final cache = ShopSnapshotCache(db);
      final sample = ShopData.sample();
      await cache.save('one', sample);
      await cache.saveProfile('one', {'active': true, 'role': 'sales'});
      expect(
        (await ShopSnapshotCache(db).load('one'))?.data.products.length,
        sample.products.length,
      );
      expect(await cache.load('two'), isNull);
      expect(await cache.loadProfile('two'), isNull);
      await cache.clear('one');
      expect(await cache.load('one'), isNull);
      expect(await cache.loadProfile('one'), isNull);
    },
  );

  test(
    'Replay after lost acknowledgment records stock and debt payment once',
    () {
      final data = ShopData.sample();
      final p = data.products.first;
      final beforeStock = p.stock;
      final receipt = OfflineBookOperation(
        type: OfflineBookOperation.receipt,
        id: 'stock1',
        actorId: actor.id,
        target: p.id,
        amount: 14400,
        cost: 100000,
        ratio: p.ratio,
        unit: p.unit,
        date: DateTime.now(),
      );
      receipt.apply(data, actor);
      receipt.apply(data, actor);
      expect(p.stock, beforeStock + 14400);

      final order = data.checkout(
        requestId: 'sale1',
        lines: [CartLine(p.id, 14400)],
        customerId: 'KH001',
        paid: 0,
        ship: 50000,
        hold: false,
        actor: actor,
      );
      final payment = OfflineBookOperation(
        type: OfflineBookOperation.payment,
        id: 'pay1',
        actorId: actor.id,
        target: order['id'],
        amount: 50000,
        expectedCollected: 0,
      );
      payment.apply(data, actor);
      final restarted = data.copy();
      payment.apply(restarted, actor);
      expect(restarted.debt('KH001'), (order['total'] as int) - 50000);
      final concurrent = OfflineBookOperation(
        type: OfflineBookOperation.payment,
        id: 'pay2',
        actorId: actor.id,
        target: order['id'],
        amount: 50000,
        expectedCollected: 0,
      );
      expect(() => concurrent.apply(restarted, actor), throwsStateError);
      expect(restarted.debt('KH001'), (order['total'] as int) - 50000);
    },
  );

  test('A worker can only claim its selected operation and live claims survive initialization', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    await outbox.enqueue(
      id: 'other',
      operationType: 'checkout.v1',
      payloadJson: '{}',
    );
    await outbox.enqueue(
      id: 'mine',
      operationType: 'checkout.v1',
      payloadJson: '{}',
    );
    final selected = await outbox.claimNext(expectedId: 'mine');
    expect(selected?.id, 'mine');
    expect((await outbox.getById('other'))?.status, 'pending');
    expect(
      await outbox.quarantineInterrupted(
        staleAfter: const Duration(minutes: 3),
      ),
      0,
    );
    expect((await outbox.getById('mine'))?.status, 'syncing');
  });
}
