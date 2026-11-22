import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/utils/money_input_formatter.dart';

void main() {
  const formatter = MoneyInputFormatter();

  TextEditingValue value(String text, int caret) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
  );

  test('backspace across a group separator deletes the preceding digit', () {
    final result = formatter.formatEditUpdate(
      value('12 345', 3),
      value('12345', 2),
    );
    expect(result.text, '1 345');
    expect(result.selection.baseOffset, 1);
  });

  test('forward delete across a separator deletes the following digit', () {
    final result = formatter.formatEditUpdate(
      value('12 345', 2),
      value('12345', 2),
    );
    expect(result.text, '1 245');
    expect(result.selection.baseOffset, 3);
  });

  test('typing in the middle keeps the caret beside the inserted digit', () {
    final result = formatter.formatEditUpdate(
      value('1 234', 3),
      value('1 2934', 4),
    );
    expect(result.text, '12 934');
    expect(result.selection.baseOffset, 4);
  });

  test('IME composing text is left unchanged', () {
    final input = value(
      '1234',
      4,
    ).copyWith(composing: const TextRange(start: 0, end: 4));
    expect(formatter.formatEditUpdate(value('', 0), input), input);
  });

  test('deleting a selected separator does not delete an extra digit', () {
    final old = value(
      '12 345',
      3,
    ).copyWith(selection: const TextSelection(baseOffset: 2, extentOffset: 3));
    final result = formatter.formatEditUpdate(old, value('12345', 2));
    expect(result.text, '12 345');
    expect(result.selection.baseOffset, 2);
  });
}
