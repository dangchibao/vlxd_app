// unit-correction-amber-action-v1: deliberate stock correction.
Tooltip(
  message: 'Đính chính đơn vị nhập nhầm (Admin) - cần đối chiếu kho',
  child: TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF8A5000),
      backgroundColor: const Color(0xFFFFE8BE),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      minimumSize: const Size(0, 40),
    ),
    onPressed: () => correctReceivedUnitDialog(context, p),
    icon: const Icon(Icons.fact_check_outlined, size: 20),
    label: const Text(
      'Đính chính đơn vị',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  ),
),
