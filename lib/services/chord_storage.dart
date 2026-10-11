import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../chord_logic.dart';

/// Persistence uložených akordů (SharedPreferences, JSON).
/// Klíč je verzovaný, aby šla data v budoucnu migrovat.
class ChordStorage {
  static const String key = 'saved_chords_v1';

  Future<List<SavedChord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return loadFrom(prefs);
  }

  Future<void> save(List<SavedChord> chords) async {
    final prefs = await SharedPreferences.getInstance();
    await saveTo(prefs, chords);
  }

  /// Testovatelné varianty s injektovanými prefs.
  List<SavedChord> loadFrom(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedChord.fromJson)
          .where((c) => c.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      // Poškozená data: raději prázdný seznam než pád.
      return [];
    }
  }

  Future<void> saveTo(SharedPreferences prefs, List<SavedChord> chords) {
    final raw = jsonEncode(chords.map((c) => c.toJson()).toList());
    return prefs.setString(key, raw);
  }
}
