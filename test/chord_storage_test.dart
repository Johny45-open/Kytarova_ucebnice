import 'package:flutter_test/flutter_test.dart';
import 'package:kytarova_ucebnice/chord_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kytarova_ucebnice/services/chord_storage.dart';

void main() {
  group('SavedChord JSON', () {
    test('roundtrip zachová jméno i pozice', () {
      final c = SavedChord('G', [3, 2, 0, 0, 0, 3]);
      final back = SavedChord.fromJson(c.toJson());
      expect(back.name, 'G');
      expect(back.positions, [3, 2, 0, 0, 0, 3]);
    });

    test('fromJson doplní chybějící struny na X', () {
      final back = SavedChord.fromJson({'name': 'A', 'positions': [0]});
      expect(back.positions, [0, -1, -1, -1, -1, -1]);
    });

    test('shortDescription a fullDescription nejsou prázdné', () {
      final c = SavedChord('Em', [0, 2, 2, 0, 0, 0]);
      expect(c.shortDescription, contains('E:O'));
      expect(c.fullDescription, contains('E tlusté'));
    });
  });

  group('ChordStorage', () {
    test('save + load roundtrip', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChordStorage();
      await storage.save([
        SavedChord('G', [3, 2, 0, 0, 0, 3]),
        SavedChord('Em', [0, 2, 2, 0, 0, 0]),
      ]);
      final loaded = await storage.load();
      expect(loaded.length, 2);
      expect(loaded[0].name, 'G');
      expect(loaded[1].positions, [0, 2, 2, 0, 0, 0]);
    });

    test('poškozená data vrátí prázdný seznam, ne pád', () async {
      SharedPreferences.setMockInitialValues(
        {ChordStorage.key: 'tohle-neni-json'},
      );
      final loaded = await ChordStorage().load();
      expect(loaded, isEmpty);
    });

    test('prázdné jméno se při loadu přeskočí', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ChordStorage().saveTo(prefs, [SavedChord('   ', [0, 0, 0, 0, 0, 0])]);
      final loaded = ChordStorage().loadFrom(prefs);
      expect(loaded, isEmpty);
    });
  });
}
