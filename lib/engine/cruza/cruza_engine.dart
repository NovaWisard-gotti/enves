import '../../domain/content/content_models.dart';
import '../../domain/records/records.dart';

class RecognitionResult {
  const RecognitionResult(this.state, this.missing);
  final String state;
  final List<String> missing;
}

/// Hash FNV-1a estable entre plataformas y versiones.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

class CruzaEngine {
  const CruzaEngine();

  static const slots = ['S1', 'S2', 'S3', 'S4'];

  /// Pieza de S4 para esta persona: la respuesta a su razón si existe para el
  /// lado reconstruido; si no, la respuesta genérica.
  PieceDef? responsePiece(CruzaSideDef side, String? userReasonId) {
    if (userReasonId != null) {
      for (final p in side.pieces) {
        if (p.isValid && p.slots.contains('S4') && p.respondsTo.contains(userReasonId)) return p;
      }
    }
    for (final p in side.pieces) {
      if (p.generic) return p;
    }
    return null;
  }

  /// Nueve piezas en orden determinista: 2 de S1, 2 de S2, 1 de S3, 1 de S4,
  /// 2 caricaturas y 1 pieza del propio lado.
  List<String> composeTable(ExperienceDef exp, String side, String? userReasonId) {
    final s = exp.cruzaSide(side);
    List<PieceDef> validFor(String slot) =>
        s.pieces.where((p) => p.isValid && p.slots.contains(slot) && !p.slots.contains('S4')).toList();
    final chosen = <PieceDef>[
      ...validFor('S1').take(2),
      ...validFor('S2').take(2),
      ...validFor('S3').take(1),
    ];
    final resp = responsePiece(s, userReasonId);
    if (resp != null) chosen.add(resp);
    final seed = stableHash('${exp.id}/$side');
    final caricatures = s.pieces.where((p) => p.isCaricature).toList();
    if (caricatures.length > 2) {
      caricatures.removeAt(seed % caricatures.length);
    }
    chosen.addAll(caricatures.take(2));
    chosen.addAll(s.pieces.where((p) => p.isOwnSide).take(1));

    // Mezcla determinista (generador congruencial lineal propio).
    final ids = chosen.map((p) => p.id).toList();
    var x = seed == 0 ? 1 : seed;
    for (var i = ids.length - 1; i > 0; i--) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      final j = x % (i + 1);
      final tmp = ids[i];
      ids[i] = ids[j];
      ids[j] = tmp;
    }
    return ids;
  }

  /// Evaluación pura del argumento reconstruido.
  RecognitionResult evaluate(CruzaSideDef side, Map<String, String> placement) {
    final missing = <String>[];
    var filled = 0;
    var ownSide = false;
    var mismatch = false;
    for (final slot in slots) {
      final id = placement[slot];
      if (id == null) {
        missing.add(slot);
        continue;
      }
      final p = side.piece(id);
      if (p == null) {
        missing.add(slot);
        continue;
      }
      filled++;
      if (p.isOwnSide || p.isCaricature) {
        ownSide = true;
      } else if (!p.slots.contains(slot)) {
        mismatch = true;
      }
    }
    if (ownSide || filled < 2) return RecognitionResult(Recognition.noRepresenta, missing);
    final core = missing.where((s) => s != 'S4').toList();
    if (mismatch || core.isNotEmpty) return RecognitionResult(Recognition.parcial, missing);
    if (missing.contains('S4')) return RecognitionResult(Recognition.reconocible, missing);
    return RecognitionResult(Recognition.fuerte, missing);
  }

  /// Se puede enviar con al menos dos ranuras ocupadas, una de ellas S3.
  bool canSubmit(Map<String, String> placement) => placement.length >= 2 && placement.containsKey('S3');
}
