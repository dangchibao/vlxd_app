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

  testWidgets(
    'Sales staff can create and edit prices from the sales catalog without rewriting old invoices',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final data = ShopData.sample();

      final order = data.checkout(
        requestId: 'old-price',
        lines: [const CartLine('PR6060VD', 14400)],
        customerId: 'KH001',
        paid: 0,
        ship: 0,
        hold: false,
        actor: const Actor('owner', Role.owner),
      );

      final originalTotal = order['total'];

      final c = Get.put(ShopController(MemoryRepository(), data))
        ..enterDemo(Role.sales);

      c.navigate(2);
      c.query = 'PR6060VD';

      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();

      // Kiểm tra mở chức năng sửa sản phẩm.
      await tester.tap(
        find.byKey(const ValueKey('edit-sale-product-PR6060VD')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm sản phẩm vào giỏ?'), findsNothing);

      // Thay đổi giá bán.
      await tester.enterText(input('Giá bán đ/đơn vị (m² hoặc m³)'), '199000');

      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(c.data.product('PR6060VD').price, 199000);

      expect(find.text('${money(199000)} / m²'), findsOneWidget);

      // Hóa đơn cũ không được thay đổi.
      expect(c.data.orders.first['total'], originalTotal);

      // Kiểm tra tạo sản phẩm mới.
      await tester.tap(find.text('Tạo sản phẩm'));
      await tester.pumpAndSettle();

      await tester.enterText(input('Mã sản phẩm / mã vạch'), 'NEW-TEST');

      await tester.enterText(input('Tên sản phẩm'), 'Gạch mới');

      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      expect(c.data.products.where((p) => p.code == 'NEW-TEST'), hasLength(1));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Archive product protects cart and preserves stock', (
    tester,
  ) async {
    Get.testMode = true;
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
      ..enterDemo(Role.owner);

    c.navigate(2);
    c.query = 'PR6060VD';

    final product = c.data.product('PR6060VD');
    final stock = product.stock;

    // BƯỚC 1: Thêm sản phẩm vào giỏ hàng nháp.
    c.addCart(product, 14400);

    await tester.pumpWidget(const BayHaiApp());
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey('delete-sale-product-PR6060VD'),
    );

    expect(deleteButton, findsOneWidget);
    expect(c.cart, hasLength(1));

    // BƯỚC 2: Không cho ngừng bán khi sản phẩm còn trong giỏ.
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(c.data.product('PR6060VD').active, isTrue);

    expect(c.cart, hasLength(1));
    expect(c.cart.single.productId, 'PR6060VD');

    // Hộp thoại xác nhận ngừng bán không được mở.
    expect(find.text('Xác nhận'), findsNothing);

    // BƯỚC 3: Xóa giỏ nháp chủ động trong chế độ Demo.
    c.cart.clear();
    c.update();

    await tester.pumpAndSettle();

    expect(c.cart, isEmpty);

    // BƯỚC 4: Mở xác nhận ngừng bán rồi chọn Hủy.
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Hủy'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(c.data.product('PR6060VD').active, isTrue);

    // BƯỚC 5: Xác nhận ngừng kinh doanh.
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận'), findsOneWidget);

    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();

    // BƯỚC 6: Xác minh sản phẩm bị ẩn,
    // tồn kho và giỏ hàng không bị thay đổi ngoài ý muốn.
    expect(c.data.product('PR6060VD').active, isFalse);

    expect(c.data.product('PR6060VD').stock, stock);

    expect(c.cart, isEmpty);

    expect(deleteButton, findsNothing);

    // Cho Snackbar của GetX hoàn tất trước khi kết thúc widget test.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
