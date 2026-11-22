// Verify that const mobile children do not freeze after controller updates.
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

  for (final page in [1, 2]) {
    testWidgets('mobile page $page updates product on the same tab', (
      tester,
    ) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shop = Get.put(
        ShopController(MemoryRepository(), ShopData.sample()),
      )..enterDemo(Role.owner);
      shop.navigate(page);
      final id = page == 1
          ? shop.catalogProducts.first.id
          : shop.visibleProducts.first.id;
      shop.query = shop.data.product(id).code;
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();

      shop.data = shop.data.copy();
      shop.data.product(id).name = 'San pham vua cap nhat';
      shop.update();
      await tester.pumpAndSettle();
      expect(find.text('San pham vua cap nhat'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
