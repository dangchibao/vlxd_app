import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/shop.dart';

abstract class ShopRepository {
  Future<ShopData> load();
  Future<void> save(ShopData data);
}

abstract class TransactionalShopRepository implements ShopRepository {
  Future<({ShopData data, T result})> transact<T>(
    T Function(ShopData data, Actor actor) operation,
    Actor actor,
  );
  Stream<ShopData> watch();
}

// Deliberately demo-only. Production financial data must use Firestore transactions.
class DemoRepository implements ShopRepository {
  final SharedPreferencesAsync preferences;
  DemoRepository(this.preferences);
  static const key = 'bay_hai_demo_v1';
  @override
  Future<ShopData> load() async {
    final stored = await preferences.getString(key);
    return stored == null
        ? ShopData.sample()
        : ShopData.fromJson(jsonDecode(stored));
  }

  @override
  Future<void> save(ShopData data) =>
      preferences.setString(key, jsonEncode(data.toJson()));
}
