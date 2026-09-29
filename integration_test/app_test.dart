import 'package:enves/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Recorrido real en dispositivo o emulador:
/// flutter test integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding y entrada a la primera pregunta', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EnvesApp()));
    await tester.pumpAndSettle();
    if (find.text('Seguir').evaluate().isNotEmpty) {
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      final line = tester.getRect(find.byType(GestureDetector).first);
      await tester.tapAt(Offset(line.right - 30, line.center.dy));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar'));
      await tester.pumpAndSettle();
      expect(find.text('El mismo descuido'), findsWidgets);
    }
  });
}
