// Only the preview navigation is tested here. No printing, network or data writes.
import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:vlxd_app/ui/app.dart';

void main() {
  final order = <String, dynamic>{
    'id': 'DH-UI-1',
    'status': 'Đã bán',
    'customerId': '',
    'customerName': 'Khách lẻ',
    'lines': <Map<String, dynamic>>[],
    'subtotal': 0,
    'discount': 0,
    'ship': 0,
    'total': 0,
    'payments': <Map<String, dynamic>>[],
  };
  final before = jsonEncode(order);

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('Invoice paper chooser is K80-first and responsive at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: InvoicePrintPreview(order: order, demo: true)),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('invoice-select-k80')), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-select-a4')), findsOneWidget);
      expect(find.byType(PdfPreview), findsNothing);
      expect(find.text('Chọn khổ giấy'), findsOneWidget);
      expect(find.textContaining('K80 · In nhiệt'), findsOneWidget);
      expect(find.textContaining('A4 · In giấy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('Chooser does not change invoice payload', () {
    expect(jsonEncode(order), before);
  });
}
