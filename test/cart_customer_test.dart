import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

Finder input(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  tearDown(() => Get.reset());

  for (final width in [390.0, 1700.0]) {
    testWidgets(
      'New customer is saved, selected and attached to the paid invoice at $width',
      (tester) async {
        Get.testMode = true;
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
          ..enterDemo(Role.sales);
        c.addCart(c.data.products.first, 14400);
        await tester.pumpWidget(
          const GetMaterialApp(home: Scaffold(body: CartPanel(compact: true))),
        );
        await tester.pumpAndSettle();
        await tester.enterText(input('Phí giao hàng (đ)'), '50000');
        await tester.tap(find.text('Thêm khách hàng mới'));
        await tester.pumpAndSettle();
        await tester.enterText(
          input('Họ tên / công trình'),
          'Khách mới chị Hương',
        );
        await tester.enterText(input('Số điện thoại'), '0901234567');
        await tester.tap(find.text('Lưu'));
        await tester.pumpAndSettle();
        final customer = c.data.customers.singleWhere(
          (p) => p['name'] == 'Khách mới chị Hương',
        );
        final selector = find.byType(DropdownButtonFormField<String>);
        expect(
          tester.widget<DropdownButtonFormField<String>>(selector).initialValue,
          customer['id'],
        );

        expect(find.text('Khách mới chị Hương'), findsWidgets);
        expect(
          tester.widget<TextField>(input('Phí giao hàng (đ)')).controller!.text,
          '50 000',
        );

        expect(c.cart, hasLength(1));
        final discount = width == 390 ? 25000 : 0;
        final subtotal = c.subtotal;
        if (discount > 0) {
          expect(input('Số tiền giảm giá (đ)'), findsNothing);
          await tester.ensureVisible(find.text('Giảm giá'));
          await tester.tap(find.text('Giảm giá'));
          await tester.pumpAndSettle();
          await tester.enterText(input('Số tiền giảm giá (đ)'), '$discount');
          await tester.pump();
          expect(find.text(money(subtotal + 50000 - discount)), findsOneWidget);
        }

        // Opening the list proves the saved customer is also available for later selection.
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Khách mới chị Hương').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Chốt đơn mẫu'));
        await tester.tap(find.text('Chốt đơn mẫu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        final order = c.data.orders.single;
        expect(order['customerId'], customer['id']);
        expect(order['discount'] ?? 0, discount);
        expect(order['ship'], 50000);
        expect(order['total'], subtotal + 50000 - discount);
        expect(ShopData.collected(order), order['total']);
        expect(find.text('Khách hàng: Khách mới chị Hương'), findsOneWidget);
        expect(c.data.debt(customer['id']), 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Cancel or save failure does not select an unsaved customer', (
    tester,
  ) async {
    Get.testMode = true;
    final repository = MemoryRepository();
    final c = Get.put(ShopController(repository, ShopData.sample()))
      ..enterDemo(Role.sales);
    final count = c.data.customers.length;
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CartPanel(compact: true))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm khách hàng mới'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Họ tên / công trình'), 'Khách chưa lưu');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(c.data.customers.length, count);
    repository.fail = true;
    await tester.tap(find.text('Thêm khách hàng mới'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Họ tên / công trình'), 'Khách lỗi mạng');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin khách hàng'), findsOneWidget);
    expect(c.data.customers.length, count);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      '',
    );
    expect(tester.takeException(), isNull);
  });
}
