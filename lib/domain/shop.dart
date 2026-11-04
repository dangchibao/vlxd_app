import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;

// Areas use 1/10,000 m² and money uses whole VND, never binary floats.
int areaUnits(num squareMetres) => (squareMetres * 10000).round();
int lineMoney(int area, int price) =>
    (area ~/ 10000) * price + ((area % 10000) * price + 5000) ~/ 10000;

enum Role { owner, sales, driver, other }

class Actor {
  final String id;
  final Role role;
  final String? displayName;
  const Actor(this.id, this.role, {this.displayName});
  bool get canAccess => role == Role.owner || role == Role.sales;
  bool get canAdmin => role == Role.owner;
  void requireAccess() {
    if (!canAccess) {
      throw StateError('Vị trí này chưa được cấp quyền truy cập.');
    }
  }

  void requireAdmin() {
    if (!canAdmin) {
      throw StateError('Chỉ chủ được quản lý tài khoản và cấp quyền.');
    }
  }
}

class Product {
  String id, code, name, size, supplier, note;
  int price, ratio, minimum;
  bool active;
  List<String> images;
  List<Json> lots;
  Product({
    required this.id,
    required this.code,
    required this.name,
    required this.size,
    required this.supplier,
    required this.price,
    required this.ratio,
    this.minimum = 144000,
    this.active = true,
    this.note = '',
    List<String>? images,
    List<Json>? lots,
  }) : images = images ?? [],
       lots = lots ?? [];
  // Existing size field also identifies bulk material units, preserving the
  // deployed document schema. All legacy tile sizes remain square metres.
  bool get isBulk => size.trim() == 'm³';
  String get unit => isBulk ? 'm³' : 'm²';
  bool get hasPackConversion => !isBulk && ratio > 0;
  int get quantityStep => hasPackConversion ? ratio : 10000;
  String get packUnit => hasPackConversion ? 'thùng' : unit;
  int get stock => lots.fold(0, (v, l) => v + (l['area'] as int));
  int get reserved => lots.fold(0, (v, l) => v + (l['reserved'] as int? ?? 0));
  int get available => stock - reserved;
  bool isOld(DateTime now) => lots.any(
    (l) =>
        (l['area'] as int) > 0 &&
        now.difference(DateTime.parse(l['date'])).inDays > 60,
  );
  Json toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'size': size,
    'supplier': supplier,
    if (note.isNotEmpty) 'note': note,
    'price': price,
    'ratio': ratio,
    'minimum': minimum,
    'active': active,
    'images': images,
    'lots': lots,
  };
  factory Product.fromJson(Json j) => Product(
    id: j['id'],
    code: j['code'],
    name: j['name'],
    size: j['size'],
    supplier: j['supplier'],
    note: j['note'] as String? ?? '',
    price: j['price'],
    ratio: j['ratio'],
    minimum: j['minimum'],
    active: j['active'],
    images: List<String>.from(j['images']),
    lots: (j['lots'] as List).map((x) => Json.from(x)).toList(),
  );
}

class CartLine {
  final String productId;
  final int area;
  final String note;
  const CartLine(this.productId, this.area, {this.note = ''});
}

String mergeLineNotes(Iterable<String> notes) =>
    notes.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().join('\n');

class RoomEstimate {
  final int requiredArea, cartons, purchasedArea;
  const RoomEstimate(this.requiredArea, this.cartons, this.purchasedArea);
  static RoomEstimate calculate(
    double length,
    double width,
    double waste,
    int ratio,
  ) {
    if (![length, width, waste].every((v) => v.isFinite) ||
        length <= 0 ||
        width <= 0 ||
        waste < 0 ||
        waste > 100 ||
        ratio <= 0) {
      throw ArgumentError('Nhập kích thước dương, hao hụt từ 0 đến 100%.');
    }
    final required = (length * width * (1 + waste / 100) * 10000).ceil();
    final cartons = (required + ratio - 1) ~/ ratio;
    return RoomEstimate(required, cartons, cartons * ratio);
  }
}

class ShopData {
  factory ShopData.empty() => ShopData(
    products: [],
    orders: [],
    customers: [],
    deliveries: [],
    payroll: [],
    audit: [],
    notifications: [],
    stockMoves: [],
  );
  List<Product> products;
  List<Json> orders,
      customers,
      deliveries,
      payroll,
      audit,
      notifications,
      stockMoves;
  ShopData({
    required this.products,
    required this.orders,
    required this.customers,
    required this.deliveries,
    required this.payroll,
    required this.audit,
    required this.notifications,
    required this.stockMoves,
  });
  Json toJson() => {
    'schema': 1,
    'products': products.map((p) => p.toJson()).toList(),
    'orders': orders,
    'customers': customers,
    'deliveries': deliveries,
    'payroll': payroll,
    'audit': audit,
    'notifications': notifications,
    'stockMoves': stockMoves,
  };
  factory ShopData.fromJson(Json j) {
    if (j['schema'] != 1) {
      throw StateError('Phiên bản dữ liệu không được hỗ trợ.');
    }
    List<Json> rows(String key) =>
        (j[key] as List).map((x) => Json.from(x)).toList();
    return ShopData(
      products: (j['products'] as List)
          .map((p) => Product.fromJson(Json.from(p)))
          .toList(),
      orders: rows('orders'),
      customers: rows('customers'),
      deliveries: rows('deliveries'),
      payroll: rows('payroll'),
      audit: rows('audit'),
      notifications: rows('notifications'),
      stockMoves: rows('stockMoves'),
    );
  }
  ShopData copy() => ShopData.fromJson(jsonDecode(jsonEncode(toJson())));
  Product product(String id) => products.firstWhere((p) => p.id == id);
  void log(Actor actor, String action, String target, String detail) {
    audit.insert(0, {
      'id': const Uuid().v4(),
      'actor': actor.id,
      if (actor.displayName?.trim().isNotEmpty == true)
        'actorName': actor.displayName!.trim(),
      'action': action,
      'target': target,
      'detail': detail,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void saveProduct(Product p, Actor actor, {Product? expected}) {
    actor.requireAccess();
    if (expected != null &&
        expected.unit != p.unit &&
        (expected.stock != 0 ||
            expected.reserved != 0 ||
            orders.any(
              (o) => (o['lines'] as List).any((l) => l['productId'] == p.id),
            ))) {
      throw StateError(
        'Sản phẩm đã có tồn hoặc lịch sử bán. Tạo mã khác khi đổi giữa m² và m³.',
      );
    }
    if (expected != null &&
        jsonEncode(product(p.id).toJson()) != jsonEncode(expected.toJson())) {
      throw StateError(
        'Sản phẩm hoặc tồn kho vừa được máy khác cập nhật. Đóng và mở lại thông tin trước khi sửa.',
      );
    }
    if (p.name.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(p.code) ||
        p.price <= 0 ||
        p.price > 1000000000 ||
        p.ratio < 0 ||
        p.ratio > 100000000 ||
        p.minimum < 0 ||
        p.note.length > 1000 ||
        p.images.length > 11) {
      throw ArgumentError(
        'Kiểm tra tên, mã không dấu, giá, quy đổi và tối đa 11 ảnh.',
      );
    }
    if (products.any(
      (x) => x.id != p.id && x.code.toLowerCase() == p.code.toLowerCase(),
    )) {
      throw StateError('Mã sản phẩm đã tồn tại.');
    }
    final index = products.indexWhere((x) => x.id == p.id);
    final before = index < 0
        ? 'Mới'
        : jsonEncode(products[index].toJson()..remove('images'));
    if (index < 0) {
      products.add(p);
    } else {
      products[index] = p;
    }
    log(
      actor,
      index < 0 ? 'Tạo sản phẩm' : 'Sửa sản phẩm',
      p.code,
      '$before → ${jsonEncode(p.toJson()..remove('images'))}',
    );
  }

  void archiveProduct(String id, Actor actor) {
    actor.requireAccess();
    final p = product(id);
    if (p.reserved != 0) throw StateError('Sản phẩm đang giữ cho đơn hàng.');
    p.active = false;
    log(
      actor,
      'Ngừng kinh doanh',
      p.code,
      'Giữ lịch sử và tồn kho, ẩn khỏi bán hàng.',
    );
  }

  void receive(
    String id,
    int area,
    int cost,
    DateTime date,
    Actor actor,
    String lotId,
  ) {
    actor.requireAccess();
    if (area <= 0 ||
        area > 10000000000 ||
        cost < 0 ||
        cost > 1000000000 ||
        date.isAfter(DateTime.now())) {
      throw ArgumentError(
        'Số lượng phải dương, giá vốn không âm, ngày nhập không ở tương lai.',
      );
    }
    final p = product(id);
    p.lots.add({
      'id': lotId,
      'date': date.toIso8601String(),
      'area': area,
      'reserved': 0,
      'cost': cost,
      'ratio': p.ratio,
    });
    stockMoves.insert(0, {
      'product': p.code,
      'area': area,
      'type': 'Nhập kho',
      'lot': lotId,
      'actor': actor.id,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    log(
      actor,
      'Nhập kho',
      p.code,
      'Lô $lotId: ${area / 10000} ${p.unit}, giá vốn $cost đ/${p.unit}',
    );
  }

  Json checkout({
    required String requestId,
    required List<CartLine> lines,
    required String customerId,
    required int paid,
    required int ship,
    required bool hold,
    required Actor actor,
    String negativeReason = '',
  }) {
    actor.requireAccess();
    final existing = orders.where((o) => o['requestId'] == requestId);
    if (existing.isNotEmpty) return existing.first;
    if (requestId.isEmpty || lines.isEmpty || paid < 0 || ship < 0) {
      throw ArgumentError('Đơn hàng hoặc số tiền không hợp lệ.');
    }
    final quantities = <String, int>{};
    final notes = <String, String>{};
    for (final line in lines) {
      notes[line.productId] = mergeLineNotes([
        notes[line.productId] ?? '',
        line.note,
      ]);
      if (notes[line.productId]!.length > 1000) {
        throw ArgumentError(
          'Lưu ý sản phẩm tối đa 1.000 ký tự; rút gọn trước khi chốt đơn.',
        );
      }
      if (line.area <= 0 || line.area > 10000000000) {
        throw ArgumentError(
          'Số lượng không hợp lệ hoặc vượt giới hạn một phiếu.',
        );
      }
      quantities.update(
        line.productId,
        (v) => v + line.area,
        ifAbsent: () => line.area,
      );
    }
    int subtotal = 0;
    for (final entry in quantities.entries) {
      final p = product(entry.key);
      if (!p.active) throw StateError('Sản phẩm đã ngừng kinh doanh.');
      if (entry.value > p.available &&
          (hold || negativeReason.trim().isEmpty)) {
        throw StateError(
          '${p.name} vượt tồn. Bán âm cần xác nhận và lý do; giữ hàng phải đủ tồn.',
        );
      }
      subtotal += lineMoney(entry.value, p.price);
    }
    final total = subtotal + ship;
    if (total > 9000000000000) {
      throw ArgumentError('Giá trị đơn vượt giới hạn một phiếu.');
    }
    if (paid > total) throw ArgumentError('Tiền thu vượt tổng đơn.');
    if (customerId.isEmpty && (paid < total || hold)) {
      throw StateError('Chọn khách để ghi công nợ hoặc giữ đơn.');
    }
    if (customerId.isNotEmpty && !customers.any((c) => c['id'] == customerId)) {
      throw StateError('Không tìm thấy khách hàng.');
    }
    if (customers.any((c) => c['id'] == customerId && c['active'] == false)) {
      throw StateError('Khách hàng đã ngừng sử dụng.');
    }
    _checkBookChange(customerId, total, paid);
    final snapshots = <Json>[];
    for (final entry in quantities.entries) {
      final p = product(entry.key);
      int remaining = entry.value;
      final allocations = <Json>[];
      final sorted = [...p.lots]
        ..sort((a, b) => (a['date'] as String).compareTo(b['date']));
      for (final lot in sorted) {
        final available = (lot['area'] as int) - (lot['reserved'] as int);
        final take = min(remaining, max(0, available));
        if (take == 0) continue;
        if (hold) {
          lot['reserved'] += take;
        } else {
          lot['area'] -= take;
        }
        allocations.add({'lot': lot['id'], 'area': take, 'cost': lot['cost']});
        remaining -= take;
        if (remaining == 0) break;
      }
      if (remaining > 0) {
        p.lots.add({
          'id': 'AM-$requestId',
          'date': DateTime.now().toIso8601String(),
          'area': -remaining,
          'reserved': 0,
          'cost': 0,
          'ratio': p.ratio,
        });
        allocations.add({
          'lot': 'AM-$requestId',
          'area': remaining,
          'cost': null,
        });
      }
      snapshots.add({
        'productId': p.id,
        'code': p.code,
        'name': p.name,
        if (notes[entry.key]!.isNotEmpty) 'note': notes[entry.key],
        'unit': p.unit,
        'price': p.price,
        'ratio': p.ratio,
        'area': entry.value,
        'amount': lineMoney(entry.value, p.price),
        'allocations': allocations,
      });
    }
    final at = DateTime.now().toUtc().toIso8601String();
    var sequence = orders.length + 1;
    while (orders.any((o) => o['id'] == 'DH-$sequence')) {
      sequence++;
    }
    final order = <String, dynamic>{
      'id': 'DH-$sequence',
      'requestId': requestId,
      'customerId': customerId,
      'lines': snapshots,
      'subtotal': subtotal,
      'ship': ship,
      'total': total,
      'status': hold ? 'Giữ hàng' : 'Đã bán',
      'payments': paid == 0
          ? <Json>[]
          : <Json>[
              {
                'id': '$requestId-first',
                'amount': paid,
                'at': at,
                'actor': actor.id,
              },
            ],
      'at': at,
      'actor': actor.id,
      'negativeReason': negativeReason,
    };
    orders.insert(0, order);
    for (final line in snapshots) {
      stockMoves.insert(0, {
        'product': line['code'],
        'area': -line['area'],
        'type': hold ? 'Giữ hàng' : 'Bán hàng',
        'lot': requestId,
        'actor': actor.id,
        'at': at,
      });
    }
    log(
      actor,
      hold ? 'Giữ đơn' : 'Chốt đơn',
      order['id'],
      'Tổng $total đ; thu $paid đ. $negativeReason',
    );
    notifications.insert(0, {
      'id': requestId,
      'event': 'Đơn mới ${order['id']}',
      'at': at,
      'status': 'Chưa gửi • chưa kết nối Messenger',
    });
    return order;
  }

  static int collected(Json order) => (order['payments'] as List)
      .where((p) => p['voided'] != true)
      .fold<int>(0, (v, p) => v + (p['amount'] as int));
  static int netCollected(Json order) =>
      collected(order) - ((order['refund'] as int?) ?? 0);
  void cancelHeld(String id, String reason, Actor actor) {
    actor.requireAccess();
    final o = orders.firstWhere((o) => o['id'] == id);
    if (o['status'] == 'Đã hủy') return;
    if (o['status'] != 'Giữ hàng' || reason.trim().isEmpty) {
      throw StateError('Chỉ hủy đơn giữ và phải ghi lý do.');
    }
    _checkBookChange(o['customerId'], -(o['total'] as int), -collected(o));
    for (final line in o['lines']) {
      for (final allocation in line['allocations']) {
        final lot = product(line['productId']).lots
            .firstWhere((l) => l['id'] == allocation['lot']);
        if ((lot['reserved'] as int) < (allocation['area'] as int)) {
          throw StateError('Lượng giữ không khớp, cần kiểm tra trước khi hủy.');
        }
      }
    }
    for (final line in o['lines']) {
      final p = product(line['productId']);
      for (final allocation in line['allocations']) {
        p.lots.firstWhere((l) => l['id'] == allocation['lot'])['reserved'] -=
            allocation['area'];
      }
      stockMoves.insert(0, {
        'id': const Uuid().v4(),
        'product': p.code,
        'area': line['area'],
        'type': 'Hủy giữ',
        'lot': id,
        'actor': actor.id,
        'at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    o['status'] = 'Đã hủy';
    o['refund'] = collected(o);
    o['cancelReason'] = reason.trim();
    o['cancelledBy'] = actor.id;
    o['cancelledAt'] = DateTime.now().toUtc().toIso8601String();
    log(
      actor,
      'Hủy giữ và hoàn cọc',
      id,
      'Đã ghi hoàn ${o['refund']} đ. ${reason.trim()}',
    );
  }

  void correctPayment(
    String orderId,
    String paymentId,
    int replacementAmount,
    String reason,
    String correctionId,
    Actor actor,
  ) {
    actor.requireAccess();
    final o = orders.firstWhere((o) => o['id'] == orderId);
    if (o['status'] == 'Đã hủy') {
      throw StateError('Không sửa thu tiền của đơn đã hủy.');
    }
    final payments = o['payments'] as List;
    if (payments.any(
      (p) => p['id'] == correctionId || p['correctionId'] == correctionId,
    )) {
      return;
    }
    final old = payments.firstWhere((p) => p['id'] == paymentId);
    if (old['voided'] == true ||
        replacementAmount < 0 ||
        reason.trim().isEmpty) {
      throw ArgumentError('Lần thu đã hủy hoặc thiếu số tiền / lý do hợp lệ.');
    }
    final available =
        (o['total'] as int) - collected(o) + (old['amount'] as int);
    if (replacementAmount > available) {
      throw ArgumentError('Sửa tiền thu làm vượt tổng đơn.');
    }
    _checkBookChange(
      o['customerId'],
      0,
      replacementAmount - (old['amount'] as int),
    );
    old['voided'] = true;
    old['correctionId'] = correctionId;
    old['voidReason'] = reason.trim();
    old['voidedBy'] = actor.id;
    if (replacementAmount > 0) {
      payments.add({
        'id': correctionId,
        'amount': replacementAmount,
        'actor': actor.id,
        'at': DateTime.now().toUtc().toIso8601String(),
        'replaces': paymentId,
      });
    }
    final customer = customers
        .where((c) => c['id'] == o['customerId'])
        .firstOrNull;
    if (customer?['active'] == false && debt(o['customerId']) > 0) {
      customer!['active'] = true;
      log(
        actor,
        'Hiện lại khách có công nợ',
        customer['id'],
        'Điều chỉnh lần thu làm phát sinh công nợ; hiển thị lại để theo dõi.',
      );
    }
    log(
      actor,
      'Điều chỉnh lần thu',
      orderId,
      '${old['amount']} đ → $replacementAmount đ. ${reason.trim()}',
    );
  }

  void fulfilHeld(String id, Actor actor) {
    actor.requireAccess();
    final o = orders.firstWhere((o) => o['id'] == id);
    if (o['status'] == 'Đã bán') return;
    if (o['status'] != 'Giữ hàng') {
      throw StateError('Đơn không ở trạng thái giữ hàng.');
    }
    for (final line in o['lines']) {
      final p = product(line['productId']);
      for (final allocation in line['allocations']) {
        final lot = p.lots.firstWhere((l) => l['id'] == allocation['lot']);
        if ((lot['reserved'] as int) < (allocation['area'] as int) ||
            (lot['area'] as int) < (allocation['area'] as int)) {
          throw StateError(
            'Lô giữ hàng không đủ tồn, cần đối chiếu trước khi xuất.',
          );
        }
      }
    }
    for (final line in o['lines']) {
      final p = product(line['productId']);
      for (final allocation in line['allocations']) {
        final lot = p.lots.firstWhere((l) => l['id'] == allocation['lot']);
        lot['reserved'] -= allocation['area'];
        lot['area'] -= allocation['area'];
      }
      stockMoves.insert(0, {
        'product': p.code,
        'area': -line['area'],
        'type': 'Xuất đơn giữ',
        'lot': id,
        'actor': actor.id,
        'at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    o['status'] = 'Đã bán';
    o['soldAt'] = DateTime.now().toUtc().toIso8601String();
    log(
      actor,
      'Xuất đơn giữ',
      id,
      'Tiền cọc giữ nguyên trong lịch sử thu, không thu lại.',
    );
  }

  ({int receivable, int received}) customerBook(String customerId) {
    final customer = customers.where((c) => c['id'] == customerId).firstOrNull;
    final sold = orders.where(
      (o) => o['customerId'] == customerId && o['status'] != 'Đã hủy',
    );
    return (
      receivable:
          sold.fold<int>(0, (s, o) => s + (o['total'] as int)) +
          (customer?['receivableAdjustment'] as int? ?? 0),
      received:
          sold.fold<int>(0, (s, o) => s + collected(o)) +
          (customer?['receivedAdjustment'] as int? ?? 0),
    );
  }

  int debt(String customerId) {
    final book = customerBook(customerId);
    return book.receivable - book.received;
  }

  void _checkBookChange(String customerId, int totalDelta, int paidDelta) {
    if (customerId.isEmpty) return;
    final before = customerBook(customerId);
    final total = before.receivable + totalDelta,
        paid = before.received + paidDelta;
    if (total < 0 || paid < 0 || paid > total) {
      throw StateError(
        'Sổ công nợ có điều chỉnh không còn khớp thao tác này. Nhờ admin đối chiếu Phải thu/Đã thu trước.',
      );
    }
  }

  void adjustCustomerBook(
    String customerId,
    int receivable,
    int received,
    String reason,
    Actor actor, {
    required int expectedReceivable,
    required int expectedReceived,
  }) {
    actor.requireAccess();
    if (receivable < 0 ||
        received < 0 ||
        received > receivable ||
        receivable > 9000000000000 ||
        reason.trim().isEmpty) {
      throw ArgumentError(
        'Phải thu/đã thu phải là số không âm, đã thu không vượt phải thu và cần lý do.',
      );
    }
    final customer = customers.firstWhere((c) => c['id'] == customerId);
    if (customer['active'] == false) {
      throw StateError('Khách đã ngừng sử dụng.');
    }
    final before = customerBook(customerId);
    if (before.receivable != expectedReceivable ||
        before.received != expectedReceived) {
      throw StateError('Sổ công nợ vừa thay đổi. Mở lại trước khi sửa.');
    }
    customer['receivableAdjustment'] =
        (customer['receivableAdjustment'] as int? ?? 0) +
        receivable -
        before.receivable;
    customer['receivedAdjustment'] =
        (customer['receivedAdjustment'] as int? ?? 0) +
        received -
        before.received;
    customer['ledgerVersion'] = (customer['ledgerVersion'] as int? ?? 0) + 1;
    log(
      actor,
      'Điều chỉnh sổ công nợ',
      customerId,
      'Phải thu ${before.receivable} → $receivable đ; đã thu ${before.received} → $received đ. ${reason.trim()}',
    );
  }

  void archiveCustomer(String customerId, Actor actor) {
    actor.requireAccess();
    final customer = customers.firstWhere((c) => c['id'] == customerId);
    if (customer['active'] == false) return;
    if (debt(customerId) != 0 ||
        orders.any(
          (o) => o['customerId'] == customerId && o['status'] == 'Giữ hàng',
        )) {
      throw StateError(
        'Khách còn số dư công nợ hoặc đơn giữ hàng. Xử lý trước khi xóa khỏi danh sách.',
      );
    }
    customer['active'] = false;
    log(
      actor,
      'Ẩn khách hàng',
      customerId,
      'Ẩn ${customer['name']}; giữ hóa đơn và lịch sử.',
    );
  }

  void recordPayment(
    String orderId,
    int amount,
    String paymentId,
    Actor actor,
  ) {
    actor.requireAccess();
    final o = orders.firstWhere((o) => o['id'] == orderId);
    if (o['status'] == 'Đã hủy') {
      throw StateError('Không thu thêm tiền cho đơn đã hủy.');
    }
    final payments = o['payments'] as List;
    if (payments.any((p) => p['id'] == paymentId)) return;
    if (amount <= 0 || amount > (o['total'] as int) - collected(o)) {
      throw ArgumentError('Tiền thu phải dương và không vượt số còn nợ.');
    }
    _checkBookChange(o['customerId'], 0, amount);
    payments.add({
      'id': paymentId,
      'amount': amount,
      'actor': actor.id,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    log(actor, 'Thu nợ', orderId, '$amount đ');
  }

  void finishDelivery(String id, Actor actor) {
    actor.requireAccess(); // Latest requirement grants sales staff this right too.
    final d = deliveries.firstWhere((d) => d['id'] == id);
    if (d['status'] == 'Đã xong') return;
    d['status'] = 'Đã xong';
    d['finishedBy'] = actor.id;
    d['finishedAt'] = DateTime.now().toUtc().toIso8601String();
    log(actor, 'Hoàn tất chuyến', id, 'Xác nhận đã giao xong');
    notifications.insert(0, {
      'id': 'delivery-$id',
      'event': 'Chuyến $id đã xong',
      'at': d['finishedAt'],
      'status': 'Chưa gửi • chưa kết nối Messenger',
    });
  }

  void setSalary(String id, int salary, int advance, Actor actor) {
    actor.requireAccess();
    if (salary < 0 || advance < 0 || advance > salary) {
      throw ArgumentError('Lương hoặc tiền ứng không hợp lệ.');
    }
    final p = payroll.firstWhere((p) => p['id'] == id);
    log(
      actor,
      'Sửa lương',
      id,
      '${p['salary']} / ${p['advance']} → $salary / $advance',
    );
    p['salary'] = salary;
    p['advance'] = advance;
  }

  factory ShopData.sample() {
    final now = DateTime.now();
    final specs = [
      [
        'PR6060VD',
        'Prime vân đá trắng',
        '60×60',
        'Prime',
        240000,
        14400,
        100,
        65,
      ],
      [
        'DT8080XM',
        'Đồng Tâm xám mờ',
        '80×80',
        'Đồng Tâm',
        320000,
        12800,
        50,
        25,
      ],
      [
        'VG6060BE',
        'Viglacera kem bóng',
        '60×60',
        'Viglacera',
        260000,
        14400,
        8,
        70,
      ],
      [
        'PR3060CT',
        'Prime chống trơn',
        '30×60',
        'Prime',
        180000,
        14400,
        120,
        20,
      ],
      [
        'DT6060VM',
        'Đồng Tâm vân mây',
        '60×60',
        'Đồng Tâm',
        245000,
        14400,
        68,
        40,
      ],
      [
        'VG8080DX',
        'Viglacera đá xám',
        '80×80',
        'Viglacera',
        335000,
        12800,
        4,
        12,
      ],
    ];
    return ShopData(
      products: specs
          .map(
            (s) => Product(
              id: s[0] as String,
              code: s[0] as String,
              name: s[1] as String,
              size: s[2] as String,
              supplier: s[3] as String,
              price: s[4] as int,
              ratio: s[5] as int,
              minimum: (s[5] as int) * 10,
              lots: [
                {
                  'id': 'LO-${s[0]}',
                  'date': now
                      .subtract(Duration(days: s[7] as int))
                      .toIso8601String(),
                  'area': (s[5] as int) * (s[6] as int),
                  'reserved': 0,
                  'cost': ((s[4] as int) * .7).round(),
                  'ratio': s[5],
                },
              ],
            ),
          )
          .toList(),
      orders: [],
      customers: [
        {
          'id': 'KH001',
          'name': 'Anh Minh • Công trình Gò Dầu',
          'phone': '0900000001',
        },
        {'id': 'KH002', 'name': 'Chị Lan', 'phone': '0900000002'},
      ],
      deliveries: [],
      payroll: [
        {
          'id': 'NV001',
          'name': 'Anh Hùng',
          'period': '${now.month}/${now.year}',
          'salary': 8000000,
          'advance': 2000000,
        },
      ],
      audit: [],
      notifications: [],
      stockMoves: [],
    );
  }
}
