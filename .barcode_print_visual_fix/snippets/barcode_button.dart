// barcode-print-teal-v1: Code 128 preview and print, not QR scanning.
Tooltip(
  message: 'Xem mã vạch Code 128 và in tem sản phẩm',
  child: OutlinedButton.icon(
    key: ValueKey('barcode-print-${p.id}'),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF0F766E),
      backgroundColor: const Color(0xFFE6F7F5),
      side: const BorderSide(color: Color(0xFF9AD5CF)),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      minimumSize: const Size(0, 40),
      visualDensity: VisualDensity.compact,
    ),
    onPressed: () => showBarcode(context, p),
    icon: const Icon(Icons.print_outlined, size: 20),
    label: const Text(
      'Mã vạch & In',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  ),
),
