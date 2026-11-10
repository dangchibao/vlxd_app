part of 'app.dart';

/// Phân trang giao diện: không cắt/xóa dữ liệu gốc, chỉ giới hạn phần hiển thị.
class VlxdPager extends StatelessWidget {
  const VlxdPager({
    super.key,
    required this.total,
    required this.page,
    required this.onChanged,
    this.pageSize = 10,
  });
  final int total;
  final int page;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pages = math.max(1, (total / pageSize).ceil());
    final current = page.clamp(0, pages - 1).toInt();
    if (total <= pageSize) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: current == 0 ? null : () => onChanged(current - 1),
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Trước'),
          ),
          Text(
            '${current + 1} / $pages',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          OutlinedButton.icon(
            onPressed: current + 1 >= pages
                ? null
                : () => onChanged(current + 1),
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Sau'),
          ),
          Text('${total} mục', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Một trang danh sách dùng trong ListView cha; không tạo vùng cuộn lồng nhau.
class VlxdPagedList<T> extends StatefulWidget {
  const VlxdPagedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 10,
  });
  final List<T> items;
  final Widget Function(T item) itemBuilder;
  final int pageSize;

  @override
  State<VlxdPagedList<T>> createState() => _VlxdPagedListState<T>();
}

class _VlxdPagedListState<T> extends State<VlxdPagedList<T>> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final maxPage = math.max(0, (widget.items.length - 1) ~/ widget.pageSize);
    final visiblePage = math.min(page, maxPage);
    final items = widget.items
        .skip(visiblePage * widget.pageSize)
        .take(widget.pageSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.map(widget.itemBuilder),
        VlxdPager(
          total: widget.items.length,
          page: visiblePage,
          pageSize: widget.pageSize,
          onChanged: (v) => setState(() => page = v),
        ),
      ],
    );
  }
}

class VlxdPagedGrid<T> extends StatefulWidget {
  const VlxdPagedGrid({
    super.key,
    required this.items,
    required this.gridDelegate,
    required this.itemBuilder,
    this.pageSize = 12,
    this.padding = EdgeInsets.zero,
  });
  final List<T> items;
  final SliverGridDelegate gridDelegate;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int pageSize;
  final EdgeInsetsGeometry padding;
  @override
  State<VlxdPagedGrid<T>> createState() => _VlxdPagedGridState<T>();
}

class _VlxdPagedGridState<T> extends State<VlxdPagedGrid<T>> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final maxPage = math.max(0, (widget.items.length - 1) ~/ widget.pageSize);
    final visiblePage = math.min(page, maxPage);
    final visible = widget.items
        .skip(visiblePage * widget.pageSize)
        .take(widget.pageSize)
        .toList();
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: widget.padding,
            gridDelegate: widget.gridDelegate,
            itemCount: visible.length,
            itemBuilder: (context, i) =>
                widget.itemBuilder(context, visible[i]),
          ),
        ),
        VlxdPager(
          total: widget.items.length,
          page: visiblePage,
          pageSize: widget.pageSize,
          onChanged: (v) => setState(() => page = v),
        ),
      ],
    );
  }
}
