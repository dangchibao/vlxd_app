// mobile-barcode-print-teal-v1: same action as desktop.
const PopupMenuItem<String>(
  value: 'barcode',
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.print_outlined, color: Color(0xFF0F766E), size: 18),
      SizedBox(width: 8),
      Text(
        'Mã vạch & In',
        style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
      ),
    ],
  ),
),
