import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kytarova_ucebnice/chord_logic.dart';
import 'package:kytarova_ucebnice/main.dart';
import 'package:kytarova_ucebnice/services/chord_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    myChordFolders = [
      ChordFolder(id: 'rock', name: 'Rock'),
    ];
    mySavedChords = [
      SavedChord('G', [3, 2, 0, 0, 0, 3], folderId: 'rock'),
      SavedChord('Em', [0, 2, 2, 0, 0, 0]),
    ];
    SharedPreferences.setMockInitialValues({});
  });

  group('Model a storage', () {
    test('SavedChord s folderId projde JSON roundtripem', () {
      final c = SavedChord('G', [3, 2, 0, 0, 0, 3], folderId: 'rock');
      final back = SavedChord.fromJson(c.toJson());
      expect(back.folderId, 'rock');
      expect(back.name, 'G');
    });

    test('ChordFolder projde JSON roundtripem', () {
      final f = ChordFolder(id: 'a', name: 'Rock');
      final back = ChordFolder.fromJson(f.toJson());
      expect(back.id, 'a');
      expect(back.name, 'Rock');
    });

    test('loadLibrary migruje v1 data bez složek', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ChordStorage().saveTo(
        prefs,
        [SavedChord('G', [3, 2, 0, 0, 0, 3])],
      );
      final library = ChordStorage().loadLibraryFrom(prefs);
      expect(library.folders, isEmpty);
      expect(library.chords.length, 1);
      expect(library.chords.first.folderId, isNull);
    });

    test('saveLibrary + loadLibrary roundtrip se složkami', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ChordStorage().saveLibraryTo(
        prefs,
        ChordLibrary(
          folders: [ChordFolder(id: 'rock', name: 'Rock')],
          chords: [SavedChord('G', [3, 2, 0, 0, 0, 3], folderId: 'rock')],
        ),
      );
      final back = ChordStorage().loadLibraryFrom(prefs);
      expect(back.folders.length, 1);
      expect(back.chords.first.folderId, 'rock');
    });

    test('sirotčí folderId se při loadu vynuluje', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ChordStorage().saveLibraryTo(
        prefs,
        ChordLibrary(
          folders: [],
          chords: [SavedChord('G', [3, 2, 0, 0, 0, 3], folderId: 'ghost')],
        ),
      );
      final back = ChordStorage().loadLibraryFrom(prefs);
      expect(back.chords.first.folderId, isNull);
    });
  });

  group('UI složek', () {
    testWidgets('Seznam ukáže složku s počtem + Bez složky', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Rock'), findsOneWidget);
      expect(find.text('1 akord'), findsOneWidget);
      // G je ve složce, v Bez složky je jen Em.
      expect(find.text('Em'), findsOneWidget);
      expect(find.byTooltip('Vytvořit složku'), findsOneWidget);
      expect(find.byTooltip('Přejmenovat složku Rock'), findsOneWidget);
      expect(find.byTooltip('Smazat složku Rock'), findsOneWidget);
    });

    testWidgets('Nová složka: prázdný název hlásí chybu', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Vytvořit složku'));
      await tester.pumpAndSettle();
      expect(find.text('Nová složka'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vytvořit'));
      await tester.pumpAndSettle();
      expect(find.text('Zadejte název složky'), findsOneWidget);
      expect(myChordFolders.length, 1);
    });

    testWidgets('Nová složka: platný název + SnackBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Vytvořit složku'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Blues');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vytvořit'));
      await tester.pumpAndSettle();

      expect(find.text('Blues'), findsOneWidget);
      expect(find.text('Složka Blues vytvořena.'), findsOneWidget);
    });

    testWidgets('Smazání složky nechá akordy v Bez složky', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Smazat složku Rock'));
      await tester.pumpAndSettle();
      expect(find.text('Smazat složku Rock?'), findsOneWidget);
      expect(find.textContaining('zůstanou v Bez složky'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Smazat'));
      await tester.pumpAndSettle();

      expect(find.text('Rock'), findsNothing);
      // G spadlo do Bez složky, Em tam bylo.
      expect(find.text('G'), findsOneWidget);
      expect(find.text('Em'), findsOneWidget);
      expect(
        find.text('Složka Rock smazána. Akordy zůstaly v Bez složky.'),
        findsOneWidget,
      );
    });

    testWidgets('Přesun akordu do složky přes radiodialog', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Přesunout akord Em do složky'));
      await tester.pumpAndSettle();
      expect(find.text('Přesunout akord Em do složky'), findsOneWidget);
      expect(find.text('Bez složky'), findsWidgets);
      expect(find.text('Rock'), findsWidgets);

      await tester.tap(find.widgetWithText(RadioListTile<String>, 'Rock'));
      await tester.pumpAndSettle();

      expect(find.text('Akord Em přesunut do Rock.'), findsOneWidget);
      expect(mySavedChords.firstWhere((c) => c.name == 'Em').folderId, 'rock');
    });

    testWidgets('Detail složky ukáže jen její akordy', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rock'));
      await tester.pumpAndSettle();

      expect(find.text('G'), findsOneWidget);
      expect(find.text('Em'), findsNothing);
      expect(
        find.byTooltip('Nový akord do složky Rock'),
        findsOneWidget,
      );
    });
  });

  group('Uložení z editoru ukazuje složku', () {
    testWidgets('Editor ze složky: dialog i hláška nesou její jméno', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ChordEditorPage(folderId: 'rock')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Uložit'));
      await tester.pumpAndSettle();
      expect(find.text('Uložit akord'), findsOneWidget);
      expect(find.text('Uloží se do: Rock'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Uložit'));
      await tester.pumpAndSettle();

      expect(
        find.text('Akord A byl uložen do Rock.'),
        findsOneWidget,
      );
      expect(
        mySavedChords.firstWhere((c) => c.name == 'A').folderId,
        'rock',
      );
    });

    testWidgets('Generický editor: ukládá do Bez složky', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Uložit'));
      await tester.pumpAndSettle();
      expect(find.text('Uloží se do: Bez složky'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'D');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Uložit'));
      await tester.pumpAndSettle();

      expect(
        find.text('Akord D byl uložen do Bez složky.'),
        findsOneWidget,
      );
      expect(
        mySavedChords.firstWhere((c) => c.name == 'D').folderId,
        isNull,
      );
    });
  });
}
