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

  void setViewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Hàng hóa compact: chi tiết ngang và giữ 4 thao tác', (tester) async {
    setViewport(tester, 1440);
    Get.testMode = true;
    final shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
      ..enterDemo(Role.owner);
    final before = jsonEncode(shop.data.toJson());
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ProductsPage())),
    );
    await tester.pumpAndSettle();

    final compactChip = find.widgetWithText(FilterChip, 'Danh sách gọn');
    if (!tester.widget<FilterChip>(compactChip).selected) {
      await tester.tap(compactChip);
      await tester.pumpAndSettle();
    }
    final item = find.byType(ExpansionTile).first;
    await tester.ensureVisible(item);
    await tester.tap(find.descendant(of: item, matching: find.byType(Text)).first);
    await tester.pumpAndSettle();

    expect(find.text('Quy cách / hãng'), findsWidgets);
    expect(find.text('Giá vốn lô gần nhất'), findsWidgets);
    expect(find.byTooltip('Sửa sản phẩm'), findsWidgets);
    expect(find.byTooltip('Mã vạch & In'), findsWidgets);
    expect(find.byTooltip('Ngừng kinh doanh (không xóa dữ liệu)'), findsWidgets);
    expect(jsonEncode(shop.data.toJson()), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hàng hóa mobile 320: chi tiết và menu vẫn sử dụng được', (tester) async {
    setViewport(tester, 320);
    Get.testMode = true;
    final shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
      ..enterDemo(Role.owner);
    final before = jsonEncode(shop.data.toJson());
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: ProductsPage())),
    );
    await tester.pumpAndSettle();

    final details = find.byTooltip('Xem chi tiết sản phẩm');
    expect(details, findsWidgets);
    expect(find.byTooltip('Thao tác với ${shop.catalogProducts.first.name}'), findsWidgets);
    await tester.tap(details.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Giá bán:'), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(jsonEncode(shop.data.toJson()), before);
  });

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Kho compact: thông tin tồn co giãn ở $width', (tester) async {
      setViewport(tester, width);
      Get.testMode = true;
      final shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
        ..enterDemo(Role.owner);
      final before = jsonEncode(shop.data.toJson());
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: InventoryPage())),
      );
      await tester.pumpAndSettle();
      final compactChip = find.widgetWithText(FilterChip, 'Danh sách gọn');
      if (!tester.widget<FilterChip>(compactChip).selected) {
        await tester.tap(compactChip);
        await tester.pumpAndSettle();
      }
      final tile = find.byType(ExpansionTile).first;
      await tester.ensureVisible(tile);
      await tester.tap(find.descendant(of: tile, matching: find.byType(Text)).first);
      await tester.pumpAndSettle();

      expect(find.text('Tồn thực tế'), findsWidgets);
      expect(find.text('Đang giữ'), findsWidgets);
      expect(find.text('Khả dụng'), findsWidgets);
      expect(find.byTooltip('Nhập hàng'), findsWidgets);
      expect(find.byTooltip('Kiểm kê / ảnh kho'), findsWidgets);
      expect(jsonEncode(shop.data.toJson()), before);
      expect(tester.takeException(), isNull);
    });
  }
}
