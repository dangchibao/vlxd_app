import 'dart:convert';
import 'dart:math' as math;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Barcode;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../controllers/shop_controller.dart';
import '../controllers/session_controller.dart';
import '../data/demo_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/shop.dart';
import '../domain/invoice_filter.dart';
import 'print_service.dart';
import '../utils/money_input_formatter.dart';

import '../data/sync/outbox_repository.dart';

part 'catalog.dart';
part 'sales.dart';
part 'operations.dart';
part 'authentication.dart';
part 'accounts.dart';
part 'history.dart';
part 'shell.dart';
part 'debt.dart';
part 'invoices.dart';
part 'finance_settings.dart';
part 'audit_text.dart';

const blue = Color(0xFF086EEB);
const ink = Color(0xFF142D50);
String money(num v) => '${NumberFormat.decimalPattern('vi').format(v)} đ';
String area(num v) => NumberFormat('0.##', 'vi').format(v / 10000);
String day(String v) =>
    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(v).toLocal());
double decimal(String v) =>
    double.tryParse(v.trim().replaceAll(',', '.')) ?? double.nan;
int whole(String v) => int.tryParse(v.replaceAll(' ', '').trim()) ?? -1;
String newId() => const Uuid().v4();

class BayHaiApp extends StatelessWidget {
  const BayHaiApp({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'VLXD Bảy Hải',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
    home: GetBuilder<ShopController>(
      builder: (c) => Get.isRegistered<SessionController>()
          ? const FirebaseGate()
          : c.actor == null
          ? const LoginPage()
          : const ShopShell(),
    ),
  );
}

Future<void> attempt(Future<void> Function() work) async {
  try {
    await work();
  } catch (e) {
    Get.snackbar(
      'Chưa thực hiện được',
      e
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', ''),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }
}

// A pop future resolves before the closing animation. Keep form controllers
// alive until the route is actually removed, including when opening a new dialog.
Future<T?> safeDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await Navigator.of(context).push<T>(route);
  await route.completed;
  return result;
}

Widget panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(20)}) =>
    Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
Widget titleText(String text, {double size = 24}) => Text(
  text,
  style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: ink),
);
Widget hint(String text, {Color? color}) => Text(
  text,
  style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF657993)),
);
Widget badge(String text, {bool warning = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: warning ? const Color(0xFFFFF0D7) : const Color(0xFFE8F2FF),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: warning ? const Color(0xFF965D00) : blue,
      fontWeight: FontWeight.w600,
    ),
  ),
);

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: panel(
              LayoutBuilder(
                builder: (context, box) {
                  final form = Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.roofing_rounded,
                          color: blue,
                          size: 50,
                        ),
                        const SizedBox(height: 12),
                        titleText('VLXD Bảy Hải', size: 30),
                        const SizedBox(height: 6),
                        hint('Gò Dầu • Tây Ninh'),
                        const SizedBox(height: 30),
                        titleText('Chào mừng trở lại'),
                        const SizedBox(height: 12),
                        const Text(
                          'Bản chạy thử giao diện và nghiệp vụ. Dữ liệu mẫu lưu trên thiết bị này, chưa kết nối Firebase.',
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () =>
                              Get.find<ShopController>().enterDemo(Role.owner),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('Dùng thử với vai trò Chủ'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Get.find<ShopController>().enterDemo(Role.sales),
                          icon: const Icon(Icons.person_outline),
                          label: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Dùng thử với vai trò Nhân viên'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        hint(
                          'Đăng nhập tên tài khoản / SĐT và mật khẩu sẽ bật sau khi cấu hình Firebase. Không nhập dữ liệu thật vào bản thử.',
                        ),
                        const SizedBox(height: 12),
                        hint(
                          'Quên mật khẩu: nhờ admin đặt lại. Tài xế và vị trí khác chưa được truy cập.',
                        ),
                      ],
                    ),
                  );
                  if (box.maxWidth < 750) return form;
                  return IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.grid_view_rounded,
                                  color: Colors.white,
                                  size: 80,
                                ),
                                const SizedBox(height: 30),
                                const Text(
                                  'Quản lý cửa hàng\nngay trong tầm tay',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Gạch men • Bán hàng • Kho\nGiao hàng • Công nợ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    height: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                badge('BẢN THỬ • KHÔNG THU PHÍ'),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: form),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

const destinations = [
  'Tổng quan',
  'Hàng hóa',
  'Bán hàng',
  'Kho',
  'Giao hàng',
  'Công nợ',
  'Báo cáo',
  'Nhật ký',
  'Cài đặt',
  'Hóa đơn',
];
const navIcons = [
  Icons.dashboard_outlined,
  Icons.grid_view_outlined,
  Icons.shopping_cart_outlined,
  Icons.warehouse_outlined,
  Icons.local_shipping_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.bar_chart,
  Icons.history,
  Icons.settings_outlined,
  Icons.receipt_long_outlined,
];

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    final sold = c.data.orders.where((o) => o['status'] == 'Đã bán').toList();
    final revenue = sold.fold<int>(0, (s, o) => s + (o['total'] as int));
    final collected = c.data.orders.fold<int>(
      0,
      (s, o) => s + ShopData.netCollected(o),
    );
    final soldArea = sold.fold<int>(
      0,
      (s, o) =>
          s +
          (o['lines'] as List)
              .where((l) => (l['unit'] ?? 'm²') == 'm²')
              .fold<int>(0, (v, l) => v + (l['area'] as int)),
    );
    final low = c.data.products
        .where((p) => p.active && p.available <= p.minimum)
        .toList();
    final old = c.data.products
        .where((p) => p.active && p.isOld(DateTime.now()))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleText('Cửa hàng trong tầm tay'),
                const SizedBox(height: 6),
                hint(
                  '${c.isLive ? 'Dữ liệu cửa hàng' : 'Toàn bộ dữ liệu mẫu'} • ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => c.navigate(2),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Tạo đơn hàng'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, b) {
            final cols = b.maxWidth > 1000
                ? 4
                : b.maxWidth > 600
                ? 2
                : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children:
                  [
                        metric(
                          'Tổng doanh thu đơn đã bán',
                          money(revenue),
                          Icons.trending_up,
                          blue,
                        ),
                        metric(
                          'Tổng tiền thực thu',
                          money(collected),
                          Icons.payments_outlined,
                          const Color(0xFF168366),
                        ),
                        metric(
                          'Diện tích đã bán',
                          '${area(soldArea)} m²',
                          Icons.layers_outlined,
                          const Color(0xFF7353BA),
                        ),
                        metric(
                          'Chuyến đang giao',
                          '${c.data.deliveries.where((d) => d['status'] != 'Đã xong').length}',
                          Icons.local_shipping_outlined,
                          const Color(0xFFC17C10),
                        ),
                      ]
                      .map(
                        (w) => SizedBox(
                          width: (b.maxWidth - (cols - 1) * 16) / cols,
                          child: w,
                        ),
                      )
                      .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText('Việc cần chú ý', size: 18),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.orange,
                ),
                title: Text('${low.length} mẫu sắp hết hàng'),
                subtitle: Text(low.map((p) => p.name).join(' • ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => c.navigate(3),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: blue),
                title: Text('${old.length} mẫu có lô tồn trên 60 ngày'),
                subtitle: const Text('Xem từng lô để lên kế hoạch xả kho'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => c.navigate(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText('Đơn hàng gần đây', size: 18),
              const SizedBox(height: 12),
              if (c.data.orders.isEmpty)
                const EmptyState(
                  'Chưa có đơn mẫu',
                  'Chọn Bán hàng để thử tạo đơn đầu tiên.',
                  Icons.receipt_long_outlined,
                ),
              ...c.data.orders
                  .take(6)
                  .map(
                    (o) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(o['id']),
                      subtitle: Text('${day(o['at'])} • ${o['status']}'),
                      trailing: Text(
                        money(o['total']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => showOrder(context, o),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget metric(String label, String value, IconData icon, Color color) =>
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 14),
            hint(label),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  final String title, description;
  final IconData icon;
  const EmptyState(this.title, this.description, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF91A6C0), size: 44),
          const SizedBox(height: 16),
          titleText(title, size: 17),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF657993)),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await safeDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;

Widget field(
  TextEditingController c,
  String label, {
  bool number = false,
  bool moneyInput = false,
  bool enabled = true,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextField(
    controller: c,
    enabled: enabled,
    keyboardType: moneyInput
        ? TextInputType.number
        : number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters: moneyInput ? [const MoneyInputFormatter()] : null,
    decoration: InputDecoration(labelText: label),
  ),
);
