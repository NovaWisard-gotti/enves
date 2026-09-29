/// Lectura tolerante de JSON: un dato ausente o mal formado nunca provoca un
/// fallo global, sino un valor seguro por defecto.
typedef Json = Map<String, dynamic>;

Json asJson(Object? value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v));
  }
  return <String, dynamic>{};
}

Json? asJsonOrNull(Object? value) => value is Map ? asJson(value) : null;

List<Json> asJsonList(Object? value) {
  if (value is! List) return <Json>[];
  return value.whereType<Map>().map(asJson).toList();
}

List<String> asStringList(Object? value) {
  if (value is! List) return <String>[];
  return value.where((e) => e != null).map((e) => e.toString()).toList();
}

String asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

String? asStringOrNull(Object? value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

DateTime? asDate(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String? dateToJson(DateTime? value) => value?.toIso8601String();

Map<String, int> asIntMap(Object? value) {
  final m = asJson(value);
  final out = <String, int>{};
  m.forEach((k, v) {
    final i = asIntOrNull(v);
    if (i != null) out[k] = i;
  });
  return out;
}

Map<String, String> asStringMap(Object? value) {
  final m = asJson(value);
  final out = <String, String>{};
  m.forEach((k, v) {
    if (v != null) out[k] = v.toString();
  });
  return out;
}
