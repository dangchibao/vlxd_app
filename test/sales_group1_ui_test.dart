// Regression for compact checkout UX. No real Firebase, payments or stock writes.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  tearDown(() => Get.reset());

  Future<ShopController> showCart(WidgetTester tester) async {
    Get.testMode = true;
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final shop = Get.put(
      ShopController(MemoryRepository(), ShopData.sample()),
    )..enterDemo(Role.sales);
    shop.addCart(shop.data.product('PR6060VD'), 144000);
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: CartPanel(compact: false))),
    );
    await tester.pumpAndSettle();
    return shop;
  }

  Finder checkout() => find.widgetWithText(FilledButton, 'Chốt đơn mẫu');

  testWidgets('Thanh toán đủ cho khách lẻ; ghi nợ cần khách hàng', (
    tester,
  ) async {
    final shop = await showCart(tester);
    final stock = shop.data.product('PR6060VD').stock;
    expect(find.text('Còn phải thu: 0 đ'), findsOneWidget);
    expect(tester.widget<FilledButton>(checkout()).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('payment-debt')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khách hàng trước khi ghi nợ hoặc giữ hàng.'),
        findsOneWidget);
    expect(find.text('Còn phải thu: ${money(shop.subtotal)}'), findsOneWidget);
    expect(tester.widget<FilledButton>(checkout()).onPressed, isNull);

    // Make the required selection without committing a sale.
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    final name = shop.data.customers.firstWhere(
      (customer) => customer['id'] == 'KH001',
    )['name'] as String;
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(checkout()).onPressed, isNotNull);
    expect(shop.data.orders, isEmpty);
    expect(shop.data.product('PR6060VD').stock, stock);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thanh toán một phần: nhập tiền nhanh, lỗi nhập và trở về trả đủ',
      (tester) async {
    final shop = await showCart(tester);
    final total = shop.subtotal;
    await tester.tap(find.byKey(const ValueKey('payment-partial')));
    await tester.pumpAndSettle();

    // Empty is not silently interpreted as full payment.
    expect(find.textContaining('Một phần phải lớn hơn 0'), findsOneWidget);
    expect(tester.widget<FilledButton>(checkout()).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('payment-quick-30-percent')));
    await tester.pumpAndSettle();
    final expected = (total * 3 / 10).round();
    expect(find.text('Còn phải thu: ${money(total - expected)}'), findsOneWidget);
    expect(tester.widget<FilledButton>(checkout()).onPressed, isNull);

    final paidField = find.byWidgetPredicate(
      (w) => w is TextField &&
          w.decoration?.labelText == 'Số tiền thu lần này (đ)',
    );
    await tester.enterText(paidField, '${total + 1000}');
    await tester.pump();
    expect(find.textContaining('Số tiền thu không hợp lệ'), findsOneWidget);
    expect(tester.widget<FilledButton>(checkout()).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('payment-quick-full')));
    await tester.pumpAndSettle();
    expect(find.text('Còn phải thu: 0 đ'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-summary')), findsOneWidget);
    expect(tester.widget<FilledButton>(checkout()).onPressed, isNotNull);
    expect(shop.data.orders, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
