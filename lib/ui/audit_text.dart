part of 'app.dart';

// Presentation only: old immutable logs remain intact in Firestore and backups.
({String title, String detail, String person}) auditPresentation(
  ShopData data,
  Json row, {
  Actor? actor,
}) {
  final action = '${row['action'] ?? 'Cập nhật dữ liệu'}';
  final target = '${row['target'] ?? ''}';
  final raw = '${row['detail'] ?? ''}';
  final savedName = '${row['actorName'] ?? ''}'.trim();
  final person = savedName.isNotEmpty
      ? savedName
      : actor != null && row['actor'] == actor.id
      ? actor.displayName ??
            (actor.canAdmin ? 'Chủ cửa hàng' : 'Nhân viên bán hàng')
      : row['actor'] == 'admin'
      ? 'Chủ cửa hàng'
      : _internalId('${row['actor']}')
      ? 'Tài khoản cửa hàng (nhật ký cũ chưa lưu tên)'
      : '${row['actor'] ?? 'Tài khoản cửa hàng'}';
  final p = data.products
      .where((p) => p.id == target || p.code == target)
      .firstOrNull;
  final customer = data.customers.where((c) => c['id'] == target).firstOrNull;
  final salary = data.payroll.where((p) => p['id'] == target).firstOrNull;
  final trip = data.deliveries.where((d) => d['id'] == target).firstOrNull;
  String subject = p != null
      ? '${p.name} (${p.code})'
      : customer != null
      ? '${customer['name']}'
      : salary != null
      ? '${salary['name']} • ${salary['period']}'
      : trip != null
      ? '${trip['orderId']} • Tài xế ${trip['driver']}'
      : _internalId(target)
      ? ''
      : target;
  var title = subject.isEmpty ? action : '$action • $subject';
  var detail = raw;

  if (action == 'Giao dịch đồng bộ') {
    title = 'Đã lưu và đồng bộ dữ liệu';
    const labels = {
      'products': 'sản phẩm',
      'orders': 'đơn hàng',
      'customers': 'khách hàng',
      'deliveries': 'chuyến giao hàng',
      'payroll': 'kỳ lương',
      'stockMoves': 'phiếu kho',
      'notifications': 'thông báo',
    };
    final counts = <String, int>{};
    for (final entry in raw.split(', ')) {
      final collection = entry.split('/').first;
      if (labels.containsKey(collection)) {
        counts.update(collection, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    detail = counts.isEmpty
        ? 'Đã lưu thay đổi để đồng bộ giữa các thiết bị.'
        : 'Đã lưu ${counts.entries.map((e) => '${e.value} ${labels[e.key]}').join(', ')}. Chi tiết thao tác được ghi trong nhật ký tương ứng.';
  } else if (action == 'Sửa sản phẩm' || action == 'Tạo sản phẩm') {
    final split = raw.indexOf(' → ');
    final before = split < 0 ? null : _auditMap(raw.substring(0, split));
    final after = split < 0 ? null : _auditMap(raw.substring(split + 3));
    if (after != null) {
      title = '$action • ${after['name']} (${after['code']})';
      final changes = <String>[];
      const labels = {
        'name': 'Tên sản phẩm',
        'code': 'Mã sản phẩm',
        'size': 'Kích thước / đơn vị',
        'supplier': 'Nhà cung cấp',
        'price': 'Giá bán',
        'ratio': 'Quy đổi thùng',
        'minimum': 'Ngưỡng sắp hết',
        'note': 'Lưu ý',
        'active': 'Kinh doanh',
      };
      for (final field in labels.keys) {
        if (jsonEncode(before?[field]) == jsonEncode(after[field])) continue;
        if (before == null && !after.containsKey(field)) continue;
        final next = _auditValue(field, after[field]);
        changes.add(
          before == null
              ? '${labels[field]}: $next'
              : '${labels[field]}: ${_auditValue(field, before[field])} → $next',
        );
      }
      if (before != null &&
          jsonEncode(before['lots']) != jsonEncode(after['lots'])) {
        changes.add('Đã cập nhật thông tin lô hàng trong kho.');
      }
      detail = changes.isEmpty
          ? 'Đã lưu thông tin hoặc hình ảnh sản phẩm.'
          : changes.join('\n');
    } else {
      detail = 'Đã lưu thông tin sản phẩm.';
    }
  } else if (action == 'Sửa lương') {
    final match = RegExp(r'^(\d+) / (\d+) → (\d+) / (\d+)$').firstMatch(raw);
    if (match != null) {
      detail =
          'Lương: ${money(int.parse(match[1]!))} → ${money(int.parse(match[3]!))}\nĐã ứng / trả: ${money(int.parse(match[2]!))} → ${money(int.parse(match[4]!))}';
    }
  }
  // Never dump serialized records, collection paths or UUIDs into the activity feed.
  if (_auditMap(detail) != null || detail.trimLeft().startsWith('{')) {
    detail = 'Đã cập nhật thông tin. Dữ liệu gốc được giữ trong bản sao lưu nhật ký.';
  }
  detail = detail.replaceAll(
    RegExp(
      r'[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}',
    ),
    'mã nội bộ',
  );
  return (title: title, detail: detail, person: person);
}

bool _internalId(String value) =>
    RegExp(r'^[a-fA-F0-9]{8}-|^GH-[a-fA-F0-9]{8}$|^[A-Za-z0-9_-]{24,}$')
        .hasMatch(value);

Json? _auditMap(String value) {
  try {
    final decoded = jsonDecode(value);
    return decoded is Map ? Json.from(decoded) : null;
  } catch (_) {
    return null;
  }
}

String _auditValue(String field, dynamic value) {
  if (value == null || value == '') return 'Chưa nhập';
  if (field == 'price' && value is num) return money(value);
  if (field == 'ratio' && value is num) {
    return value == 0 ? 'Chưa nhập' : '1 thùng = ${area(value)} m²';
  }
  if (field == 'minimum' && value is num) return '${area(value)} đơn vị bán';
  if (field == 'active') return value == true ? 'Đang bán' : 'Ngừng bán';
  return '$value';
}
