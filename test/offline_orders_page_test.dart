import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/local/app_database.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/offline_orders.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late ShopController shop;

  setUp(() {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    Get.put<OutboxRepository>(outbox);
    shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()));
    shop.actor = const Actor('employee-001', Role.owner);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  Future<void> addOrder({
    required String id,
    String actorId = 'employee-001',
    String customerId = 'KH001',
  }) async {
    await outbox.enqueueCheckout(
      OfflineCheckoutCommand(
        requestId: id,
        actorId: actorId,
        customerId: customerId,
        lines: const [
          OfflineCheckoutLine(
            productId: 'PR6060VD',
            area: 14400,
            note: 'Giao buổi sáng',
            quotedPrice: 180000,
            quotedRatio: 14400,
          ),
        ],
        paid: 100000,
        ship: 20000,
        hold: false,
        negativeReason: '',
        createdAt: DateTime.utc(2026, 11, 8),
      ),
    );
  }

  Future<void> openPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GetMaterialApp(home: OfflineOrdersPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('Hiển thị pending và xem chi tiết từ SQLite', (tester) async {
    await addOrder(id: 'offline-page-001');
    await openPage(tester);

    expect(
      find.byKey(const ValueKey('offline-order-offline-page-001')),
      findsOneWidget,
    );
    expect(find.textContaining('Chờ đồng bộ'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('offline-order-offline-page-001')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết đơn offline'), findsOneWidget);
    expect(find.text('Khách hàng: KH001'), findsOneWidget);
    expect(find.text('Tiền đã thu (đ): 100000'), findsOneWidget);
    expect(find.text('Phí giao hàng (đ): 20000'), findsOneWidget);
    expect(find.text('PR6060VD'), findsOneWidget);
    expect(find.textContaining('Giao buổi sáng'), findsOneWidget);
    expect((await outbox.getById('offline-page-001'))!.status, 'pending');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hiển thị failed nhưng không tự gửi hay đổi trạng thái', (
    tester,
  ) async {
    await addOrder(id: 'offline-page-failed');
    await outbox.markFailed('offline-page-failed', 'Cần đối chiếu server');
    final before = (await outbox.getById('offline-page-failed'))!;

    await openPage(tester);
    expect(find.textContaining('Cần xác minh'), findsWidgets);
    await tester.tap(find.byTooltip('Làm mới danh sách'));
    await tester.pumpAndSettle();

    final after = (await outbox.getById('offline-page-failed'))!;
    expect(after.status, 'failed');
    expect(after.attempts, before.attempts);
    expect(after.lastError, before.lastError);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mở lại trang đọc lại Outbox, chỉ thấy đơn của actor', (
    tester,
  ) async {
    await addOrder(id: 'offline-page-mine');
    await addOrder(id: 'offline-page-other', actorId: 'other-employee');
    await openPage(tester);

    expect(
      find.byKey(const ValueKey('offline-order-offline-page-mine')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('offline-order-offline-page-other')),
      findsNothing,
    );

    // Gỡ trang để hủy State/Future, nhưng giữ nguyên SQLite và GetX.
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    await outbox.markSynced('offline-page-mine');
    await tester.pumpWidget(const GetMaterialApp(home: OfflineOrdersPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('offline-order-offline-page-mine')),
      findsOneWidget,
    );
    expect(find.textContaining('Server đã xác nhận'), findsWidgets);
    expect(
      find.byKey(const ValueKey('offline-order-offline-page-other')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
