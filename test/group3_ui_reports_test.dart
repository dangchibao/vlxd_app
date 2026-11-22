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
  tearDown(() => Get.reset());

  test('Top sản phẩm theo tiền tính mọi đơn vị, không gộp sai mã', () {
    Json line(String id, String name, int amount, String unit) => {
      if (id.isNotEmpty) 'productId': id,
      'name': name,
      'code': id,
      'unit': unit,
      'amount': amount,
    };
    final ranked = bestSellingByValue([
      {
        'status': 'Đã bán',
        'lines': [
          line('A', 'Keo bao', 170000, 'bao'),
          line('B', 'Gach', 100000, 'm²'),
          line('', 'Cu', 4000, 'cái'),
        ],
      },
      {
        'status': 'Đã bán',
        'lines': [
          line('A', 'Keo doi ten', 20000, 'bao'),
          line('', 'Cu', 5000, 'cái'),
        ],
      },
      {'status': 'Giữ hàng', 'lines': [line('A', 'Keo bao', 999999, 'bao')]},
      {'status': 'Đã hủy', 'lines': [line('A', 'Keo bao', 999999, 'bao')]},
      {'status': 'Đã trả hàng', 'lines': [line('B', 'Gach', 999999, 'm²')]},
    ]);
    expect(ranked.first.code, 'A');
    expect(ranked.first.total, 190000);
    expect(ranked[1].code, 'B');
    expect(ranked[1].total, 100000);
    expect(ranked.where((row) => row.code.isEmpty), hasLength(2));
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('Nợ và Lương là hai chế độ riêng biệt $width', (tester) async {
      tester.view.physicalSize = Size(width, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.testMode = true;
      final data = ShopData.sample();
      final before = jsonEncode(data.toJson());
      final c = Get.put(ShopController(MemoryRepository(), data))
        ..enterDemo(Role.owner);
      c.navigate(5);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      expect(find.text('Sổ công nợ khách hàng'), findsOneWidget);
      expect(find.text('Lương nhân viên'), findsOneWidget); // tab label only
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lương nhân viên'));
      await tester.pumpAndSettle();
      expect(find.text('Sổ công nợ khách hàng'), findsNothing);
      expect(find.text('Tạo kỳ lương'), findsOneWidget);
      expect(jsonEncode(c.data.toJson()), before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bộ lọc hóa đơn mặc định gọn, mở được khi cần $width', (tester) async {
      tester.view.physicalSize = Size(width, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Get.testMode = true;
      final data = ShopData.sample();
      final before = jsonEncode(data.toJson());
      final c = Get.put(ShopController(MemoryRepository(), data))
        ..enterDemo(Role.owner);
      c.navigate(9);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invoice-search')), findsOneWidget);
      expect(find.byKey(const ValueKey('period-Toàn bộ')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('invoice-filter-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('period-Toàn bộ')), findsOneWidget);
      expect(jsonEncode(c.data.toJson()), before);
      expect(tester.takeException(), isNull);
    });
  }
}
