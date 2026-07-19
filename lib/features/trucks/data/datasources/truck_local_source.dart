import 'dart:convert';

import 'package:hive/hive.dart';

class TruckLocalSource {
  final Box<String> _cache;

  static const _trucksKey = 'trucks_cache';
  static const _timestampKey = 'trucks_cache_time';

  TruckLocalSource(this._cache);

  Future<void> cacheTrucks(List<Map<String, dynamic>> trucks) async {
    await _cache.put(_trucksKey, jsonEncode(trucks));
  }

  List<Map<String, dynamic>> getCachedTrucks() {
    final raw = _cache.get(_trucksKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateCacheTime() async {
    await _cache.put(_timestampKey, DateTime.now().toIso8601String());
  }

  DateTime? getLastCacheTime() {
    final ts = _cache.get(_timestampKey);
    return ts != null ? DateTime.tryParse(ts) : null;
  }

  bool get hasCachedData => _cache.containsKey(_trucksKey);
}
