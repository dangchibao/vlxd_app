import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';

// Repository giả lập chế độ Firebase.
// Không kết nối hoặc ghi dữ liệu lên Firebase thật.
class FakeLiveRepository implements TransactionalShopRepository {
  ShopData state = ShopData.sample();

  @override
  Future<ShopData> load() async => state.copy();

  @override
  Future<void> save(ShopData data) async {
    throw UnsupportedError('Không dùng save cho dữ liệu live.');
  }

  @override
  Stream<ShopData> watch() => const Stream<ShopData>.empty();

  @override
  Future<({ShopData data, T result})> transact<T>(
    T Function(ShopData data, Actor actor) operation,
    Actor actor,
  ) async {
    final next = state.copy();
    final result = operation(next, actor);
    state = next;
    return (data: next, result: result);
  }
}

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late ShopController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);

    controller = ShopController(FakeLiveRepository(), ShopData.sample());

    // Giả lập nhân viên có quyền bán hàng.
    controller.actor = const Actor('employee-001', Role.owner);

    controller.requestId = 'request-offline-001';

    controller.addCart(
      controller.data.product('PR6060VD'),
      144000,
      note: 'Giao buổi sáng',
    );
  });

  tearDown(() async {
    controller.onClose();
    await db.close();
  });

  test('Chuẩn bị hóa đơn offline giữ nguyên dữ liệu', () {
    final command = controller.prepareOfflineCheckout(
      customerId: 'KH001',
      paid: 1000000,
      ship: 150000,
      hold: false,
    );

    expect(command.requestId, 'request-offline-001');
    expect(command.actorId, 'employee-001');
    expect(command.customerId, 'KH001');
    expect(command.paid, 1000000);
    expect(command.ship, 150000);
    expect(command.hold, isFalse);

    expect(command.lines, hasLength(1));
    expect(command.lines.single.productId, 'PR6060VD');
    expect(command.lines.single.area, 144000);
    expect(command.lines.single.note, 'Giao buổi sáng');

    final product = controller.data.product('PR6060VD');

    expect(command.lines.single.quotedPrice, product.price);
    expect(command.lines.single.quotedRatio, product.ratio);

    // Chuẩn bị lệnh không làm thay đổi giỏ hàng.
    expect(controller.cart, hasLength(1));
    expect(controller.requestId, 'request-offline-001');
  });

  test('queueOfflineCheckout lưu hóa đơn vào Drift', () async {
    final id = await controller.queueOfflineCheckout(
      outbox: outbox,
      customerId: 'KH001',
      paid: 1000000,
      ship: 150000,
    );

    expect(id, 'request-offline-001');

    final pending = await outbox.getPending();

    expect(pending, hasLength(1));
    expect(pending.single.id, id);
    expect(pending.single.operationType, 'checkout.v1');
    expect(pending.single.status, 'pending');

    final command = OfflineCheckoutCommand.decode(pending.single.payloadJson);

    expect(command.requestId, id);
    expect(command.actorId, 'employee-001');
    expect(command.customerId, 'KH001');
    expect(command.paid, 1000000);
    expect(command.ship, 150000);
    expect(command.lines.single.area, 144000);
    expect(command.lines.single.note, 'Giao buổi sáng');

    // Chưa được xem là đơn hàng đã đồng bộ.
    expect(controller.cart, hasLength(1));
    expect(controller.requestId, id);
    expect(controller.busy, isFalse);
  });

  test('Không lưu trùng requestId khi gọi hai lần', () async {
    await controller.queueOfflineCheckout(
      outbox: outbox,
      customerId: 'KH001',
      paid: 1000000,
      ship: 150000,
    );

    await expectLater(
      controller.queueOfflineCheckout(
        outbox: outbox,
        customerId: 'KH001',
        paid: 1000000,
        ship: 150000,
      ),
      throwsA(isA<Exception>()),
    );

    final pending = await outbox.getPending();

    expect(pending, hasLength(1));
    expect(pending.single.id, 'request-offline-001');

    expect(controller.cart, hasLength(1));
    expect(controller.busy, isFalse);
  });

  test('Dữ liệu không hợp lệ không được lưu vào Outbox', () async {
    await expectLater(
      controller.queueOfflineCheckout(
        outbox: outbox,
        customerId: '',
        paid: -1000,
        ship: 0,
      ),
      throwsArgumentError,
    );

    final pending = await outbox.getPending();

    expect(pending, isEmpty);
    expect(controller.cart, hasLength(1));
    expect(controller.requestId, 'request-offline-001');
    expect(controller.busy, isFalse);
  });
}
