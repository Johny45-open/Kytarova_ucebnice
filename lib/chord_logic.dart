class ChordLogic {
  List<int> fingerPositions = List.filled(6, -1);
  final List<String> stringNames = ['E tlusté', 'A', 'D', 'G', 'H', 'e tenké'];
  final List<int> midiBaseNotes = [40, 45, 50, 55, 59, 64];

  void setBarre(int fret) {
    bool allSet = fingerPositions.every((p) => p == fret);
    for (int i = 0; i < 6; i++) {
      fingerPositions[i] = allSet ? -1 : fret;
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
}
