import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/progress.dart';

abstract interface class ProgressRepository {
  Future<ProgressStats> load();
  Future<void> save(ProgressStats stats);
}

class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _key = 'brain_nourishment.progress.v1';

  @override
  Future<ProgressStats> load() async {
    final saved = await _preferences.getString(_key);
    if (saved == null) return const ProgressStats();
    return ProgressStats.fromJson(jsonDecode(saved) as Map<String, dynamic>);
  }

  @override
  Future<void> save(ProgressStats stats) =>
      _preferences.setString(_key, jsonEncode(stats.toJson()));
}
