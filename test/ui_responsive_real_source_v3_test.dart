// UI-only smoke tests: no Firestore writes, no product/invoice mutations.
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

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'small screen $width: summary, products, warehouse and debt render',
      (tester) async {
        Get.testMode = true;
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final shop = Get.put(
          ShopController(MemoryRepository(), ShopData.sample()),
        )..enterDemo(Role.owner);
        await tester.pumpWidget(const BayHaiApp());
        for (final page in [0, 1, 3, 5]) {
          shop.navigate(page);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'page $page / width $width',
          );
        }
      },
    );
  }

  testWidgets(
    'phone has compact catalog and can still open details and correction',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final shop = Get.put(
        ShopController(MemoryRepository(), ShopData.sample()),
      )..enterDemo(Role.owner);
      shop.navigate(1);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      final product = shop.catalogProducts.first;
      await tester.tap(
        find.byKey(ValueKey('mobile-catalog-options-${product.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết'), findsOneWidget);
      await tester.tap(find.text('Chi tiết'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Giá bán:'), findsWidgets);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
