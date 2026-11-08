import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

class GuardTestRepository implements TransactionalShopRepository {
  ShopData state = ShopData.sample();

  @override
  Future<ShopData> load() async => state.copy();

  @override
  Future<void> save(ShopData data) async {
    throw UnsupportedError('Test không ghi Firebase.');
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
    Get.testMode = true;

    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);

    Get.put<OutboxRepository>(outbox);

    controller = Get.put(
      ShopController(GuardTestRepository(), ShopData.sample()),
    );

    controller.attachCheckoutOutbox(outbox);
    controller.actor = const Actor('employee-001', Role.owner);
    controller.requestId = 'guard-test-001';

    controller.addCart(controller.data.product('PR6060VD'), 144000);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  testWidgets('Giỏ hàng bị khóa khi request đã nằm trong Outbox', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final command = controller.prepareOfflineCheckout(
      customerId: 'KH001',
      paid: 1000000,
      ship: 150000,
    );

    await outbox.enqueueCheckout(command);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CartPanel(compact: false))),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Chờ đồng bộ Firebase'), findsWidgets);

    final removeButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Bỏ khỏi giỏ',
    );

    expect(removeButton, findsOneWidget);

    expect(tester.widget<IconButton>(removeButton).onPressed, isNull);

    final product = controller.data.product('PR6060VD');

    final decreaseButton = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.tooltip == 'Bớt một ${product.packUnit}',
    );

    final increaseButton = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.tooltip == 'Thêm một ${product.packUnit}',
    );

    expect(decreaseButton, findsOneWidget);
    expect(increaseButton, findsOneWidget);

    expect(tester.widget<IconButton>(decreaseButton).onPressed, isNull);

    expect(tester.widget<IconButton>(increaseButton).onPressed, isNull);

    expect(controller.cart, hasLength(1));
    expect(controller.requestId, 'guard-test-001');

    expect(tester.takeException(), isNull);
  });
}
