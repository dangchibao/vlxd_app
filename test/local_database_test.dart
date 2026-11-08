import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:vlxd_app/data/local/app_database.dart';

import 'dart:io';

import 'package:path/path.dart' as p;

void main() {
  test('Outbox vẫn còn dữ liệu sau khi đóng và mở database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vlxd_offline_test_',
    );

    final dbFile = File(p.join(directory.path, 'offline.sqlite'));

    try {
      // Lần 1: Mở database và ghi dữ liệu.
      final db1 = AppDatabase.forTesting(NativeDatabase(dbFile));

      await db1
          .into(db1.pendingOperations)
          .insert(
            PendingOperationsCompanion.insert(
              id: 'offline-operation-001',
              operationType: 'sale',
              payloadJson: '{"orderId":"TEST001"}',
            ),
          );

      await db1.close();

      // Lần 2: Mở lại chính file database đó.
      final db2 = AppDatabase.forTesting(NativeDatabase(dbFile));

      try {
        final operations = await db2.select(db2.pendingOperations).get();

        expect(operations.length, 1);
        expect(operations.first.id, 'offline-operation-001');
        expect(operations.first.status, 'pending');
        expect(operations.first.operationType, 'sale');
      } finally {
        await db2.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
