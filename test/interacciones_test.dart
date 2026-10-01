import 'dart:convert';
import 'dart:io';

import 'package:enves/app/providers.dart';
import 'package:enves/core/json.dart';
import 'package:enves/domain/content/content_models.dart';
import 'package:enves/domain/records/prefs.dart';
import 'package:enves/domain/records/records.dart';
import 'package:enves/engine/experience/experience_engine.dart';
import 'package:enves/features/experience/probes/probes.dart';
import 'package:enves/features/experience/stages/cruza_anchor.dart';
import 'package:enves/features/experience/widgets/memoria_regresa.dart';
import 'package:enves/features/home/home_screen.dart';
import 'package:enves/features/map/map_screen.dart';
import 'package:enves/theme/app_theme.dart';
import 'package:enves/widgets/margen_vivo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _FixedUser extends UserStateController {
  _FixedUser(this.s);
  final UserState s;
  @override
  Future<UserState> build() async => s;
}

UserState demoProfile() =>
    UserState.fromJson(asJson(jsonDecode(File('assets/demo/demo_profile.json').readAsStringSync())));

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  required ContentBundle content,
  UserState? user,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool reduced = false,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      contentProvider.overrideWith((ref) async => content),
      userStateProvider.overrideWith(() => _FixedUser(user ?? UserState.empty())),
      currentPrefsProvider.overrideWithValue(Prefs(motion: reduced ? 'reduced' : 'system')),
    ],
    child: MaterialApp(
      theme: buildTheme(brightness),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: child)),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final f = find.bySemanticsLabel(label);
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> tapDone(WidgetTester tester) async {
  final f = find.byKey(const ValueKey('probe_done'));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  late ContentBundle c;
  setUp(() async => c = await loadContent());

  ProbeDef probeOf(String exp) => c.byId[exp]!.probes.first;

  testWidgets('E1: la escena se compara y el reproche se marca con tinta', (tester) async {
    Json? result;
    await pumpApp(
      tester,
      ProbeView(experienceId: 'e1_mismo_descuido', probe: probeOf('e1_mismo_descuido'), onDone: (r) => result = r),
      content: c,
    );
    expect(find.text('La conducta es la misma.'), findsOneWidget);
    await tapLabel(tester, 'Ver la escena de Beto');
    expect(find.textContaining('un niño cruza'), findsOneWidget);
    await tapLabel(tester, 'Reproche a Ana: Poco');
    await tapLabel(tester, 'Reproche a Beto: Bastante');
    await tapDone(tester);
    expect(result, {'ana': 1, 'beto': 3, 'diff': 2});
  });

  testWidgets('E2: en la variante secreta la promesa sigue dibujada', (tester) async {
    Json? result;
    final probe = c.byId['e2_promesa_sabado']!.probes.first;
    await pumpApp(tester, ProbeView(experienceId: 'e2_promesa_sabado', probe: probe, onDone: (r) => result = r), content: c);
    expect(find.textContaining('La promesa sigue dibujada'), findsOneWidget);
    await tapLabel(tester, 'Tu hermana: qué depende de ti');
    expect(find.textContaining('Qué depende de ti'), findsOneWidget);
    await tester.tap(find.text('Sigue estando mal: falté a mi palabra'));
    await tester.pumpAndSettle();
    await tapDone(tester);
    expect(result, {'choice': 'falle'});
  });

  testWidgets('E3: la situación se mueve entre círculos de cercanía', (tester) async {
    Json? result;
    final engine = ExperienceEngine(c, clock: fakeClock());
    var s = engine.start(UserState.empty(), 'e3_lo_que_viste');
    s = engine.submitJudgment(s, 'e3_lo_que_viste', -2);
    final probe = c.byId['e3_lo_que_viste']!.probes.first;
    await pumpApp(tester, ProbeView(experienceId: 'e3_lo_que_viste', probe: probe, onDone: (r) => result = r), content: c, user: s);
    await tester.tap(find.text('Callaría').first);
    await tester.pumpAndSettle();
    // Tras responder, pasa sola al siguiente círculo.
    expect(find.text('Si hubiera sido un desconocido:'), findsOneWidget);
    await tester.tap(find.text('Se lo contaría al dueño').first);
    await tester.pumpAndSettle();
    await tapDone(tester);
    expect(result, {'companero': -1, 'desconocido': 1});
  });

  testWidgets('E4: la línea se traza en un peldaño y se mueve con accesibilidad', (tester) async {
    Json? result;
    final probe = c.byId['e4_verdad_incomoda']!.probes.first;
    await pumpApp(tester, ProbeView(experienceId: 'e4_verdad_incomoda', probe: probe, onDone: (r) => result = r), content: c);
    final rung = find.bySemanticsLabel(RegExp(r'^Peldaño 2:'));
    await tester.ensureVisible(rung);
    await tester.tap(rung);
    await tester.pumpAndSettle();
    expect(find.text('Aquí trazaría mi línea'), findsOneWidget);
    final slider = tester.widget<Semantics>(find.ancestor(
      of: find.text('Aquí trazaría mi línea'),
      matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.slider == true),
    ));
    slider.properties.onIncrease!();
    await tester.pumpAndSettle();
    await tapDone(tester);
    expect(result, {'line': 3});
  });

  testWidgets('E5: las becas se mueven y se revela la imposibilidad', (tester) async {
    Json? result;
    await pumpApp(
      tester,
      ProbeView(experienceId: 'e5_cien_becas', probe: probeOf('e5_cien_becas'), onDone: (r) => result = r),
      content: c,
      size: const Size(420, 2200),
    );
    expect(find.text('El problema no eres tú.'), findsNothing);
    final sliders = find.byType(Slider);
    for (var i = 0; i < 9; i++) {
      final box = tester.getRect(sliders.at(i.isEven ? 0 : 1));
      await tester.tapAt(Offset(box.left + 24 + (i * 37 % 200), box.center.dy));
      await tester.pumpAndSettle();
    }
    expect(find.text('El problema no eres tú.'), findsOneWidget);
    expect(find.text('No existe una combinación que cumpla ambos criterios en estas condiciones.'), findsOneWidget);
    await tapDone(tester);
    expect(result!.keys, containsAll(['attempts', 'north', 'south', 'reachedI1', 'reachedI2', 'bothEver']));
    expect(result!['bothEver'], isFalse);
  });

  testWidgets('E6: tocar un nodo conecta la ubicación con el modo elegido', (tester) async {
    Json? result;
    await pumpApp(
      tester,
      ProbeView(experienceId: 'e6_donde_estas', probe: probeOf('e6_donde_estas'), onDone: (r) => result = r),
      content: c,
    );
    await tapLabel(tester, 'Sus padres, Siempre');
    await tapLabel(tester, 'Modo: Solo en emergencias');
    await tapLabel(tester, 'Sus amigos, Solo en emergencias');
    expect(find.text('Marcaste 2 de 12 conexiones.'), findsOneWidget);
    await tapDone(tester);
    expect(result!['accepted'], 2);
    expect(result!['cells'], ['0:0', '2:2']);
  });

  testWidgets('E7: marcar, revelar y volver a mirar una frase', (tester) async {
    Json? result;
    await pumpApp(
      tester,
      ProbeView(experienceId: 'e7_la_carta', probe: probeOf('e7_la_carta'), onDone: (r) => result = r),
      content: c,
    );
    await tester.ensureVisible(find.text('Aquí estoy.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aquí estoy.'));
    await tester.pumpAndSettle();
    await tapDone(tester);
    expect(find.textContaining('sistema automático'), findsOneWidget);
    await tester.ensureVisible(find.text('Aquí estoy.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aquí estoy.'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cambió lo que estas palabras significan para ti?'), findsOneWidget);
    await tapDone(tester);
    expect(result, {'marked': 1, 'revealed': true});
  });

  testWidgets('E8: la figura se vuelve a dibujar y el resultado no cambia', (tester) async {
    Json? result;
    await pumpApp(
      tester,
      ProbeView(experienceId: 'e8_la_copia', probe: probeOf('e8_la_copia'), onDone: (r) => result = r),
      content: c,
    );
    final slider = find.byType(Slider);
    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.right - 24, box.center.dy));
    await tester.pumpAndSettle();
    expect(find.textContaining('La figura está completa'), findsOneWidget);
    await tapDone(tester);
    expect(result, {'stop': 100});
  });

  testWidgets('E9: el recorrido final reúne las posiciones reconstruidas', (tester) async {
    Json? result;
    final probe = c.byId['e9_sin_haberlo_vivido']!.probes.first;
    await pumpApp(
      tester,
      ProbeView(experienceId: 'e9_sin_haberlo_vivido', probe: probe, onDone: (r) => result = r),
      content: c,
      user: demoProfile(),
      size: const Size(420, 6000),
    );
    final options = find.text('Por qué lo piensan');
    final n = options.evaluate().length;
    expect(n, greaterThan(0));
    for (var i = 0; i < n; i++) {
      await tester.tap(options.at(i));
      await tester.pumpAndSettle();
    }
    await tapDone(tester);
    expect(result!['items'], n);
    expect(result!['porque'], n);
  });

  testWidgets('CRUZA: se cruza con el botón y la hoja cambia de cara', (tester) async {
    final engine = ExperienceEngine(c, clock: fakeClock());
    final s = walkUntil(engine, 'e1_mismo_descuido', Stage.cruzaAnchor);
    final exp = c.byId['e1_mismo_descuido']!;
    await pumpApp(
      tester,
      SizedBox(height: 800, child: CruzaAnchorStage(exp: exp, progress: s.progress(exp.id))),
      content: c,
      user: s,
    );
    expect(find.text('Entrar al taller'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('anchor_cross')));
    await tester.pumpAndSettle();
    expect(find.text('Desde aquí, ¿cómo se ve?'), findsOneWidget);
    expect(find.textContaining('A trasluz'), findsOneWidget);
    expect(find.byKey(const ValueKey('anchor_done')), findsOneWidget);
  });

  testWidgets('Tu respuesta regresa: la cita muestra dónde, cuándo y con qué postura', (tester) async {
    final engine = ExperienceEngine(c, clock: fakeClock());
    final s = walk(engine, UserState.empty(), 'e1_mismo_descuido', stance: -2, reasonId: 'e1_r_decision');
    final p = s.progress('e1_mismo_descuido');
    final ref = RecordRef(experienceId: 'e1_mismo_descuido', field: 'reason', at: p.reason!.at, quote: p.reason!.text);
    await pumpApp(tester, MemoriaRegresa(pregunta: '¿Y ahora?', refs: [ref]), content: c, user: s);
    expect(find.text('«${p.reason!.text}»'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('memory_note')));
    await tester.pumpAndSettle();
    expect(find.textContaining('El mismo descuido'), findsWidgets);
    expect(find.textContaining('Tu postura entonces'), findsOneWidget);
  });

  testWidgets('Ver el envés tiene alternativa accesible al gesto', (tester) async {
    await pumpApp(
      tester,
      const VerElEnves(titulo: 'La objeción', texto: 'Del otro lado', child: Text('Derecho')),
      content: c,
    );
    expect(find.text('Derecho'), findsOneWidget);
    await tapLabel(tester, 'Ver el envés: La objeción');
    expect(find.text('Del otro lado'), findsOneWidget);
    await tapLabel(tester, 'Volver al derecho');
    expect(find.text('Derecho'), findsOneWidget);
  });

  testWidgets('El mapa: tocar un hilo destaca las experiencias que lo construyeron', (tester) async {
    await pumpApp(
      tester,
      SizedBox(height: 4000, child: MapScreen(demo: false)),
      content: c,
      user: demoProfile(),
      size: const Size(420, 4200),
    );
    expect(find.text('Este hilo existe por:'), findsNothing);
    final hilo = find.bySemanticsLabel(RegExp(r'(volvió en|comparten una razón)'));
    await tester.tap(hilo.first);
    await tester.pumpAndSettle();
    expect(find.text('Este hilo existe por:'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('inicio y sondas sin desbordes a texto 200 % (${dark ? 'oscuro' : 'claro'})', (tester) async {
      final demo = demoProfile();
      await pumpApp(
        tester,
        const SizedBox(height: 2400, child: HomeScreen()),
        content: c,
        user: demo,
        brightness: dark ? Brightness.dark : Brightness.light,
        textScale: 2,
        size: const Size(360, 2600),
      );
      final hx = tester.takeException();
      expect(hx, isNull, reason: 'inicio: ${hx is FlutterError ? hx.toStringDeep() : hx}');
      for (final e in c.experiences) {
        for (final p in e.probes) {
          await pumpApp(
            tester,
            ProbeView(experienceId: e.id, probe: p, onDone: (_) {}),
            content: c,
            user: demo,
            brightness: dark ? Brightness.dark : Brightness.light,
            textScale: 2,
            reduced: dark,
            size: const Size(360, 6000),
          );
          final ex = tester.takeException();
          expect(ex, isNull, reason: '${e.id}: ${ex is FlutterError ? ex.toStringDeep() : ex}');
        }
      }
    });
  }
}

/// Avanza una experiencia hasta la etapa pedida con decisiones por defecto.
UserState walkUntil(ExperienceEngine engine, String id, String stage) {
  final exp = engine.content.byId[id]!;
  var s = engine.start(UserState.empty(), id);
  for (var i = 0; i < 40; i++) {
    final p = s.progress(id);
    if (p.stage == stage) return s;
    switch (p.stage) {
      case Stage.probe:
        s = engine.submitProbe(s, id, exp.eligeProbe!.id, defaultProbeResult(exp.eligeProbe!));
      case Stage.judgment:
        s = engine.submitJudgment(s, id, -2);
      case Stage.reason:
        s = engine.submitReason(s, id, exp.reasons.first.id);
      case Stage.question:
        final q = p.active!;
        final answer = q.kind == QuestionKind.tension
            ? 'mantener'
            : (q.kind == QuestionKind.assumption ? 'si' : exp.questionById(q.questionId)!.answers.first.id);
        s = engine.answerQuestion(s, id, answer);
      case Stage.implication:
        s = engine.answerImplication(s, id, true);
      case Stage.fundamento:
      case Stage.discovery:
        s = engine.continueToCruza(s, id);
      case Stage.cruzaSide:
        s = engine.chooseCruzaSide(s, id, 'left');
      default:
        throw StateError('Etapa inesperada ${p.stage}');
    }
  }
  throw StateError('No se llegó a $stage');
}
