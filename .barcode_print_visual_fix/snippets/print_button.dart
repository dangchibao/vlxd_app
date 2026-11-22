FilledButton.icon(
  style: FilledButton.styleFrom(
    backgroundColor: const Color(0xFF0F766E),
    foregroundColor: Colors.white,
  ),
  onPressed: () => attempt(() => PrintService.barcode(p)),
  icon: const Icon(Icons.print_outlined),
  label: const Text('In tem mã vạch'),
),
