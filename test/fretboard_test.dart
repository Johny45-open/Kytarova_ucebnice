
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kytarova_ucebnice/main.dart';

void main() {
  testWidgets('Test zobrazení a chování puntíku', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));

    // Buňka pro strunu 0, pražec 1 je standardní OutlinedButton.
    final finder = find.widgetWithText(OutlinedButton, '1').first;
    
    // Před kliknutím by neměl být puntík
    expect(find.byType(Container), isNot(find.byWidgetPredicate((widget) => widget is Container && widget.decoration is BoxDecoration)));

    // Kliknout
    await tester.tap(finder);
    await tester.pump();

    // Po kliknutí by měl být puntík
    // Hledáme Container s BoxDecoration (puntík)
    expect(find.byWidgetPredicate((widget) => widget is Container && widget.decoration != null && (widget.decoration as BoxDecoration).shape == BoxShape.circle), findsOneWidget);

    // Kliknout znovu pro zrušení
    await tester.tap(finder);
    await tester.pump();

    // Puntík by měl zmizet
    expect(find.byWidgetPredicate((widget) => widget is Container && widget.decoration != null && (widget.decoration as BoxDecoration).shape == BoxShape.circle), findsNothing);
  });

  testWidgets('G dur hmatem D dur (5, 7, 8, 7) je v jednom výřezu 1–7 po posunu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));

    // Výchozí výřez 1–7
    expect(find.text('Rozsah: 1–7'), findsOneWidget);

    // Posun o 4 pražce na začátek 5
    for (int i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Další pražec'));
      await tester.pump();
    }
    expect(find.text('Rozsah: 5–11'), findsOneWidget);

    // Všechny pražce hmatu G dur (D tvar) jsou vidět najednou
    for (final fret in [5, 7, 8]) {
      expect(find.text('$fret'), findsWidgets);
    }
  });

  testWidgets('Stav struny (X/O) jde zvolit klávesnicí v dialogu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));

    // Otevřít dialog stavu první struny (E tlusté, výchozí stav X).
    await tester.tap(find.widgetWithText(TextButton, 'E (X)'));
    await tester.pumpAndSettle();
    expect(find.text('Struna E tlusté'), findsOneWidget);

    final xRadio = find.widgetWithText(RadioListTile<int>, 'X – nehrát');
    final oRadio = find.widgetWithText(
      RadioListTile<int>,
      'O – prázdná struna',
    );
    expect(xRadio, findsOneWidget);
    expect(oRadio, findsOneWidget);
    // X je výchozí stav → skupina hlásí -1.
    expect(
      tester
          .widget<RadioGroup<int>>(find.byType(RadioGroup<int>))
          .groupValue,
      -1,
    );

    // Tabem dojít do skupiny (skočí na zaškrtnuté X – standardní
    // chování radioskupiny), šipkou dolů na O, zvolit Mezerníkem.
    bool focusedOn(Finder f) {
      final target = tester.element(f);
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx == null) return false;
      if (ctx == target) return true;
      bool hit = false;
      ctx.visitAncestorElements((e) {
        if (e == target) hit = true;
        return true;
      });
      return hit;
    }

    bool reached = false;
    for (int i = 0; i < 20 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      reached = focusedOn(xRadio);
    }
    expect(reached, isTrue, reason: 'Na skupinu X/O se nelze dostat Tabem');

    // Šipka ve skupině rovnou i vybírá: dialog se zavře s volbou O.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('Struna E tlusté'), findsNothing);
    expect(find.widgetWithText(TextButton, 'E (O)'), findsOneWidget);
  });

  testWidgets('Pražec jde ovládat klávesnicí (fokus + Mezerník, bez myši)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));

    // Pražce jsou OutlinedButton – nativně v Tab pořadí (holý InkWell
    // by Tab přeskočil).
    final fretBtn = find.widgetWithText(OutlinedButton, '1').first;
    expect(fretBtn, findsOneWidget);

    Finder dot() => find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration != null &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    expect(dot(), findsNothing);

    // Fokusovat tlačítko čistě klávesnicí: Tab od startu, dokud fokus
    // nespočine uvnitř této buňky (anebo do limitu).
    final target = tester.element(fretBtn);
    bool focusedOnTarget() {
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx == null) return false;
      if (ctx == target) return true;
      bool hit = false;
      ctx.visitAncestorElements((e) {
        if (e == target) hit = true;
        return true;
      });
      return hit;
    }

    bool reached = false;
    for (int i = 0; i < 120 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      reached = focusedOnTarget();
    }
    expect(reached, isTrue, reason: 'Na pražec se nelze dostat Tabem');

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(dot(), findsOneWidget);

    // A znovu Mezerníkem vypnout.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(dot(), findsNothing);
  });

  testWidgets('Řádky jdou shora od nejtenčí struny (tabulatura)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));

    // Vizuální pořadí tlačítek stavu: e, H, G, D, A, E.
    final statusButtons = tester
        .widgetList<TextButton>(find.byType(TextButton))
        .map((b) => (b.child as Text).data!)
        .toList();
    expect(statusButtons, [
      'e (X)',
      'H (X)',
      'G (X)',
      'D (X)',
      'A (X)',
      'E (X)',
    ]);

    // Mapování sedí: pražec v prvním řádku patří tenké e (index 5).
    Finder fretBtn(String label) => find.ancestor(
      of: find.byWidgetPredicate(
        (w) => w is Text && w.semanticsLabel == label,
      ),
      matching: find.byType(OutlinedButton),
    );
    expect(
      fretBtn('Struna e tenké, pražec 1, nevybráno'),
      findsOneWidget,
    );
    await tester.tap(
      fretBtn('Struna e tenké, pražec 1, nevybráno'),
    );
    await tester.pump();
    expect(
      fretBtn('Struna e tenké, pražec 1, vybráno'),
      findsOneWidget,
    );
  });
}
