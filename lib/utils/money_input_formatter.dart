import 'package:flutter/services.dart';

class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) {
      return newValue;
    }

    final input = newValue.text;
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    int mapOffset(int offset) {
      if (offset < 0) return formatted.length;

      final safeOffset = offset.clamp(0, input.length);
      final digitsBefore = input
          .substring(0, safeOffset)
          .replaceAll(RegExp(r'[^0-9]'), '')
          .length;

      if (digitsBefore == 0) return 0;

      var count = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (formatted.codeUnitAt(i) >= 48 && formatted.codeUnitAt(i) <= 57) {
          count++;
        }
        if (count == digitsBefore) {
          return i + 1;
        }
      }
      return formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}
