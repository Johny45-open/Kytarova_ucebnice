import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../chord_logic.dart';

/// Persistence uložených akordů a složek (SharedPreferences, JSON).
/// v1 (pouze akordy) se při prvním čtení migruje do v2 (složky + akordy).
class ChordStorage {
  static const String key = 'saved_chords_v1';
  static const String libraryKey = 'saved_chords_v2';
  static int _idSeq = 0;

  /// Nové id složky (unikátní i při rychlém opakovaném volání).
  static String newFolderId() {
    _idSeq++;
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$_idSeq';
  }

  /// Nové API: celá knihovna (složky + akordy) včetně migrace z v1.
  Future<ChordLibrary> loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    return loadLibraryFrom(prefs);
  }

  Future<void> saveLibrary(ChordLibrary library) async {
    final prefs = await SharedPreferences.getInstance();
    await saveLibraryTo(prefs, library);
  }

  ChordLibrary loadLibraryFrom(SharedPreferences prefs) {
    final raw = prefs.getString(libraryKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final folders = ((decoded['folders'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChordFolder.fromJson)
            .where((f) => f.id.isNotEmpty && f.name.trim().isNotEmpty)
            .toList();
        final folderIds = folders.map((f) => f.id).toSet();
        final chords = ((decoded['chords'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SavedChord.fromJson)
            .where((c) => c.name.trim().isNotEmpty)
            .toList();
        // Siřetčí folderId bez existující složky -> Bez složky.
        for (final c in chords) {
          if (c.folderId != null && !folderIds.contains(c.folderId)) {
            c.folderId = null;
          }
        }
        return ChordLibrary(folders: folders, chords: chords);
      } catch (_) {
        return ChordLibrary(folders: [], chords: []);
      }
    }
    // Migrace z v1: akordy bez složek.
    final migrated = loadFrom(prefs);
    return ChordLibrary(folders: [], chords: migrated);
  }

  Future<void> saveLibraryTo(SharedPreferences prefs, ChordLibrary library) {
    final raw = jsonEncode({
      'folders': library.folders.map((f) => f.toJson()).toList(),
      'chords': library.chords.map((c) => c.toJson()).toList(),
    });
    return prefs.setString(libraryKey, raw);
  }

  /// Staré API pro akordy (složky se zachovají). Ponecháno kvůli testům.
  Future<List<SavedChord>> load() async {
    return (await loadLibrary()).chords;
  }

  Future<void> save(List<SavedChord> chords) async {
    final prefs = await SharedPreferences.getInstance();
    List<ChordFolder> folders = [];
    final raw = prefs.getString(libraryKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        folders = ((decoded['folders'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChordFolder.fromJson)
            .where((f) => f.id.isNotEmpty && f.name.trim().isNotEmpty)
            .toList();
      } catch (_) {}
    }
    await saveLibraryTo(prefs, ChordLibrary(folders: folders, chords: chords));
  }

  /// Testovatelné varianty s injektovanými prefs (formát v1).
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

/// Celá knihovna: složky + akordy.
class ChordLibrary {
  final List<ChordFolder> folders;
  final List<SavedChord> chords;
  ChordLibrary({required this.folders, required this.chords});
}
