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
  AppDatabase() : super(driftDatabase(name: 'vlxd_bayhai_local'));

  // Dùng database riêng cho kiểm thử.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
