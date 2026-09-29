import 'package:enves/domain/content/condition.dart';
import 'package:enves/engine/rules/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final facts = <String, Object?>{'a': 2, 'b': 'x', 'tags': ['p1', 'p2']};
  final ev = ConditionEvaluator((f) => facts[f]);

  test('hojas y combinaciones', () {
    expect(ev.eval(Condition.fromJson({'fact': 'a', 'op': 'gt', 'value': 1})), isTrue);
    expect(ev.eval(Condition.fromJson({'fact': 'a', 'op': 'lt', 'value': 1})), isFalse);
    expect(ev.eval(Condition.fromJson({'fact': 'b', 'op': 'in', 'value': ['x', 'y']})), isTrue);
    expect(ev.eval(Condition.fromJson({'fact': 'tags', 'op': 'containsAny', 'value': ['p2']})), isTrue);
    expect(
      ev.eval(Condition.fromJson({
        'all': [
          {'fact': 'a', 'op': 'eq', 'value': 2},
          {'not': {'fact': 'b', 'op': 'eq', 'value': 'z'}},
        ]
      })),
      isTrue,
    );
    expect(ev.eval(Condition.fromJson({})), isTrue);
  });

  test('un hecho inexistente nunca cumple una condición', () {
    expect(ev.eval(Condition.fromJson({'fact': 'nada', 'op': 'ne', 'value': 1})), isFalse);
    expect(ev.eval(Condition.fromJson({'fact': 'nada', 'op': 'notExists'})), isTrue);
  });

  test('la plantilla no se muestra si falta un valor', () {
    expect(TemplateRenderer.render('Elegiste «{razon}».', {'razon': 'X'}, (_) => null), 'Elegiste «X».');
    expect(TemplateRenderer.render('Elegiste «{razon}».', {}, (_) => null), isNull);
    expect(TemplateRenderer.render('Al {fact:p}%', {}, (f) => f == 'p' ? 60 : null), 'Al 60%');
  });
}
