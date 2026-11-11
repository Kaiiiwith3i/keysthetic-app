import 'package:flutter/material.dart';

import '../models/build.dart';
import '../services/browse.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'keycap_card.dart';
import 'keyboard_layers.dart';
import 'price_chip.dart';

/// Name dialog for creating / renaming a build. Null when cancelled.
Future<String?> promptBuildName(BuildContext context, {required String title, String initial = ''}) => showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title, initial),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog(this.title, this.initial);
  final String title, initial;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final n = _c.text.trim();
    if (n.isNotEmpty) Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          key: const ValueKey('build.name.field'),
          controller: _c,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Cream 65% daily'),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(key: const ValueKey('build.name.save'), onPressed: _save, child: const Text('Save')),
        ],
      );
}

/// "Add to build": pick which build gets [slot]. Resolves to the chosen build,
/// or `create: true` when the buyer wants a new one.
Future<({Build? build, bool create})?> pickBuildForSlot(BuildContext context, List<Build> builds, BuildSlot slot) =>
    showModalBottomSheet<({Build? build, bool create})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Add to which build?', style: ctx.tt.titleLarge),
          const SizedBox(height: Sp.xs),
          Text('It will fill the ${slotLabels[slot]!.toLowerCase()} slot.', style: ctx.tt.bodyMedium!.copyWith(color: ctx.cs.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          for (final b in builds)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: KeycapCard(
                key: ValueKey('detail.build.${b.id}'),
                semanticLabel: 'Add to ${b.name}',
                onTap: () => Navigator.pop(ctx, (build: b, create: false)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.name, style: ctx.tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: Sp.xs),
                      Text(
                        b.slots[slot.name] == null ? 'Slot open' : 'Replaces ${b.slots[slot.name]!.title}',
                        style: ctx.tt.bodySmall!.copyWith(color: ctx.cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                  const SizedBox(width: Sp.md),
                  Text(formatPeso(b.total), style: monoStyle(14, ctx.cs.onSurface)),
                ]),
              ),
            ),
          KeyButton(key: const ValueKey('detail.build.new'), label: 'New build', icon: Icons.add, secondary: true, onPressed: () => Navigator.pop(ctx, (build: null, create: true))),
        ]),
      ),
    );
