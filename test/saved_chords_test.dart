import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kytarova_ucebnice/chord_logic.dart';
import 'package:kytarova_ucebnice/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    mySavedChords = [
      SavedChord('G', [3, 2, 0, 0, 0, 3]),
      SavedChord('Em', [0, 2, 2, 0, 0, 0]),
    ];
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Seznam ukáže hmat a přístupná tlačítka', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
    await tester.pumpAndSettle();

    // Jména + krátký popis hmatu.
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Em'), findsOneWidget);
    expect(find.textContaining('E:O'), findsWidgets);

    // Každý řádek má 4 akce s plným kontextem v tooltipu.
    expect(find.byTooltip('Přehrát akord G'), findsOneWidget);
    expect(find.byTooltip('Popsat hmat G'), findsOneWidget);
    expect(find.byTooltip('Přejmenovat akord G'), findsOneWidget);
    expect(find.byTooltip('Smazat akord G'), findsOneWidget);
  });

  testWidgets('Přejmenování: prázdný název hlásí chybu, dialog zůstane',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Přejmenovat akord G'));
    await tester.pumpAndSettle();
    expect(find.text('Přejmenovat akord G'), findsOneWidget);

    // Vymazat a potvrdit.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Přejmenovat'));
    await tester.pumpAndSettle();

    expect(find.text('Zadejte název akordu'), findsOneWidget);
    // Původní akord stále existuje, nic se nesmazalo.
    expect(find.text('Přejmenovat akord G'), findsOneWidget);
  });

  testWidgets('Přejmenování: duplicitní název hlásí chybu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Přejmenovat akord G'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Em');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Přejmenovat'));
    await tester.pumpAndSettle();

    expect(find.text('Tento název už existuje'), findsOneWidget);
  });

  testWidgets('Přejmenování: platný název projde + SnackBar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Přejmenovat akord G'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'G7');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Přejmenovat'));
    await tester.pumpAndSettle();

    expect(find.text('G7'), findsOneWidget);
    expect(find.text('Akord přejmenován na G7.'), findsOneWidget);
  });

  testWidgets('Smazání vyžaduje potvrzení', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Smazat akord Em'));
    await tester.pumpAndSettle();
    expect(find.text('Smazat Em?'), findsOneWidget);

    // Zrušit nechá akord na místě.
    await tester.tap(find.widgetWithText(TextButton, 'Zrušit'));
    await tester.pumpAndSettle();
    expect(find.text('Em'), findsOneWidget);

    // Potvrdit smaže + SnackBar.
    await tester.tap(find.byTooltip('Smazat akord Em'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Smazat'));
    await tester.pumpAndSettle();
    expect(find.text('Em'), findsNothing);
    expect(find.textContaining('smazán'), findsOneWidget);
  });

  testWidgets('Tap na řádek načte hmat do editoru', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SavedChordsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('G'));
    await tester.pumpAndSettle();

    // Editor se otevřel v režimu úpravy.
    expect(find.text('Úprava: G'), findsOneWidget);
  });

  testWidgets('Editor: uložení bez jména hlásí chybu', (tester) async {
    mySavedChords = [];
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Uložit'));
    await tester.pumpAndSettle();
    expect(find.text('Uložit akord'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Uložit'));
    await tester.pumpAndSettle();
    expect(find.text('Zadejte název akordu'), findsOneWidget);
    expect(mySavedChords, isEmpty);
  });

  testWidgets('Rozsah je live-region pro čtečku', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));
    await tester.pumpAndSettle();

    final live = find.ancestor(
      of: find.text('Rozsah: 1–7'),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
    );
    expect(live, findsOneWidget);
  });
}
