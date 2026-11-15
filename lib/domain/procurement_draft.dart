/// Stage 1 procurement domain. This is deliberately NOT persisted to Firestore,
/// NOT wired to inventory, and NOT a payable ledger until rules and backend
/// atomic transactions have been reviewed. Safe to use for design/tests only.
class ProcurementDraftBook {
  final Map<String, SupplierDraft> suppliers = {};
  final Map<String, PurchaseDraft> orders = {};

  void addSupplier(SupplierDraft supplier) {
    if (supplier.id.trim().isEmpty || supplier.name.trim().isEmpty) {
      throw ArgumentError('Nhà cung cấp cần mã và tên.');
    }
    if (suppliers.containsKey(supplier.id)) {
      throw StateError('Mã nhà cung cấp đã tồn tại.');
    }
    suppliers[supplier.id] = supplier;
  }

  void createOrder(PurchaseDraft order) {
    if (!suppliers.containsKey(order.supplierId)) {
      throw StateError('Không tìm thấy nhà cung cấp.');
    }
    if (orders.containsKey(order.id)) {
      throw StateError('Mã đơn mua đã tồn tại.');
    }
    if (order.lines.isEmpty || order.lines.any((line) =>
        line.productId.isEmpty || line.quantity <= 0 || line.costPerUnit < 0)) {
      throw ArgumentError('Đơn mua thiếu sản phẩm, số lượng hoặc giá nhập.');
    }
    orders[order.id] = order;
  }
}

class SupplierDraft {
  final String id;
  final String name;
  final String phone;
  final String note;
  const SupplierDraft({required this.id, required this.name,
      this.phone = '', this.note = ''});
}

class PurchaseDraftLine {
  final String productId;
  /// Quantity stored as 1/10,000 of the selected unit, same as stock model.
  final int quantity;
  final int costPerUnit;
  const PurchaseDraftLine({required this.productId, required this.quantity,
      required this.costPerUnit});
  int get amount => ((quantity * costPerUnit) + 5000) ~/ 10000;
}

class PurchaseDraft {
  final String id;
  final String supplierId;
  final List<PurchaseDraftLine> lines;
  const PurchaseDraft({required this.id, required this.supplierId,
      required this.lines});
  int get total => lines.fold<int>(0, (sum, line) => sum + line.amount);
}
