import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/procurement_draft.dart';

void main() {
  test('Don mua nhap dung gia tong va chan ma nha cung cap trung', () {
    final book = ProcurementDraftBook();
    book.addSupplier(const SupplierDraft(id:'NCC001',name:'Nha cung cap A'));
    final order = PurchaseDraft(id:'PN001',supplierId:'NCC001',lines:[
      const PurchaseDraftLine(productId:'SP0001',quantity:15000,costPerUnit:100000),
    ]);
    book.createOrder(order);
    expect(order.total, 150000);
    expect(() => book.addSupplier(const SupplierDraft(id:'NCC001',name:'B')),
        throwsStateError);
  });
}
