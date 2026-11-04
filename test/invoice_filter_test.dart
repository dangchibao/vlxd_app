import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/domain/invoice_filter.dart';
import 'package:vlxd_app/domain/shop.dart';

Json invoice({
  int paid = 500,
  int total = 1000,
  String status = 'Đã bán',
  String? soldAt,
}) => {
  'id': 'DH-42',
  'status': status,
  'total': total,
  'at': DateTime(2026, 1, 1).toUtc().toIso8601String(),
  'soldAt': soldAt,
  'payments': [
    if (paid > 0) {'amount': paid},
    {'amount': 10000, 'voided': true},
  ],
};

void main() {
  test('Payment filters use effective receipts and exclude held or cancelled orders', () {
    expect(
      const InvoiceFilter(payment: InvoicePayment.partial)
          .matches(invoice(), 'Bảo'),
      isTrue,
    );
    expect(
      const InvoiceFilter(payment: InvoicePayment.unpaid)
          .matches(invoice(paid: 0), 'Bảo'),
      isTrue,
    );
    expect(
      const InvoiceFilter(payment: InvoicePayment.paid)
          .matches(invoice(paid: 1000), 'Bảo'),
      isTrue,
    );
    expect(
      const InvoiceFilter(payment: InvoicePayment.owing)
          .matches(invoice(paid: 1000), 'Bảo'),
      isFalse,
    );
    expect(
      const InvoiceFilter().matches(invoice(status: 'Giữ hàng'), 'Bảo'),
      isFalse,
    );
    expect(
      const InvoiceFilter().matches(invoice(status: 'Đã hủy'), 'Bảo'),
      isFalse,
    );
  });
  test(
    'Sale date uses fulfilment date and includes the whole final local day',
    () {
      final filter = InvoiceFilter(
        from: DateTime(2026, 11, 4),
        through: DateTime(2026, 11, 4),
      );
      expect(
        filter.matches(
          invoice(
            soldAt: DateTime(2026, 11, 4, 23, 59, 59).toUtc().toIso8601String(),
          ),
          'Test',
        ),
        isTrue,
      );
      expect(
        filter.matches(
          invoice(soldAt: DateTime(2026, 11, 5).toUtc().toIso8601String()),
          'Test',
        ),
        isFalse,
      );
      expect(filter.matches(invoice(), 'Test'), isFalse);
    },
  );
  test('Amount bounds are inclusive; invalid ranges cannot silently return all invoices', () {
    expect(
      const InvoiceFilter(
        minimum: 1000,
        maximum: 1000,
      ).matches(invoice(), 'Test'),
      isTrue,
    );
    expect(
      const InvoiceFilter(minimum: 1001).matches(invoice(), 'Test'),
      isFalse,
    );
    expect(const InvoiceFilter(minimum: -1).valid, isFalse);
    expect(
      const InvoiceFilter(
        minimum: 2000,
        maximum: 1000,
      ).matches(invoice(), 'Test'),
      isFalse,
    );
  });
  test(
    'Search combines invoice code and customer with date/payment/amount',
    () {
      const filter = InvoiceFilter(
        query: '  dh-42 ',
        minimum: 900,
        payment: InvoicePayment.partial,
      );
      expect(filter.matches(invoice(), 'Đặng Chí Bảo'), isTrue);
      expect(
        const InvoiceFilter(query: 'bảo').matches(invoice(), 'Đặng Chí Bảo'),
        isTrue,
      );
      expect(filter.matches(invoice(paid: 1000), 'Đặng Chí Bảo'), isFalse);
    },
  );
  test('Bulk material quantities use cubic metres and preserve sale unit on snapshots', () {
    final data = ShopData.empty();
    final p = Product(
      id: 'CAT',
      code: 'CAT',
      name: 'Cát',
      size: 'm³',
      supplier: 'Mẫu',
      price: 350000,
      ratio: 10000,
      lots: [
        {
          'id': 'lot',
          'date': DateTime.now().toIso8601String(),
          'area': 250000,
          'reserved': 0,
          'cost': 240000,
          'ratio': 10000,
        },
      ],
    );
    data.products.add(p);
    final order = data.checkout(
      requestId: 'bulk',
      lines: [const CartLine('CAT', 25000)],
      customerId: '',
      paid: 875000,
      ship: 0,
      hold: false,
      actor: const Actor('owner', Role.owner),
    );
    expect(order['total'], 875000);
    expect((order['lines'] as List).single['unit'], 'm³');
    expect(p.stock, 225000);
    expect(Product.fromJson(p.toJson()).unit, 'm³');
    final changed = Product.fromJson(p.toJson())..size = '60×60';
    expect(
      () => data.saveProduct(
        changed,
        const Actor('owner', Role.owner),
        expected: p,
      ),
      throwsStateError,
    );
  });
}
