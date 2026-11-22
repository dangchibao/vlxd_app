/// Unit conversion rules for new transactions. Legacy quantities are stored in
/// 1/10,000 of the product base unit; never reinterpret historical records.
const int productUnitScale = 10000;

/// Decimal snapshots are strings: preserve entered precision without changing
/// the existing integer stock or money calculations.
String saleDecimal(String input) {
  input = input.trim();
  if (input.startsWith('+')) input = input.substring(1);
  if (input.startsWith('.') || input.startsWith(',')) input = '0$input';
  final match = RegExp(r'^\+?(\d+)(?:[.,](\d*))?(?:[eE]([+-]?\d+))?$')
      .firstMatch(input.trim());
  if (match == null || input.length > 64) {
    throw const FormatException('Số lượng không hợp lệ.');
  }
  final fraction = match[2] ?? '';
  final exponent = int.tryParse(match[3] ?? '0');
  if (exponent == null || exponent.abs() > 20) {
    throw const FormatException('Số lượng vượt giới hạn.');
  }
  var digits = BigInt.parse('${match[1]}$fraction');
  var scale = fraction.length - exponent;
  if (scale < 0) {
    digits *= BigInt.from(10).pow(-scale);
    scale = 0;
  }
  return _saleDecimalText(digits, scale);
}

String _saleDecimalText(BigInt digits, int scale) {
  if (scale == 0) return digits.toString();
  final text = digits.toString().padLeft(scale + 1, '0');
  return '${text.substring(0, text.length - scale)}.${text.substring(text.length - scale)}'
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Both operands must be non-negative decimal snapshots.
String addSaleQuantities(String left, String right, {bool subtract = false}) {
  final a = saleDecimal(left).split('.');
  final b = saleDecimal(right).split('.');
  final scale =
      (a.length == 2 ? a[1].length : 0) > (b.length == 2 ? b[1].length : 0)
      ? (a.length == 2 ? a[1].length : 0)
      : (b.length == 2 ? b[1].length : 0);
  BigInt value(List<String> parts) => BigInt.parse(
    '${parts[0]}${(parts.length == 2 ? parts[1] : '').padRight(scale, '0')}',
  );
  final result = subtract ? value(a) - value(b) : value(a) + value(b);
  if (result < BigInt.zero) throw const FormatException('Số lượng âm.');
  return _saleDecimalText(result, scale);
}

/// Exact price per selected unit; presentation snapshot only, never a new price
/// used to recalculate a committed amount.
String salePriceSnapshot(int basePrice, int factor) =>
    _saleDecimalText(BigInt.from(basePrice) * BigInt.from(factor), 4);

int roundedSaleDisplayAmount(String quantity, String price) {
  final q = saleDecimal(quantity).split('.');
  final p = saleDecimal(price).split('.');
  final scale =
      (q.length == 2 ? q[1].length : 0) + (p.length == 2 ? p[1].length : 0);
  final numerator = BigInt.parse(q.join()) * BigInt.parse(p.join());
  final divisor = BigInt.from(10).pow(scale);
  return ((numerator * BigInt.two + divisor) ~/ (divisor * BigInt.two)).toInt();
}

String canonicalProductUnit(String input) {
  final value = input.trim();
  switch (value.toLowerCase().replaceAll(' ', '')) {
    case 'm2':
    case 'm^2':
    case 'm²':
      return 'm²';
    case 'm3':
    case 'm^3':
    case 'm³':
      return 'm³';
    default:
      return value;
  }
}

/// Conversion factor in internal 1/10,000 units.
int inputUnitFactor({required int packRatio, required bool byPack}) =>
    byPack ? packRatio : productUnitScale;

/// Stores the cost for ONE base unit, regardless of the entered purchase unit.
/// The schema uses whole VND, therefore any fraction is explicitly rounded.
int baseUnitCostFromInput({
  required int enteredUnitCost,
  required int packRatio,
  required bool byPack,
}) {
  final factor = inputUnitFactor(packRatio: packRatio, byPack: byPack);
  if (factor <= 0 || enteredUnitCost < 0) {
    throw ArgumentError('Giá nhập hoặc hệ số quy đổi không hợp lệ.');
  }
  return (enteredUnitCost * productUnitScale / factor).round();
}

int baseQuantityFromInput({
  required double quantity,
  required int packRatio,
  required bool byPack,
}) {
  final factor = inputUnitFactor(packRatio: packRatio, byPack: byPack);
  if (factor <= 0 || !quantity.isFinite || quantity <= 0) {
    throw ArgumentError('Số lượng hoặc hệ số quy đổi không hợp lệ.');
  }
  final units = (quantity * factor).round();
  if (units <= 0) throw ArgumentError('Số lượng quá nhỏ.');
  return units;
}
