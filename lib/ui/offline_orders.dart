import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  late Future<List<PendingOperation>> _operations;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _operations = _readOperations();
  }

  Future<List<PendingOperation>> _readOperations() async {
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
    final all = await outbox.db.select(outbox.db.pendingOperations).get();
    final visible = <PendingOperation>[];
    for (final operation in all) {
      if (operation.operationType != 'checkout.v1') continue;
      try {
        final command = OfflineCheckoutCommand.decode(operation.payloadJson);
        if (command.requestId == operation.id && command.actorId == actor.id) {
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
  }

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
                SelectableText('Mã giao dịch: ${operation.id}'),
                const SizedBox(height: 8),
                Text('Trạng thái: ${_statusText(operation.status)}'),
                Text('Lưu lúc: ${_date(operation.createdAt)}'),
                Text('Khách hàng: ${command.customerId}'),
                Text('Nhân viên: ${command.actorId}'),
                Text('Tiền đã thu (đ): ${command.paid}'),
                Text('Phí giao hàng (đ): ${command.ship}'),
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
                    title: Text(line.productId),
                    subtitle: Text(
                      'Số lượng quy đổi: ${line.area}\n'
                      'Đơn giá: ${line.quotedPrice} đ / đơn vị\n'
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
    body: FutureBuilder<List<PendingOperation>>(
      future: _operations,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
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
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final operation = items[index];
            final command = OfflineCheckoutCommand.decode(
              operation.payloadJson,
            );
            return Card(
              child: ListTile(
                key: ValueKey('offline-order-${operation.id}'),
                title: Text(
                  operation.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_date(operation.createdAt)} · Khách ${command.customerId}\n'
                  '${command.lines.length} mặt hàng · ${_statusText(operation.status)}',
                ),
                isThreeLine: true,
                trailing: Icon(
                  Icons.chevron_right,
                  color: _statusColor(operation.status),
                ),
                onTap: () => _showDetails(operation),
              ),
            );
          },
        );
      },
    ),
  );
}
