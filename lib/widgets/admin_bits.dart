import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'keycap_card.dart';
import 'shimmer.dart';

/// Small coloured label (listing status, role, banned). The colour animates when it changes.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: context.reduceMotion ? Duration.zero : Dur.base,
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm + 2, vertical: Sp.xs + 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(Rad.sm),
          border: Border.all(color: color.withValues(alpha: .55), width: 1.5),
        ),
        child: AnimatedSwitcher(
          duration: context.reduceMotion ? Duration.zero : Dur.base,
          child: Text(label.toUpperCase(), key: ValueKey(label), style: context.tt.labelSmall!.copyWith(color: color, letterSpacing: 1)),
        ),
      );
}

/// Confirm dialog; buttons are keyed `<keyPrefix>.confirm` / `<keyPrefix>.cancel`.
Future<bool> confirmAction(BuildContext context, {required String title, required String body, required String confirmLabel, required String keyPrefix, bool destructive = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(key: ValueKey('$keyPrefix.cancel'), style: TextButton.styleFrom(minimumSize: const Size(64, 48)), onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          key: ValueKey('$keyPrefix.confirm'),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: destructive ? ctx.cs.error : ctx.cs.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Row of single-select chips: (value, label, count).
class ChipFilterRow extends StatelessWidget {
  const ChipFilterRow({super.key, required this.options, required this.selected, required this.onSelected, required this.keyPrefix});
  final List<(String, String, int)> options;
  final String selected, keyPrefix;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
        child: Wrap(spacing: Sp.sm, children: [
          for (final (v, label, n) in options)
            ChoiceChip(
              key: ValueKey('$keyPrefix.$v'),
              label: Text('$label $n'),
              selected: selected == v,
              showCheckmark: false,
              onSelected: (_) => onSelected(v),
            ),
        ]),
      );
}

/// Pull-to-refresh list with the shared loading / error / empty states.
/// [header] stays fixed above the list.
class AdminListBody extends StatelessWidget {
  const AdminListBody({
    super.key,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyText,
    required this.children,
    this.header,
    this.keyPrefix = 'admin',
  });
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyText, keyPrefix;
  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (loading) {
      content = ListView(
        key: ValueKey('$keyPrefix.loading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Sp.lg),
        children: [for (var i = 0; i < 6; i++) const ListRowSkeleton()],
      );
    } else {
      content = RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          key: ValueKey('$keyPrefix.list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
          children: error != null
              ? [_Message(icon: Icons.cloud_off, text: error!, action: KeyButton(key: ValueKey('$keyPrefix.retry'), label: 'Try again', icon: Icons.refresh, onPressed: onRefresh))]
              : children.isEmpty
                  ? [_Message(icon: emptyIcon, text: emptyText)]
                  : children,
        ),
      );
    }
    return Column(children: [?header, Expanded(child: content)]);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xxl),
        child: Column(children: [
          Icon(icon, size: 40, color: context.cs.onSurfaceVariant),
          const SizedBox(height: Sp.md),
          Text(text, textAlign: TextAlign.center, style: context.tt.bodyLarge!.copyWith(color: context.cs.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: Sp.lg), action!],
        ]),
      );
}

/// Screen title + search box used at the top of the admin tabs.
class AdminHeader extends StatelessWidget {
  const AdminHeader({super.key, required this.title, required this.searchKey, required this.hint, required this.onChanged, this.below = const []});
  final String title, hint;
  final Key searchKey;
  final ValueChanged<String> onChanged;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.md), child: Text(title, style: context.tt.headlineMedium)),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.md),
          child: TextField(key: searchKey, onChanged: onChanged, textInputAction: TextInputAction.search, decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search))),
        ),
        ...below,
      ]);
}
