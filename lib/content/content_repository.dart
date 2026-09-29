import 'dart:convert';

import '../core/json.dart';
import '../domain/content/content_models.dart';
import 'content_validator.dart';

/// Origen de los archivos de contenido (assets en la app, disco en pruebas).
abstract class ContentSource {
  Future<String> read(String path);
}

class ContentLoadFailure implements Exception {
  const ContentLoadFailure(this.message);
  final String message;
  @override
  String toString() => 'ContentLoadFailure: $message';
}

class ContentRepository {
  const ContentRepository();

  Future<Json> _json(ContentSource source, String path) async {
    final raw = await source.read(path);
    return asJson(jsonDecode(raw));
  }

  /// Carga todo el contenido. Un error en una experiencia la marca como no
  /// disponible; solo un catálogo ilegible impide cargar la app.
  Future<ContentBundle> load(ContentSource source) async {
    final Json catalog;
    try {
      catalog = await _json(source, 'catalog.json');
    } catch (e) {
      throw ContentLoadFailure('catálogo ilegible: $e');
    }
    final issues = <String>[];
    Future<Json> optional(String path) async {
      try {
        return await _json(source, path);
      } catch (e) {
        issues.add('$path: $e');
        return <String, dynamic>{};
      }
    }

    final axes = await optional('axes.json');
    final principles = await optional('principles.json');
    final distinctions = await optional('distinctions.json');
    final references = await optional('references.json');
    final common = await optional('cruza_common.json');

    final entries = asJsonList(catalog['experiences'])
        .map((e) => CatalogEntry(
              id: asString(e['id']),
              title: asString(e['title']),
              question: asString(e['question']),
              tramo: asInt(e['tramo'], 1),
              order: asInt(e['order']),
            ))
        .where((e) => e.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final experiences = <ExperienceDef>[];
    final unavailable = <String>{};
    for (final entry in entries) {
      try {
        final json = await _json(source, 'experiences/${entry.id}.json');
        experiences.add(ExperienceDef.fromJson(json));
      } catch (e) {
        issues.add('${entry.id}: $e');
        unavailable.add(entry.id);
      }
    }

    final bundle = ContentBundle(
      contentVersion: asString(catalog['contentVersion'], '1.0.0'),
      catalog: entries,
      tramos: asJsonList(catalog['tramos'])
          .map((t) => TramoDef(id: asInt(t['id']), title: asString(t['title'])))
          .toList(),
      experiences: experiences,
      axes: asJsonList(axes['axes'])
          .map((a) => AxisDef(id: asString(a['id']), left: asString(a['left']), right: asString(a['right'])))
          .toList(),
      principles: asJsonList(principles['principles'])
          .map((p) => PrincipleDef(id: asString(p['id']), label: asString(p['label'])))
          .toList(),
      distinctions: asJsonList(distinctions['distinctions']).map(DistinctionDef.fromJson).toList(),
      references: asJsonList(references['references']).map(ReferenceDef.fromJson).toList(),
      common: CruzaCommon.fromJson(common),
    );

    final report = const ContentValidator().validate(bundle);
    return ContentBundle(
      contentVersion: bundle.contentVersion,
      catalog: bundle.catalog,
      tramos: bundle.tramos,
      experiences: bundle.experiences,
      axes: bundle.axes,
      principles: bundle.principles,
      distinctions: bundle.distinctions,
      references: bundle.references,
      common: bundle.common,
      unavailable: {...unavailable, ...report.brokenExperiences},
      issues: [...issues, ...report.issues],
    );
  }
}
