import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A labelled row of single-select chips. Tap the selected chip again to clear
/// when [clearable]. Keys: `<keyPrefix>.<value>`.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
    this.clearable = true,
  });

  final String label, keyPrefix;
  final Map<String, String> options; // value -> display text
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool clearable;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tt.labelLarge!.copyWith(color: context.cs.onSurfaceVariant)),
          const SizedBox(height: Sp.xs),
          Wrap(spacing: Sp.sm, children: [
            for (final e in options.entries)
              ChoiceChip(
                key: ValueKey('$keyPrefix.${e.key}'),
                label: Text(e.value),
                selected: value == e.key,
                onSelected: (_) => onChanged(value == e.key && clearable ? null : e.key),
              ),
          ]),
        ],
      );
}
