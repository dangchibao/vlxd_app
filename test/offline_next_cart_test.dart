import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';

class _FakeLiveRepository implements TransactionalShopRepository {
  @override
  Future<ShopData> load() async => ShopData.sample();

  @override
  Future<void> save(ShopData data) async =>
      throw UnsupportedError('Không lưu dữ liệu demo.');

  @override
  Stream<ShopData> watch() => const Stream<ShopData>.empty();

  @override
  Future<({ShopData data, T result})> transact<T>(
    T Function(ShopData data, Actor actor) operation,
    Actor actor,
  ) async {
    final data = ShopData.sample();
    return (data: data, result: operation(data, actor));
  }
}

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late ShopController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    controller = ShopController(_FakeLiveRepository(), ShopData.sample());
    controller.attachCheckoutOutbox(outbox);
    controller.actor = const Actor('employee-001', Role.owner);
    controller.requestId = 'saved-request-001';
    controller.addCart(
      controller.data.product('PR6060VD'),
      14400,
      note: 'Đơn thứ nhất',
    );
  });

  tearDown(() async {
    controller.onClose();
    await db.close();
  });

  Future<void> save() async {
    await controller.queueOfflineCheckout(
      outbox: outbox,
      customerId: 'KH001',
      paid: 100000,
      ship: 0,
    );
  }

  test('Tạo giỏ mới sau khi SQLite đã lưu; đơn cũ được giữ nguyên', () async {
    await save();
    final oldPayload = (await outbox.getById('saved-request-001'))!.payloadJson;

    await controller.startNewCartAfterOfflineSave(outbox: outbox);

    expect(controller.cart, isEmpty);
    expect(controller.cartEditingLocked, isFalse);
    expect(controller.requestId, isNot('saved-request-001'));
    expect(
      (await outbox.getById('saved-request-001'))!.payloadJson,
      oldPayload,
    );
    expect((await outbox.getById('saved-request-001'))!.status, 'pending');

    controller.addCart(controller.data.product('PR6060VD'), 14400);
    await controller.queueOfflineCheckout(
      outbox: outbox,
      customerId: 'KH001',
      paid: 200000,
      ship: 0,
    );
    expect((await outbox.getPending()), hasLength(2));
  });

  test('Giỏ chưa được lưu không được xóa để tạo giỏ mới', () async {
    await expectLater(
      controller.startNewCartAfterOfflineSave(outbox: outbox),
      throwsA(isA<StateError>()),
    );
    expect(controller.cart, hasLength(1));
    expect(controller.requestId, 'saved-request-001');
  });

  test('Nếu bản ghi Outbox không còn, không được xóa giỏ đã khóa', () async {
    await save();
    await db.delete(db.pendingOperations).go();
    await expectLater(
      controller.startNewCartAfterOfflineSave(outbox: outbox),
      throwsA(isA<StateError>()),
    );
    expect(controller.cart, hasLength(1));
    expect(controller.cartEditingLocked, isTrue);
    expect(controller.requestId, 'saved-request-001');
  });

  test(
    'Không mở giỏ khi actor trong SQLite khác người đang đăng nhập',
    () async {
      await save();
      final saved = await outbox.getById('saved-request-001');
      final original = OfflineCheckoutCommand.decode(saved!.payloadJson);
      await db.delete(db.pendingOperations).go();
      await outbox.enqueueCheckout(
        OfflineCheckoutCommand(
          requestId: original.requestId,
          actorId: 'another-employee',
          customerId: original.customerId,
          lines: original.lines,
          paid: original.paid,
          ship: original.ship,
          hold: original.hold,
          negativeReason: original.negativeReason,
          createdAt: original.createdAt,
        ),
      );

      await expectLater(
        controller.startNewCartAfterOfflineSave(outbox: outbox),
        throwsA(isA<StateError>()),
      );
      expect(controller.cart, hasLength(1));
      expect(controller.cartEditingLocked, isTrue);
    },
  );
}
