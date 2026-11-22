import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Get.reset());

  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Catalog advanced filters are optional and do not alter products', (
    tester,
  ) async {
    viewport(tester, 1440);
    Get.testMode = true;
    final shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
      ..enterDemo(Role.owner);
    final before = jsonEncode(shop.data.toJson());

    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ProductsPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bộ lọc nâng cao'), findsOneWidget);
    expect(find.text('Danh sách gọn'), findsOneWidget);
    expect(find.text('Lọc quy cách / kích thước thực tế'), findsNothing);

    await tester.tap(find.text('Bộ lọc nâng cao'));
    await tester.pumpAndSettle();
    expect(find.text('Lọc quy cách / kích thước thực tế'), findsOneWidget);

    await tester.tap(find.text('Ẩn bộ lọc nâng cao'));
    await tester.pumpAndSettle();
    expect(find.text('Lọc quy cách / kích thước thực tế'), findsNothing);
    expect(jsonEncode(shop.data.toJson()), before);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Compact inventory has quick actions at width $width', (
      tester,
    ) async {
      viewport(tester, width);
      Get.testMode = true;
      final shop = Get.put(
        ShopController(MemoryRepository(), ShopData.sample()),
      )..enterDemo(Role.owner);
      final before = jsonEncode(shop.data.toJson());

      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: InventoryPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Danh sách gọn'), findsOneWidget);
      expect(find.byTooltip('Nhập hàng'), findsWidgets);
      expect(find.byTooltip('Kiểm kê / ảnh kho'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Details are available without invoking stock mutation handlers.
      final tile = find.byType(ExpansionTile).first;
      await tester.ensureVisible(tile);
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(Text)).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Tồn '), findsWidgets);
      expect(jsonEncode(shop.data.toJson()), before);
      expect(tester.takeException(), isNull);
    });
  }
}
