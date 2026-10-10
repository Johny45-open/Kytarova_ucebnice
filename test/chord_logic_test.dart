import 'package:flutter_test/flutter_test.dart';
import 'package:kytarova_ucebnice/chord_logic.dart';

void main() {
  group('ChordLogic Tests', () {
    test('setBarre sets all strings', () {
      final logic = ChordLogic();
      logic.setBarre(3);
      for (int i = 0; i < 6; i++) {
        expect(logic.fingerPositions[i], 3);
      }
    });

    test('setPosition changes one string', () {
      final logic = ChordLogic();
      logic.setPosition(0, 5);
      expect(logic.fingerPositions[0], 5);
      expect(logic.fingerPositions[1], -1);
    });

    test('getChordDescription returns correct string', () {
      final logic = ChordLogic();
      logic.setPosition(0, -1);
      logic.setPosition(1, 0);
      logic.setPosition(2, 3);
      expect(logic.getChordDescription(), contains('E tlusté: nehraje, X'));
      expect(logic.getChordDescription(), contains('A: prázdná struna, O'));
      expect(logic.getChordDescription(), contains('D: 3. pražec'));
    });
  });
}
