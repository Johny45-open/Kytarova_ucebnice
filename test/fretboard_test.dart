
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kytarova_ucebnice/main.dart';

void main() {
  testWidgets('Test zobrazení a chování puntíku', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChordEditorPage()));

    // Najít buňku pro strunu 0, pražec 1
    final finder = find.byType(Semantics).at(1); // 0. je asi název struny, 1. je pražec 1
    
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
}
