import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/shop.dart';

void main() {
  const owner = Actor('owner', Role.owner);
  const sales = Actor('sales', Role.sales);

  Product item({String id = 'p-1', String code = 'SP001',
      int stock = 0}) => Product(
        id: id, code: code, name: 'Keo dán gạch', size: '25kg',
        supplier: 'A', price: 100000, ratio: 0, unitLabel: 'bao',
        lots: stock == 0 ? [] : [{
          'id': 'lot-1', 'date': '2026-01-01T00:00:00',
          'area': stock, 'reserved': 0, 'cost': 65000, 'ratio': 0,
        }],
      );

  test('deleting unused SKU then restoring reuses original identity', () {
    final d = ShopData.empty();
    d.products.add(item());
    d.deleteUnusedProduct('p-1', owner);
    expect(d.product('p-1').deleted, true);
    expect(() => d.saveProduct(item(id: 'p-2', code: 'SP002'), owner),
        throwsStateError);
    d.restoreDeletedProduct('p-1', owner);
    expect(d.product('p-1').deleted, false);
    expect(d.product('p-1').code, 'SP001');
    expect(d.products.length, 1);
  });

  test('product with stock history cannot silently change SKU', () {
    final d = ShopData.empty();
    final before = item(stock: 20000);
    d.products.add(before);
    final changed = Product.fromJson(before.toJson())..code = 'SP777';
    expect(() => d.saveProduct(changed, owner, expected: before),
        throwsStateError);
  });

  test('receive refuses duplicate lot ID without adjusting quantity', () {
    final d = ShopData.empty();
    d.products.add(item(stock: 30000));
    expect(() => d.receive('p-1', 20000, 50000, DateTime(2026, 1, 1),
        owner, 'lot-1'), throwsStateError);
    expect(d.product('p-1').stock, 30000);
  });

  test('only owner approves negative sales exception', () {
    final d = ShopData.empty();
    d.products.add(item(stock: 10000));
    expect(() => d.checkout(requestId: 'req-sales',
        lines: [const CartLine('p-1', 20000)], customerId: '',
        paid: 200000, ship: 0, hold: false, actor: sales,
        negativeReason: 'Đã báo chủ'), throwsStateError);
    expect(d.product('p-1').stock, 10000);
    final order = d.checkout(requestId: 'req-owner',
        lines: [const CartLine('p-1', 20000)], customerId: '',
        paid: 200000, ship: 0, hold: false, actor: owner,
        negativeReason: 'Chủ chấp thuận bán âm');
    expect(order['status'], 'Đã bán');
    expect(d.product('p-1').stock, -10000);
  });

  test('customer contact is snapshotted at checkout', () {
    final d = ShopData.empty();
    d.products.add(item(stock: 20000));
    d.customers.add({'id':'KH1','name':'Anh Nam','phone':'0909000000',
      'address':'Gò Dầu', 'active':true});
    final order = d.checkout(requestId: 'contact-1',
        lines: [const CartLine('p-1', 10000)], customerId: 'KH1',
        paid: 100000, ship: 0, hold: false, actor: owner);
    d.customers.first['address'] = 'Địa chỉ mới';
    expect(order['customerName'], 'Anh Nam');
    expect(order['customerAddress'], 'Gò Dầu');
  });

  test('refund of held deposit needs owner and positive confirmation', () {
    final d = ShopData.empty();
    d.products.add(item(stock: 20000));
    d.customers.add({'id':'KH1','name':'Anh Nam','phone':'', 'active':true});
    final order = d.checkout(requestId: 'hold-1',
        lines: [const CartLine('p-1', 10000)], customerId: 'KH1',
        paid: 50000, ship: 0, hold: true, actor: sales);
    expect(() => d.cancelHeld(order['id'], 'Hủy theo yêu cầu', sales,
        depositRefunded:true, refundMethod:'Tiền mặt'), throwsStateError);
    expect(() => d.cancelHeld(order['id'], 'Hủy theo yêu cầu', owner),
        throwsStateError);
    d.cancelHeld(order['id'], 'Hủy theo yêu cầu', owner,
        depositRefunded:true, refundMethod:'Tiền mặt');
    expect(order['refund'], 50000);
    expect(order['refundConfirmedBy'], 'owner');
  });

  test('hidden return lot becomes visible when stock increases', () {
    final d = ShopData.empty();
    final p = item(stock: 10000);
    d.products.add(p);
    final order = d.checkout(requestId:'return-1',
      lines:[const CartLine('p-1', 10000)], customerId:'',
      paid:100000, ship:0, hold:false, actor:owner);
    p.lots.first['hiddenFromInventory'] = true;
    d.returnSoldOrder(order['id'], 'Đã hoàn trả đủ tiền', owner,
      cashWasReturned:true);
    expect(p.stock,10000);
    expect(p.lots.first['hiddenFromInventory'],false);
  });

  test('cancelled delivery cannot be completed or edited via domain', () {
    final d = ShopData.empty();
    d.deliveries.add({'id':'GH-1','status':'Đang giao'});
    d.cancelDelivery('GH-1', 'Xe hỏng đột xuất', sales);
    expect(d.deliveries.first['status'], 'Đã hủy');
    expect(() => d.finishDelivery('GH-1', owner), throwsStateError);
  });

  test('payroll mutation is reserved for owner', () {
    final d = ShopData.empty();
    d.payroll.add({'id':'NV1','salary':5000000,'advance':0});
    expect(() => d.setSalary('NV1', 6000000, 0, sales), throwsStateError);
    d.setSalary('NV1',6000000,0,owner);
    expect(d.payroll.first['salary'],6000000);
  });
}
