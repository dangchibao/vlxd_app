import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/demo_repository.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

class _FakeLiveRepository implements TransactionalShopRepository {
  ShopData state = ShopData.sample();
  int transactions = 0;

  @override
  Future<ShopData> load() async => state.copy();

  @override
  Future<void> save(ShopData data) async {
    throw UnsupportedError('Không ghi dữ liệu Firebase trong test.');
  }

  @override
  Stream<ShopData> watch() => const Stream<ShopData>.empty();

  @override
  Future<({ShopData data, T result})> transact<T>(
    T Function(ShopData data, Actor actor) operation,
    Actor actor,
  ) async {
    transactions++;
    final next = state.copy();
    final result = operation(next, actor);
    state = next;
    return (data: next, result: result);
  }
}

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;

  setUp(() {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    Get.put<OutboxRepository>(outbox);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  Future<void> showCart(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CartPanel(compact: false))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Live: lưu offline chỉ ghi Drift, khóa lần lưu tiếp theo', (
    tester,
  ) async {
    final repository = _FakeLiveRepository();
    final controller = Get.put(ShopController(repository, ShopData.sample()));
    controller.attachCheckoutOutbox(outbox);
    controller.actor = const Actor('employee-001', Role.owner);
    controller.requestId = 'offline-ui-001';
    controller.addCart(controller.data.product('PR6060VD'), 144000);

    await showCart(tester);

    final save = find.byKey(const ValueKey('save-offline-checkout'));
    expect(save, findsOneWidget);

    // Chọn khách hàng thật trong dữ liệu mẫu; khách lẻ rỗng bị từ chối.
    final customer = controller.data.customers.firstWhere(
      (p) => p['id'] == 'KH001',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(customer['name'] as String).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Lưu đơn offline trên máy?'), findsOneWidget);
    expect(await outbox.getPending(), isEmpty);

    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();

    final saved = await outbox.getById('offline-ui-001');
    expect(saved, isNotNull);
    expect(saved!.status, 'pending');
    final command = OfflineCheckoutCommand.decode(saved.payloadJson);
    expect(command.customerId, 'KH001');
    expect(command.lines.single.area, 144000);
    expect(repository.transactions, 0);
    expect(controller.cart, hasLength(1));
    expect(controller.cartEditingLocked, isTrue);
    expect(controller.requestId, 'offline-ui-001');
    expect(find.textContaining('Chờ đồng bộ Firebase'), findsWidgets);

    final saveButton = tester.widget<OutlinedButton>(save);
    expect(saveButton.onPressed, isNull);
    expect((await outbox.getPending()), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo: không hiển thị nút lưu offline', (tester) async {
    final controller = Get.put(
      ShopController(MemoryRepository(), ShopData.sample()),
    )..enterDemo(Role.owner);
    controller.addCart(controller.data.product('PR6060VD'), 144000);

    await showCart(tester);

    expect(find.byKey(const ValueKey('save-offline-checkout')), findsNothing);
    expect(find.text('Chốt đơn mẫu'), findsOneWidget);
    expect((await outbox.getPending()), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
