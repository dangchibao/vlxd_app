import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  tearDown(() => Get.reset());
  test(
    'Legacy product JSON is rendered as changes without mutating the audit',
    () {
      final d = ShopData.sample();
      final before = d.products.first.toJson()..remove('images');
      final after = {...before, 'price': 190000, 'note': 'Giao buổi sáng'};
      final row = <String, dynamic>{
        'action': 'Sửa sản phẩm',
        'target': before['code'],
        'actor': 'admin',
        'detail': '${jsonEncode(before)} → ${jsonEncode(after)}',
      };
      final original = jsonEncode(row);
      final text = auditPresentation(d, row);
      expect(text.title, contains(before['name']));
      expect(text.detail, contains('Giá bán:'));
      expect(text.detail, contains('190.000 đ'));
      expect(text.detail, contains('Lưu ý: Chưa nhập → Giao buổi sáng'));
      expect(text.detail, isNot(contains('"lots"')));
      expect(jsonEncode(row), original);
    },
  );
  test('Sync rows summarize Vietnamese entity counts and do not leak internal identifiers', () {
    final text = auditPresentation(ShopData.sample(), {
      'action': 'Giao dịch đồng bộ',
      'target': 'ce623384-ad48-4e7a-b1f2-1d997e3faa16',
      'actor': 'vTqMT6544MUVsymit010zVhkIo03',
      'detail':
          'products/MAU-GACH-3060, audit/58fefc43-d2c2-4790-b46e-0e976138b895',
    });
    expect(text.title, 'Đã lưu và đồng bộ dữ liệu');
    expect(text.detail, contains('1 sản phẩm'));
    expect('$text', isNot(contains('ce623384')));
    expect('$text', isNot(contains('products/')));
    expect('$text', isNot(contains('vTqMT')));
  });
  test('Delivery/payroll/customer targets resolve to readable subjects; new logs store actor name', () {
    final d = ShopData.sample();
    d.deliveries.add({
      'id': 'GH-ce7180bf',
      'orderId': 'DH-1',
      'driver': 'Phong',
    });
    final trip = auditPresentation(d, {
      'action': 'Hoàn tất chuyến',
      'target': 'GH-ce7180bf',
      'actor': 'admin',
      'detail': 'Đã giao xong',
    });
    expect(trip.title, 'Hoàn tất chuyến • DH-1 • Tài xế Phong');
    expect(trip.title, isNot(contains('GH-')));
    final p = d.payroll.first;
    final salary = auditPresentation(d, {
      'action': 'Sửa lương',
      'target': p['id'],
      'actor': 'admin',
      'detail': '8000000 / 0 → 9000000 / 1000000',
    });
    expect(salary.title, contains(p['name']));
    expect(salary.detail, contains('Đã ứng / trả: 0 đ → 1.000.000 đ'));
    d.log(
      const Actor('staff', Role.sales, displayName: 'Chị Hoa'),
      'Lưu khách hàng',
      'KH001',
      'Đã lưu',
    );
    expect(auditPresentation(d, d.audit.first).person, 'Chị Hoa');
  });
  testWidgets(
    'Delivery heading uses a bold sales order code and audit search finds readable product names',
    (tester) async {
      Get.testMode = true;
      final data = ShopData.sample();
      data.deliveries.add({
        'id': 'GH-ce7180bf',
        'orderId': 'DH-1',
        'driver': 'Phong',
        'vehicle': 'Xe tải',
        'address': 'Gò Dầu',
        'fee': 0,
        'cost': 0,
        'images': [],
        'status': 'Đã xong',
      });
      data.log(
        const Actor('admin', Role.owner),
        'Sửa sản phẩm',
        data.products.first.code,
        'Mới → ${jsonEncode(data.products.first.toJson()..remove('images'))}',
      );
      final c = Get.put(ShopController(MemoryRepository(), data))
        ..enterDemo(Role.owner);
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: DeliveriesPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('GH-ce7180bf'), findsNothing);
      expect(
        tester.widget<Text>(find.text('DH-1')).style!.fontWeight,
        FontWeight.w800,
      );
      expect(find.textContaining('Tài xế: Phong'), findsOneWidget);
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: AuditPage())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), data.products.first.name);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sửa sản phẩm • ${c.data.products.first.name}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
