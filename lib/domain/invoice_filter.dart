import 'shop.dart';

enum InvoicePayment { all, unpaid, partial, paid, owing }

class InvoiceFilter {
  final String query;
  final InvoicePayment payment;
  final DateTime? from, through;
  final int? minimum, maximum;
  const InvoiceFilter({
    this.query = '',
    this.payment = InvoicePayment.all,
    this.from,
    this.through,
    this.minimum,
    this.maximum,
  });

  bool get valid =>
      (minimum == null || minimum! >= 0) &&
      (maximum == null || maximum! >= 0) &&
      (minimum == null || maximum == null || minimum! <= maximum!) &&
      (from == null || through == null || !from!.isAfter(through!));

  bool matches(Json order, String customerText) {
    if (!valid || order['status'] != 'Đã bán') return false;
    if (!'${order['id']} $customerText'.toLowerCase().contains(
      query.trim().toLowerCase(),
    )) {
      return false;
    }
    final sold = DateTime.tryParse(order['soldAt'] ?? order['at'])?.toLocal();
    if (sold == null) return false;
    if (from != null &&
        sold.isBefore(DateTime(from!.year, from!.month, from!.day))) {
      return false;
    }
    if (through != null &&
        !sold.isBefore(
          DateTime(through!.year, through!.month, through!.day + 1),
        )) {
      return false;
    }
    final total = order['total'] as int;
    if (minimum != null && total < minimum!) return false;
    if (maximum != null && total > maximum!) return false;
    final paid = ShopData.collected(order);
    return switch (payment) {
      InvoicePayment.all => true,
      InvoicePayment.unpaid => paid == 0 && total > 0,
      InvoicePayment.partial => paid > 0 && paid < total,
      InvoicePayment.paid => paid >= total,
      InvoicePayment.owing => paid < total,
    };
  }
}
