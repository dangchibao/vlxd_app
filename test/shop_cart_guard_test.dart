import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';

// Giả lập repository Live mà không truy cập Firebase.
class _FakeLiveRepository implements TransactionalShopRepository {
  ShopData state = ShopData.sample();

  @override
  Future<ShopData> load() async => state.copy();

  @override
  Future<void> save(ShopData data) async {
    throw UnsupportedError('Không sử dụng save() ở chế độ Live.');
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
    controller = ShopController(_FakeLiveRepository(), ShopData.sample());
    controller.attachCheckoutOutbox(outbox);
    controller.actor = const Actor('employee-001', Role.owner);
    controller.requestId = 'guard-request-001';
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

  Future<String> queue() => controller.queueOfflineCheckout(
    outbox: outbox,
    customerId: 'KH001',
    paid: 1000000,
    ship: 150000,
  );

  test('Khóa giỏ ngay trong lúc đang lưu Outbox', () async {
    final saving = queue();

    // Trước khi Future hoàn tất, giỏ đã phải ở trạng thái khóa.
    expect(controller.cartEditingLocked, isTrue);
    expect(controller.busy, isTrue);
    expect(
      () => controller.addCart(controller.data.product('PR6060VD'), 14400),
      throwsA(isA<StateError>()),
    );
    expect(() => controller.cart.clear(), throwsA(isA<StateError>()));
    expect(
      () => controller.requestId = 'another-request',
      throwsA(isA<StateError>()),
    );

    expect(await saving, 'guard-request-001');
    expect(controller.busy, isFalse);
    expect(controller.cartEditingLocked, isTrue);
  });

  test('Đơn đã lưu Outbox chặn mọi thao tác sửa giỏ thường dùng', () async {
    await queue();
    final before = List<CartLine>.from(controller.cart);
    final line = before.single;

    expect(() => controller.cart.clear(), throwsA(isA<StateError>()));
    expect(() => controller.cart.remove(line), throwsA(isA<StateError>()));
    expect(() => controller.cart.removeAt(0), throwsA(isA<StateError>()));
    expect(
      () => controller.cart.removeWhere((_) => true),
      throwsA(isA<StateError>()),
    );
    expect(
      () => controller.cart[0] = CartLine(line.productId, 14400),
      throwsA(isA<StateError>()),
    );
    expect(
      () => controller.cart.add(CartLine(line.productId, 14400)),
      throwsA(isA<StateError>()),
    );
    expect(
      () => controller.requestId = 'another-request',
      throwsA(isA<StateError>()),
    );

    expect(controller.cart, orderedEquals(before));
    expect(controller.requestId, 'guard-request-001');
    expect((await outbox.getPending()).single.id, 'guard-request-001');
  });

  test('Không cho checkout online cùng mã đã lưu Outbox', () async {
    await queue();

    await expectLater(
      controller.checkout(customerId: 'KH001', paid: 1000000, ship: 150000),
      throwsA(isA<StateError>()),
    );

    expect(controller.cart, hasLength(1));
    expect(controller.requestId, 'guard-request-001');
    expect((await outbox.getPending()), hasLength(1));
  });

  test('Dữ liệu sai bị từ chối trước khi khóa giỏ', () async {
    await expectLater(
      controller.queueOfflineCheckout(
        outbox: outbox,
        customerId: '',
        paid: -1,
        ship: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(controller.cartEditingLocked, isFalse);
    expect(controller.busy, isFalse);
    expect(await outbox.getPending(), isEmpty);
    controller.addCart(controller.data.product('PR6060VD'), 14400);
    expect(controller.cart.single.area, 158400);
  });

  test('Checkout online không có Outbox vẫn mở khóa sau thành công', () async {
    expect(await outbox.getById(controller.requestId), isNull);

    final order = await controller.checkout(
      customerId: 'KH001',
      paid: 1000000,
      ship: 150000,
    );

    expect(order['requestId'], 'guard-request-001');
    expect(controller.cart, isEmpty);
    expect(controller.cartEditingLocked, isFalse);
    expect(controller.requestId, isNot('guard-request-001'));
    expect(await outbox.getPending(), isEmpty);
  });
}
