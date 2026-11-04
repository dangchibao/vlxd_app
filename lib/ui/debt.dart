part of 'app.dart';

class DebtPage extends StatefulWidget {
  const DebtPage({super.key});
  @override
  State<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends State<DebtPage> {
  String query = '';
  String? selectedId;
  bool salary = false;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    final customers = c.data.customers
        .where(
          (x) =>
              x['active'] != false &&
              '${x['name']} ${x['phone']}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final selected =
        customers.where((x) => x['id'] == selectedId).firstOrNull ??
        customers.firstOrNull;
    final debt = c.data.customers.fold<int>(
      0,
      (s, x) => s + c.data.debt(x['id']),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1060;
        final customerPanel = _customers(context, c, customers, selected);
        final detail = _detail(context, c, selected);
        final payroll = _payroll(context, c);
        return ListView(
          padding: EdgeInsets.all(box.maxWidth < 600 ? 16 : 24),
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: titleText(
                    'Công nợ và lương nhân viên',
                    size: box.maxWidth < 600 ? 22 : 26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            hint(
              'Theo dõi khoản phải thu, lịch sử thanh toán và lương nhân viên.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Khách còn nợ'),
                  selected: !salary,
                  onSelected: (_) => setState(() => salary = false),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Lương nhân viên'),
                  selected: salary,
                  onSelected: (_) => setState(() => salary = true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, metricsBox) {
                final cols = metricsBox.maxWidth >= 650 ? 3 : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      [
                            _summary(
                              'Tổng khách hàng',
                              '${c.data.customers.where((x) => x['active'] != false).length}',
                              Icons.people_outline,
                              blue,
                            ),
                            _summary(
                              'Công nợ phải thu',
                              money(debt),
                              Icons.account_balance_wallet_outlined,
                              const Color(0xFFD28A16),
                            ),
                            _summary(
                              'Khách còn nợ',
                              '${c.data.customers.where((x) => c.data.debt(x['id']) > 0).length}',
                              Icons.person_search_outlined,
                              const Color(0xFF168366),
                            ),
                          ]
                          .map(
                            (w) => SizedBox(
                              width:
                                  (metricsBox.maxWidth - (cols - 1) * 12) /
                                  cols,
                              child: w,
                            ),
                          )
                          .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        if (!salary) ...[
                          customerPanel,
                          const SizedBox(height: 16),
                        ],
                        payroll,
                      ],
                    ),
                  ),
                  if (!salary) ...[
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: detail),
                  ],
                ],
              )
            else if (salary)
              payroll
            else ...[
              customerPanel,
              const SizedBox(height: 16),
              detail,
            ],
          ],
        );
      },
    );
  }

  Widget _summary(String label, String value, IconData icon, Color color) =>
      panel(
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  hint(label),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
      );

  Widget _customers(
    BuildContext context,
    ShopController c,
    List<Json> customers,
    Json? selected,
  ) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            titleText('Sổ công nợ khách hàng', size: 18),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => editCustomer(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm khách hàng'),
                ),
                IconButton(
                  tooltip: 'Cài đặt sổ công nợ',
                  onPressed: c.busy ? null : () => openDebtSettings(context),
                  icon: const Icon(Icons.settings_outlined, color: blue),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Tìm tên khách hàng, số điện thoại…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        _table(
          DataTable(
            showCheckboxColumn: false,
            columnSpacing: 24,
            horizontalMargin: 12,
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F4FA)),
            columns: const [
              DataColumn(label: Text('Tên khách')),
              DataColumn(label: Text('Phải thu'), numeric: true),
              DataColumn(label: Text('Đã thu'), numeric: true),
              DataColumn(label: Text('Còn nợ'), numeric: true),
              DataColumn(label: Text('Trạng thái')),
              DataColumn(label: Text('Thao tác')),
            ],
            rows: customers.map((customer) {
              final book = c.data.customerBook(customer['id']);
              final total = book.receivable, paid = book.received;
              final owed = c.data.debt(customer['id']);
              return DataRow(
                selected: selected?['id'] == customer['id'],
                onSelectChanged: (_) =>
                    setState(() => selectedId = customer['id']),
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['name'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        hint(customer['phone']),
                      ],
                    ),
                  ),
                  DataCell(Text(money(total))),
                  DataCell(Text(money(paid))),
                  DataCell(
                    Text(
                      money(owed),
                      style: TextStyle(
                        color: owed > 0 ? const Color(0xFFB67205) : ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DataCell(
                    badge(
                      total == 0
                          ? 'Chưa phát sinh'
                          : owed == 0
                          ? 'Đã trả'
                          : paid > 0
                          ? 'Trả một phần'
                          : 'Chưa trả',
                      warning: owed > 0,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sửa thông tin khách',
                          onPressed: () =>
                              editCustomer(context, original: customer),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: blue,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa khách hàng',
                          onPressed: c.busy
                              ? null
                              : () => deleteCustomer(context, customer),
                          icon: const Icon(Icons.close, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        if (customers.isEmpty)
          const EmptyState(
            'Chưa có khách hàng phù hợp',
            'Thêm khách hàng để theo dõi công nợ. Khoản nợ được tính từ đơn hàng thực tế.',
            Icons.people_outline,
          ),
        const SizedBox(height: 12),
        hint(
          '${customers.length} khách hàng • Chọn một dòng để xem lịch sử thanh toán',
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
  );

  Widget _detail(BuildContext context, ShopController c, Json? customer) {
    if (customer == null) {
      return panel(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chi tiết thanh toán',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 40),
            EmptyState(
              'Chưa chọn khách hàng',
              'Thông tin khách, số tiền còn nợ và các lần thanh toán sẽ hiển thị tại đây.',
              Icons.receipt_long_outlined,
            ),
            SizedBox(height: 40),
          ],
        ),
      );
    }
    final orders = c.data.orders
        .where((o) => o['customerId'] == customer['id'])
        .toList();
    final payments = <({Json order, Json payment})>[];
    for (final o in orders) {
      for (final p in o['payments'] as List) {
        payments.add((order: o, payment: Map<String, dynamic>.from(p)));
      }
    }
    payments.sort(
      (a, b) => '${b.payment['at']}'.compareTo('${a.payment['at']}'),
    );
    final unpaid = orders
        .where(
          (o) =>
              o['status'] != 'Đã hủy' &&
              (o['total'] as int) > ShopData.collected(o),
        )
        .toList();
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE5F0FF),
                child: Text(
                  (customer['name'] as String).characters.firstOrNull ?? '?',
                  style: const TextStyle(
                    color: blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleText(customer['name'], size: 20),
                    const SizedBox(height: 4),
                    hint(customer['phone']),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sửa thông tin khách',
                onPressed: () => editCustomer(context, original: customer),
                icon: const Icon(Icons.edit_outlined, color: blue),
              ),
              IconButton(
                tooltip: 'Xóa khách hàng',
                onPressed: c.busy
                    ? null
                    : () => deleteCustomer(context, customer),
                icon: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hint('Còn nợ hiện tại'),
                const SizedBox(height: 4),
                titleText(money(c.data.debt(customer['id'])), size: 26),
              ],
            ),
          ),
          const SizedBox(height: 24),
          titleText('Lịch sử thanh toán', size: 18),
          const SizedBox(height: 12),
          _table(
            DataTable(
              horizontalMargin: 8,
              columnSpacing: 20,
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F4FA)),
              columns: const [
                DataColumn(label: Text('Ngày thu')),
                DataColumn(label: Text('Số tiền')),
                DataColumn(label: Text('Đơn hàng')),
              ],
              rows: payments
                  .map(
                    (entry) => DataRow(
                      cells: [
                        DataCell(Text(day(entry.payment['at']))),
                        DataCell(
                          Text(
                            '${money(entry.payment['amount'])}${entry.payment['voided'] == true ? ' • Đã hủy lần thu' : ''}',
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () => showOrder(context, entry.order),
                            child: Text(entry.order['id']),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Chưa có lần thanh toán nào.',
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),
          titleText('Đơn hàng của khách', size: 16),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Chưa có đơn hàng.'),
            ),
          ...orders.map(
            (o) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${o['id']} • ${o['status']}'),
              subtitle: Text('Tổng ${money(o['total'])}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showOrder(context, o),
            ),
          ),
          if (unpaid.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.add_card),
              label: const Text('Ghi nhận trả tiền'),
              onPressed: () async {
                if (unpaid.length == 1) {
                  await collectPayment(context, unpaid.first);
                  return;
                }
                if (!context.mounted) return;
                await safeDialog<void>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Chọn đơn cần thu tiền'),
                    children: unpaid
                        .map(
                          (o) => SimpleDialogOption(
                            child: Text(
                              '${o['id']} • Còn ${money((o['total'] as int) - ShopData.collected(o))}',
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              collectPayment(context, o);
                            },
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          hint(
            'Mở đơn hàng để sửa hoặc hủy lần thu; lịch sử gốc được giữ lại.',
          ),
          if (c.data.audit.any(
            (x) =>
                x['target'] == customer['id'] &&
                x['action'] == 'Điều chỉnh sổ công nợ',
          )) ...[
            const SizedBox(height: 20),
            titleText('Điều chỉnh sổ công nợ', size: 16),
            ...c.data.audit
                .where(
                  (x) =>
                      x['target'] == customer['id'] &&
                      x['action'] == 'Điều chỉnh sổ công nợ',
                )
                .take(10)
                .map(
                  (x) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(day(x['at'])),
                    subtitle: Text(x['detail']),
                    leading: const Icon(Icons.manage_history, color: blue),
                  ),
                ),
          ],
        ],
      ),
      padding: const EdgeInsets.all(18),
    );
  }

  Widget _payroll(BuildContext context, ShopController c) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            titleText('Lương nhân viên', size: 18),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => createPayroll(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo kỳ lương'),
                ),
                IconButton(
                  tooltip: 'Cài đặt lương',
                  onPressed: c.busy ? null : () => openPayrollSettings(context),
                  icon: const Icon(Icons.settings_outlined, color: blue),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _table(
          DataTable(
            horizontalMargin: 12,
            columnSpacing: 24,
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF0F4FA)),
            columns: const [
              DataColumn(label: Text('Nhân viên')),
              DataColumn(label: Text('Kỳ lương')),
              DataColumn(label: Text('Lương')),
              DataColumn(label: Text('Đã ứng / trả')),
              DataColumn(label: Text('Còn phải trả')),
              DataColumn(label: Text('Thao tác')),
            ],
            rows: c.data.payroll
                .map(
                  (p) => DataRow(
                    cells: [
                      DataCell(Text(p['name'])),
                      DataCell(Text(p['period'])),
                      DataCell(Text(money(p['salary']))),
                      DataCell(Text(money(p['advance']))),
                      DataCell(
                        Text(
                          money((p['salary'] as int) - (p['advance'] as int)),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'Sửa lương / ghi chi',
                          onPressed: () => editSalary(context, p),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
        if (c.data.payroll.isEmpty)
          const EmptyState(
            'Chưa có kỳ lương',
            'Chủ cửa hàng tạo kỳ lương để theo dõi số tiền đã trả và còn phải trả.',
            Icons.groups_outlined,
          ),
      ],
    ),
    padding: const EdgeInsets.all(16),
  );

  Widget _table(Widget table) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: table,
      ),
    ),
  );
}
