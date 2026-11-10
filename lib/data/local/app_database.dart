import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class PendingOperations extends Table {
  TextColumn get id => text()();

  TextColumn get operationType => text()();

  TextColumn get payloadJson => text()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [PendingOperations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open('vlxd_bayhai_local'));

  // Tách tuyệt đối Outbox thử nghiệm khỏi Outbox cửa hàng thật.
  AppDatabase.forEmulator() : super(_open('vlxd_bayhai_emulator_test'));

  static QueryExecutor _open(String name) => driftDatabase(
    name: name,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.base.resolve('sqlite3.wasm'),
      driftWorker: Uri.base.resolve('drift_worker.js'),
      onResult: (result) {
        if ([
          'inMemory',
          'unsafeIndexedDb',
        ].contains(result.chosenImplementation.name)) {
          throw StateError(
            'Trình duyệt không cung cấp bộ nhớ lưu đơn bền vững.',
          );
        }
      },
    ),
  );

  // Dùng database riêng cho kiểm thử.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
