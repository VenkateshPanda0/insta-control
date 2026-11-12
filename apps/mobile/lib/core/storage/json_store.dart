import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes one JSON document per key in local storage.
abstract interface class JsonStore {
  Object? read(String key);
  Future<void> write(String key, Object? value);
}

class PrefsJsonStore implements JsonStore {
  PrefsJsonStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  Object? read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null; // Corrupt data is treated as absent rather than crashing.
    }
  }

  @override
  Future<void> write(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));
}
