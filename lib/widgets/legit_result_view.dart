import 'package:flutter/material.dart';

import '../models/legit.dart';
import '../theme/tokens.dart';
import 'keycap_card.dart';
import 'reveal_list.dart';

const legitDisclaimer = "This compares the seller's answers to published stock specs. It is not proof of authenticity.";

/// Result field name -> key in the reference's `fields` map.
const _refKey = {'switch': 'switches', 'serial': 'serial_format'};

String _show(Object? v) => v == null ? '' : (v is List ? v.join(', ') : '$v');

/// "https://www.example.com/x" -> "example.com"
String sourceDomain(String url) {
  final h = Uri.tryParse(url)?.host ?? '';
  return h.startsWith('www.') ? h.substring(4) : h;
}

/// Verdict banner, then each compared field revealed one by one. [reference]
/// supplies the per-field source domains. Key: `legit.result`, fields `legit.result.<field>`.
class LegitResultView extends StatelessWidget {
  const LegitResultView({super.key, required this.result, this.reference});
  final LegitResult result;
  final LegitReference? reference;

  static const _labels = {'match': 'Matches stock specs', 'mods': 'Declared mods', 'mismatch': 'Mismatch: ask the seller'};

  @override
  Widget build(BuildContext context) {
    final k = context.keys;
    final (color, icon) = switch (result.verdict) {
      'match' => (k.accepted, Icons.check_circle),
      'mods' => (k.offer, Icons.build_circle),
      _ => (k.declined, Icons.report),
    };
    final label = _labels[result.verdict] ?? result.verdictLabel;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(
          child: DecoratedBox(
            key: const ValueKey('legit.result'),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: color, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Sp.lg),
              child: Row(children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(width: Sp.md),
                Expanded(child: Text(label, style: context.tt.headlineSmall!.copyWith(color: color))),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: Sp.md),
      Text(legitDisclaimer, key: const ValueKey('legit.disclaimer'), style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
      const SizedBox(height: Sp.lg),
      RevealList(children: [for (final f in result.fields) _FieldCard(f, reference?.fields[_refKey[f.field] ?? f.field]?.source)]),
    ]);
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard(this.f, this.source);
  final LegitFieldResult f;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final k = context.keys, cs = context.cs, tt = context.tt;
    final (color, icon, word) = switch (f.result) {
      'match' => (k.accepted, Icons.check_circle, 'Match'),
      'mod' => (k.offer, Icons.build_circle, 'Declared mod'),
      'mismatch' => (k.declined, Icons.cancel, 'Mismatch'),
      _ => (cs.onSurfaceVariant, Icons.help_outline, 'Unknown'),
    };
    final unknown = f.result == 'unknown';
    final domain = source == null ? null : sourceDomain(source!);
    Widget line(String l, String v) => Padding(
          padding: const EdgeInsets.only(top: Sp.xs),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$l  ', style: tt.labelMedium!.copyWith(color: cs.onSurfaceVariant)),
            TextSpan(text: v.isEmpty ? '-' : v, style: tt.bodyMedium),
          ])),
        );
    return KeycapCard(
      key: ValueKey('legit.result.${f.field}'),
      padding: const EdgeInsets.all(Sp.md),
      child: Semantics(
        container: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: Sp.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(f.label, style: tt.titleSmall),
                Text(word.toUpperCase(), style: tt.labelSmall!.copyWith(color: color, letterSpacing: 1)),
              ]),
              line('Expected', unknown ? 'No published reference' : _show(f.expected)),
              line('Given', _show(f.given)),
              if (f.note != null && f.note!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: Sp.xs), child: Text(f.note!, style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant))),
              if (domain != null && domain.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Sp.xs),
                  child: Text('Source: $domain', style: tt.labelSmall!.copyWith(color: cs.primary, decoration: TextDecoration.underline)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
