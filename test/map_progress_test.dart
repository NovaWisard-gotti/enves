import 'dart:convert';
import 'dart:io';

import 'package:enves/core/json.dart';
import 'package:enves/domain/records/records.dart';
import 'package:enves/engine/experience/experience_engine.dart';
import 'package:enves/engine/map/map_builder.dart';
import 'package:enves/engine/progress/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('el mapa vacío no inventa patrones', () async {
    final c = await loadContent();
    final m = const MapBuilder().build(c, UserState.empty());
    expect(m.isEmpty, isTrue);
    expect(m.threads, isEmpty);
    expect(m.axes.every((a) => !a.consolidated), isTrue);
  });

  test('con menos de tres decisiones el eje es provisional', () async {
    final c = await loadContent();
    final engine = ExperienceEngine(c, clock: fakeClock());
    final s = walk(engine, UserState.empty(), 'e1_mismo_descuido', stance: -2, reasonId: 'e1_r_decision');
    final axis = const MapBuilder().build(c, s).axes.firstWhere((a) => a.axis.id == 'ax_intencion_resultado');
    expect(axis.consolidated, isFalse);
    expect(axis.statement, contains('1 de 3'));
  });

  test('el perfil de demostración produce un mapa completo y separado', () async {
    final c = await loadContent();
    final demo = UserState.fromJson(asJson(jsonDecode(File('assets/demo/demo_profile.json').readAsStringSync())));
    expect(demo.experiences.values.where((p) => p.status == ExpStatus.completed).length, 9);
    final m = const MapBuilder().build(c, demo);
    expect(m.completedCount, 9);
    expect(m.hollows.length, 9);
    expect(m.openQuestions.length, 3);
    expect(m.threads, isNotEmpty);
    expect(m.axes.any((a) => a.consolidated), isTrue);
    expect(m.threads.length, lessThanOrEqualTo(MapBuilder.maxThreads));
  });

  test('siguiente pregunta, orden recomendado y eco', () async {
    final c = await loadContent();
    const svc = ProgressService();
    final engine = ExperienceEngine(c, clock: fakeClock());
    var s = UserState.empty();
    expect(svc.next(c, s).experience!.id, 'e1_mismo_descuido');
    expect(svc.isOutOfOrder(c, s, 'e5_cien_becas'), isTrue);
    s = engine.start(s, 'e2_promesa_sabado');
    expect(svc.next(c, s).isContinue, isTrue);
    s = engine.skip(s, 'e2_promesa_sabado');
    s = walk(engine, s, 'e1_mismo_descuido', stance: -2, reasonId: 'e1_r_decision');
    expect(svc.next(c, s).experience!.id, 'e3_lo_que_viste');
    expect(svc.echo(c, s), contains('«El mismo descuido»'));
    expect(svc.completedCount(s), 1);
  });
}
