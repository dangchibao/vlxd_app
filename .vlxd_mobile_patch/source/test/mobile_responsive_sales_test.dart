// Mobile presentation regression tests. No Firestore or production writes.
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

  Future<ShopController> openApp(WidgetTester tester, double width, int page) async {
    Get.testMode = true;
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
      ..enterDemo(Role.owner);
    shop.navigate(page);
    await tester.pumpWidget(const BayHaiApp());
    await tester.pumpAndSettle();
    return shop;
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('mobile sales has six compact actions and product list at $width', (tester) async {
      final shop = await openApp(tester, width, 2);
      expect(find.byKey(const ValueKey('mobile-sales-actions')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-sales-product-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-create-product')), findsOneWidget);
      expect(find.byKey(const ValueKey('restore-local-cart-draft')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-scan-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-sold-invoices')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-offline-orders')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-order-history')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-sales-open-cart')), findsOneWidget);
      expect(find.byKey(ValueKey('mobile-sale-card-${shop.visibleProducts.first.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick quantity opens the original confirmation without touching stock', (tester) async {
    final shop = await openApp(tester, 390, 2);
    final product = shop.visibleProducts.first;
    final initialStock = product.stock;
    await tester.tap(find.byKey(ValueKey('mobile-qty-plus-${product.id}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('mobile-add-to-cart-${product.id}')));
    await tester.pumpAndSettle();
    final quantity = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.labelText == 'Số lượng (thùng)');
    expect(quantity, findsOneWidget);
    expect(tester.widget<TextField>(quantity).controller!.text, '2');
    expect(shop.cart, isEmpty);
    expect(shop.data.product(product.id).stock, initialStock);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile catalog keeps item actions and compact filters', (tester) async {
    final shop = await openApp(tester, 390, 1);
    expect(find.byKey(const ValueKey('mobile-catalog-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-catalog-create')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-catalog-product-list')), findsOneWidget);
    expect(find.byKey(ValueKey('mobile-catalog-card-${shop.catalogProducts.first.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop sales retains original cards and visible action labels', (tester) async {
    await openApp(tester, 1440, 2);
    expect(find.byKey(const ValueKey('mobile-sales-actions')), findsNothing);
    expect(find.text('Tạo sản phẩm'), findsOneWidget);
    expect(find.text('Khôi phục giỏ nháp'), findsNothing); // Demo mode
    expect(tester.takeException(), isNull);
  });
}
