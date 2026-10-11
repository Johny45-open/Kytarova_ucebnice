class ChordLogic {
  List<int> fingerPositions = List.filled(6, -1);
  static const List<String> stringNamesStatic = [
    'E tlusté',
    'A',
    'D',
    'G',
    'H',
    'e tenké',
  ];
  final List<String> stringNames = stringNamesStatic;
  final List<int> midiBaseNotes = [40, 45, 50, 55, 59, 64];

  void setBarre(int fret) {
    // Pokud jsou už všechny struny na tomto pražci, vypneme je (nastavíme na -1).
    // Jinak nastavíme všechny struny na tento pražec.
    bool allAlreadySet = fingerPositions.every((p) => p == fret);
    for (int i = 0; i < 6; i++) {
      fingerPositions[i] = allAlreadySet ? -1 : fret;
    }
  }

  void setPosition(int sIdx, int value) {
    fingerPositions[sIdx] = value;
  }

  String getChordDescription() {
    List<String> desc = [];
    for (int i = 0; i < 6; i++) {
      String pos;
      if (fingerPositions[i] == -1) {
        pos = 'nehraje, X';
      } else if (fingerPositions[i] == 0) {
        pos = 'prázdná struna, O';
      } else {
        pos = '${fingerPositions[i]}. pražec';
      }
      desc.add('${stringNames[i]}: $pos');
    }
    return desc.join('. ');
  }

  int? getMidiNote(int sIdx) {
    int fret = fingerPositions[sIdx];
    if (fret == -1) return null;
    return midiBaseNotes[sIdx] + fret;
  }

  /// Krátký jednorádkový popis vhodný jako subtitle v seznamu.
  static String describePositions(List<int> positions) {
    final parts = <String>[];
    for (int i = 0; i < 6 && i < positions.length; i++) {
      final p = positions[i];
      final short = stringNamesStatic[i].split(' ')[0];
      if (p == -1) {
        parts.add('$short:X');
      } else if (p == 0) {
        parts.add('$short:O');
      } else {
        parts.add('$short:$p');
      }
    }
    return parts.join(' ');
  }

  /// Plný popis pro čtečku (věty místo zkratek).
  static String fullDescription(List<int> positions) {
    final logic = ChordLogic();
    for (int i = 0; i < 6 && i < positions.length; i++) {
      logic.fingerPositions[i] = positions[i];
    }
    return logic.getChordDescription();
  }
}

/// Uložený akord s persistencí (JSON) a přístupným popisem.
class SavedChord {
  String name;
  final List<int> positions;
  SavedChord(this.name, List<int> pos) : positions = List.from(pos);

  Map<String, dynamic> toJson() => {'name': name, 'positions': List.of(positions)};

  factory SavedChord.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final raw = json['positions'] as List? ?? [];
    final pos = raw.map((e) => (e as num).toInt()).toList();
    // Vždy 6 strun; chybějící doplnit X (-1), přebytečné oříznout.
    while (pos.length < 6) {
      pos.add(-1);
    }
    return SavedChord(name, pos.sublist(0, 6));
  }

  /// Krátký popis hmatu pro subtitle.
  String get shortDescription => ChordLogic.describePositions(positions);

  /// Plný popis pro screen reader.
  String get fullDescription => ChordLogic.fullDescription(positions);
}
