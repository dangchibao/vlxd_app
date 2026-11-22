/// Unit conversion rules for new transactions. Legacy quantities are stored in
/// 1/10,000 of the product base unit; never reinterpret historical records.
const int productUnitScale = 10000;

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
