import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/shop_controller.dart';
import '../data/local/app_database.dart';
import '../data/sync/offline_checkout_command.dart';
import '../data/sync/outbox_repository.dart';

/// Màn hình CHỈ ĐỌC các giao dịch đã lưu trên thiết bị.
/// Không gọi SyncRuntime, SyncEngine, retryFailed hay xóa bản ghi.
class OfflineOrdersPage extends StatefulWidget {
  const OfflineOrdersPage({super.key});

  @override
  State<OfflineOrdersPage> createState() => _OfflineOrdersPageState();
}

class _OfflineOrdersPageState extends State<OfflineOrdersPage> {
  late Stream<List<PendingOperation>> _operations;
  String _searchText = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _operations = _watchOperations();
  }

  Stream<List<PendingOperation>> _watchOperations() {
    if (!Get.isRegistered<OutboxRepository>()) {
      throw StateError('Outbox chưa được khởi tạo trên thiết bị này.');
    }
    if (!Get.isRegistered<ShopController>()) {
      throw StateError('Phiên bán hàng chưa sẵn sàng.');
    }
    final actor = Get.find<ShopController>().actor;
    if (actor == null) {
      throw StateError('Vui lòng đăng nhập để xem đơn offline.');
    }

    final outbox = Get.find<OutboxRepository>();
    return outbox.db.select(outbox.db.pendingOperations).watch().map((all) {
      final visible = <PendingOperation>[];
      for (final operation in all) {
        if (operation.operationType != 'checkout.v1') continue;
        try {
          final command = OfflineCheckoutCommand.decode(operation.payloadJson);
          if (command.requestId == operation.id &&
              command.actorId == actor.id) {
            visible.add(operation);
          }
        } catch (_) {
          // Dữ liệu không đọc được phải được kiểm tra bởi người quản trị;
          // không hiển thị nội dung lỗi có thể thuộc về tài khoản khác.
        }
      }
      visible.sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
      return visible;
    });
  }

  // Tên chỉ được tra từ dữ liệu hiện có trên máy, không gọi Firebase.
  // Các đơn cũ chưa lưu snapshot tên nên tên hiện tại có thể khác lúc bán.
  String _customerName(String id) {
    final customers = Get.find<ShopController>().data.customers;
    for (final customer in customers) {
      if (customer['id'] == id) {
        final name = (customer['name'] as String? ?? '').trim();
        if (name.isNotEmpty) return name;
      }
    }
    return 'Chưa có tên khách hàng';
  }

  String _staffName(String id) {
    final actor = Get.find<ShopController>().actor;
    if (actor != null && actor.id == id) {
      final name = actor.displayName?.trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return 'Chưa có tên nhân viên đã lưu';
  }

  String _productName(String id) {
    final products = Get.find<ShopController>().data.products;
    for (final product in products) {
      if (product.id == id) {
        return '${product.name} ${product.size}'.trim();
      }
    }
    return 'Sản phẩm không còn trong danh mục';
  }

  // Chỉ là mã tham chiếu dễ nhìn, KHÔNG thay thế requestId duy nhất.
  String _shortReference(String id) {
    final fragment = id.replaceAll('-', '').toUpperCase();
    return 'OFF-${fragment.length > 8 ? fragment.substring(0, 8) : fragment}';
  }

  String _money(num amount) =>
      '${NumberFormat.decimalPattern('vi_VN').format(amount)} đ';

  String _statusText(String status) => switch (status) {
    'pending' => 'Chờ đồng bộ',
    'syncing' => 'Đang xử lý',
    'failed' => 'Cần xác minh',
    'synced' => 'Server đã xác nhận',
    _ => 'Trạng thái: $status',
  };

  Color _statusColor(String status) => switch (status) {
    'pending' => const Color(0xFFAA6900),
    'syncing' => const Color(0xFF086EEB),
    'failed' => const Color(0xFFB3261E),
    'synced' => const Color(0xFF168366),
    _ => Colors.grey,
  };

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  void _showDetails(PendingOperation operation) {
    final command = OfflineCheckoutCommand.decode(operation.payloadJson);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chi tiết đơn offline'),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mã tham chiếu: ${_shortReference(operation.id)}'),
                SelectableText('Request ID (kỹ thuật): ${operation.id}'),
                const SizedBox(height: 8),
                Text('Trạng thái: ${_statusText(operation.status)}'),
                Text('Lưu lúc: ${_date(operation.createdAt)}'),
                Text('Khách hàng: ${_customerName(command.customerId)}'),
                Text('Mã khách hàng: ${command.customerId}'),
                Text('Nhân viên: ${_staffName(command.actorId)}'),
                Text('UID nhân viên: ${command.actorId}'),
                Text('Tiền đã thu: ${_money(command.paid)}'),
                Text('Phí giao hàng: ${_money(command.ship)}'),
                Text('Giữ hàng / đặt cọc: ${command.hold ? 'Có' : 'Không'}'),
                if (command.negativeReason.isNotEmpty)
                  Text('Lý do bán âm: ${command.negativeReason}'),
                if (operation.lastError != null &&
                    operation.lastError!.isNotEmpty)
                  Text('Ghi chú đồng bộ: ${operation.lastError}'),
                const Divider(height: 24),
                const Text(
                  'Sản phẩm (giá và quy đổi tại lúc lưu)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final line in command.lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_productName(line.productId)),
                    subtitle: Text(
                      'Mã sản phẩm: ${line.productId}\n'
                      'Số lượng quy đổi: ${line.area}\n'
                      'Đơn giá khi lưu: ${_money(line.quotedPrice)} / đơn vị\n'
                      'Hệ số quy đổi: ${line.quotedRatio}'
                      '${line.note.isEmpty ? '' : '\nGhi chú: ${line.note}'}',
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Đây là lệnh lưu trên thiết bị. Chưa được coi là hóa đơn '
                  'hoàn tất nếu server chưa xác nhận.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Đơn chờ đồng bộ'),
      actions: [
        IconButton(
          tooltip: 'Làm mới danh sách',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(_reload),
        ),
      ],
    ),
    body: StreamBuilder<List<PendingOperation>>(
      stream: _operations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Không thể đọc đơn offline: ${snapshot.error}'),
            ),
          );
        }
        final items = snapshot.data ?? const <PendingOperation>[];
        if (items.isEmpty) {
          return const Center(
            child: Text('Chưa có đơn offline của tài khoản này trên thiết bị.'),
          );
        }
        final pendingCount = items
            .where((item) => item.status == 'pending')
            .length;
        final needsReviewCount = items
            .where((item) => item.status == 'failed')
            .length;
        final syncedCount = items
            .where((item) => item.status == 'synced')
            .length;
        final search = _searchText.trim().toLowerCase();
        final filtered = items.where((operation) {
          if (_statusFilter != 'all' && operation.status != _statusFilter) {
            return false;
          }
          if (search.isEmpty) return true;
          final command = OfflineCheckoutCommand.decode(operation.payloadJson);
          final searchable = <String>[
            operation.id,
            _shortReference(operation.id),
            command.customerId,
            _customerName(command.customerId),
            for (final line in command.lines) ...[
              line.productId,
              _productName(line.productId),
            ],
          ].join(' ').toLowerCase();
          return searchable.contains(search);
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Danh sách tự cập nhật khi trạng thái trên máy thay đổi.',
                    style: TextStyle(color: Color(0xFF526780), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('offline-order-search'),
                    decoration: const InputDecoration(
                      labelText: 'Tìm đơn offline',
                      hintText: 'Mã đơn, tên khách hoặc sản phẩm',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchText = value),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in const <(String, String)>[
                          ('all', 'Tất cả'),
                          ('pending', 'Chờ đồng bộ'),
                          ('syncing', 'Đang xử lý'),
                          ('failed', 'Cần kiểm tra'),
                          ('synced', 'Đã xác nhận'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: ValueKey('offline-filter-${filter.$1}'),
                              label: Text(filter.$2),
                              selected: _statusFilter == filter.$1,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = filter.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text('Chờ: $pendingCount'),
                        backgroundColor: const Color(0xFFFFF2D8),
                      ),
                      Chip(
                        label: Text('Cần kiểm tra: $needsReviewCount'),
                        backgroundColor: const Color(0xFFFFE5E3),
                      ),
                      Chip(
                        label: Text('Đã xác nhận: $syncedCount'),
                        backgroundColor: const Color(0xFFE4F5EC),
                      ),
                    ],
                  ),
                  if (needsReviewCount > 0)
                    const Text(
                      'Đơn cần kiểm tra không tự gửi lại. Hãy đối chiếu Firebase trước khi xử lý.',
                      style: TextStyle(
                        color: Color(0xFFB3261E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Không tìm thấy đơn phù hợp.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final operation = filtered[index];
                        final command = OfflineCheckoutCommand.decode(
                          operation.payloadJson,
                        );
                        return Card(
                          child: ListTile(
                            key: ValueKey('offline-order-${operation.id}'),
                            title: Text(
                              'Mã tham chiếu ${_shortReference(operation.id)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_date(operation.createdAt)} · Khách ${_customerName(command.customerId)}\n'
                              '${command.lines.length} mặt hàng · ${_statusText(operation.status)}',
                            ),
                            isThreeLine: true,
                            trailing: Icon(
                              Icons.circle,
                              size: 15,
                              color: _statusColor(operation.status),
                            ),
                            onTap: () => _showDetails(operation),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}
