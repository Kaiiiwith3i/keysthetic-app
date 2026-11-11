import 'listing.dart';

/// Slot names as used by the API: board, switches, keycaps, stabilizers, cable.
class Build {
  const Build({
    required this.id,
    required this.name,
    this.layout,
    this.stem,
    this.connector,
    required this.slots,
    required this.total,
    required this.openSlots,
  });

  final int id, total;
  final String name;
  final String? layout, stem, connector;
  final Map<String, Listing?> slots;
  final List<String> openSlots;

  factory Build.fromJson(Map<String, dynamic> j) => Build(
        id: j['id'] as int,
        name: j['name'] as String,
        layout: j['layout'] as String?,
        stem: j['stem'] as String?,
        connector: j['connector'] as String?,
        slots: (j['slots'] as Map<String, dynamic>).map((k, v) => MapEntry(
            k, v == null ? null : Listing.fromJson(v as Map<String, dynamic>))),
        total: (j['total'] ?? 0) as int,
        openSlots: ((j['open_slots'] ?? const []) as List).cast<String>(),
      );
}
