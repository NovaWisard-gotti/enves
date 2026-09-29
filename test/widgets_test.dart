import 'package:enves/theme/app_theme.dart';
import 'package:enves/widgets/balanza.dart';
import 'package:enves/widgets/tension_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: child))),
    );

void main() {
  testWidgets('la balanza se usa con toques y con acciones de accesibilidad', (tester) async {
    int? value;
    await tester.pumpWidget(wrap(StatefulBuilder(
      builder: (context, setState) => Balanza(
        leftLabel: 'Izquierda',
        rightLabel: 'Derecha',
        value: value,
        prompt: '¿Qué piensas?',
        onChanged: (v) => setState(() => value = v),
      ),
    )));
    final line = find.descendant(of: find.byType(Balanza), matching: find.byType(GestureDetector));
    final box = tester.getRect(line.first);
    await tester.tapAt(Offset(box.right - 26, box.center.dy));
    await tester.pump();
    expect(value, 3);
    await tester.tapAt(box.center);
    await tester.pump();
    expect(value, 0);
    final slider = tester.widget<Semantics>(
      find.descendant(of: find.byType(Balanza), matching: find.byType(Semantics)).first,
    );
    expect(slider.properties.slider, isTrue);
    slider.properties.onIncrease!();
    await tester.pump();
    expect(value, 1);
    expect(find.textContaining('Derecha'), findsWidgets);
  });

  testWidgets('Mantener, Matizar y Revisar tienen el mismo tamaño', (tester) async {
    String? chosen;
    await tester.pumpWidget(wrap(TensionButtons(onSelected: (id) => chosen = id)));
    final sizes = ['mantener', 'matizar', 'revisar']
        .map((id) => tester.getSize(find.byKey(ValueKey('tension_$id'))))
        .toList();
    expect(sizes[0], sizes[1]);
    expect(sizes[1], sizes[2]);
    await tester.tap(find.byKey(const ValueKey('tension_revisar')));
    expect(chosen, 'revisar');
    expect(find.text('Esta pregunta no aplica'), findsOneWidget);
  });

  testWidgets('el descubrimiento muestra primero las palabras del usuario', (tester) async {
    await tester.pumpWidget(wrap(const DiscoveryNote(
      userWords: 'Beto puede reparar el daño',
      openingLine: 'Otras personas también pensaron en esta diferencia.',
      everydayName: 'Reprochar no es lo mismo que reparar',
      explanation: 'Explicación',
      relation: 'la suerte moral',
      isOwn: false,
      doubtful: false,
    )));
    final words = tester.getTopLeft(find.byKey(const ValueKey('discovery_words')));
    final name = tester.getTopLeft(find.byKey(const ValueKey('discovery_name')));
    expect(words.dy, lessThan(name.dy));
  });
}
