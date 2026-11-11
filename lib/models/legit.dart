/// One sourced fact about a reference product. [value] may be a String, num or
/// List; a null field in the API means no public source exists.
class LegitField {
  const LegitField({this.value, this.source, this.accessed, this.regex});
  final Object? value;
  final String? source, accessed, regex;

  static LegitField? fromJsonOrNull(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    return LegitField(
      value: j['value'],
      source: j['source'] as String?,
      accessed: j['accessed'] as String?,
      regex: j['regex'] as String?,
    );
  }
}

class LegitReference {
  const LegitReference(
      {required this.id, required this.brand, required this.model, required this.fields});
  final String id, brand, model;
  final Map<String, LegitField?> fields;

  factory LegitReference.fromJson(Map<String, dynamic> j) => LegitReference(
        id: j['id'] as String,
        brand: j['brand'] as String,
        model: j['model'] as String,
        fields: ((j['fields'] ?? const {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, LegitField.fromJsonOrNull(v))),
      );
}

class LegitFieldResult {
  const LegitFieldResult(
      {required this.field, required this.label, this.expected, this.given, required this.result, this.note});
  final String field, label, result; // result: match | mod | mismatch | unknown
  final Object? expected, given;
  final String? note;

  factory LegitFieldResult.fromJson(Map<String, dynamic> j) => LegitFieldResult(
        field: j['field'] as String,
        label: j['label'] as String,
        expected: j['expected'],
        given: j['given'],
        result: j['result'] as String,
        note: j['note'] as String?,
      );
}

class LegitResult {
  const LegitResult({
    required this.referenceId,
    required this.verdict,
    required this.verdictLabel,
    required this.fields,
    this.labelPhotoUrl,
    this.pcbPhotoUrl,
    required this.disclaimer,
    this.checkedAt,
  });

  final String referenceId, verdict, verdictLabel, disclaimer; // verdict: match | mods | mismatch
  final List<LegitFieldResult> fields;
  final String? labelPhotoUrl, pcbPhotoUrl, checkedAt;

  factory LegitResult.fromJson(Map<String, dynamic> j) => LegitResult(
        referenceId: j['reference_id'] as String,
        verdict: j['verdict'] as String,
        verdictLabel: j['verdict_label'] as String,
        fields: ((j['fields'] ?? const []) as List)
            .map((e) => LegitFieldResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        labelPhotoUrl: j['label_photo_url'] as String?,
        pcbPhotoUrl: j['pcb_photo_url'] as String?,
        disclaimer: (j['disclaimer'] ?? '') as String,
        checkedAt: j['checked_at'] as String?,
      );
}
