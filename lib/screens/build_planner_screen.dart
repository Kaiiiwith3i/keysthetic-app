import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/build.dart';
import '../models/listing.dart';
import '../services/api.dart';
import '../services/browse.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/build_sheets.dart';
import '../widgets/keyboard_layers.dart';
import '../widgets/keycap_card.dart';
import '../widgets/listing_card.dart';
import '../widgets/pressable.dart';
import '../widgets/price_chip.dart';
import '../widgets/routes.dart';
import '../widgets/shimmer.dart';
import '../widgets/snack.dart';
import 'listing_detail_screen.dart';
import 'search_filter_screen.dart';

const _slotIcons = {
  BuildSlot.board: Icons.keyboard_outlined,
  BuildSlot.switches: Icons.radio_button_checked,
  BuildSlot.keycaps: Icons.grid_view_rounded,
  BuildSlot.stabilizers: Icons.straighten,
  BuildSlot.cable: Icons.cable,
};

/// Build tab: pick a build, watch the keyboard assemble as slots fill, track the total.
class BuildPlannerScreen extends ConsumerStatefulWidget {
  const BuildPlannerScreen({super.key});
  @override
  ConsumerState<BuildPlannerScreen> createState() => _BuildPlannerScreenState();
}

class _BuildPlannerScreenState extends ConsumerState<BuildPlannerScreen> {
  KeyboardColorway _colorway = KeyboardColorway.carbon;

  Future<void> _do(Future<void> Function() job) async {
    try {
      await job();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _create() async {
    final name = await promptBuildName(context, title: 'New build');
    if (name != null) await _do(() => ref.read(buildsProvider.notifier).create(name));
  }

  Future<void> _rename(Build b) async {
    final name = await promptBuildName(context, title: 'Rename build', initial: b.name);
    if (name != null && name != b.name) await _do(() => ref.read(buildsProvider.notifier).rename(b.id, name));
  }

  Future<void> _delete(Build b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${b.name}"?'),
        content: const Text('The listings in it are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(key: const ValueKey('build.delete.confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _do(() => ref.read(buildsProvider.notifier).remove(b.id));
  }

  Future<void> _pickSpec(Build b, String field, Map<String, String> options, String? current) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (field) {
              'layout' => 'Layout',
              'stem' => 'Switch stem',
              _ => 'Connector',
            }, style: ctx.tt.titleLarge),
            const SizedBox(height: Sp.md),
            Wrap(
              spacing: Sp.sm,
              runSpacing: Sp.xs,
              children: [
                for (final e in options.entries)
                  ChoiceChip(
                    key: ValueKey('build.spec.$field.${e.key}'),
                    label: Text(e.value),
                    selected: current == e.key,
                    showCheckmark: false,
                    onSelected: (_) => Navigator.pop(ctx, e.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (v == null || v == current) return;
    await _do(
      () => ref
          .read(buildsProvider.notifier)
          .setSpec(
            b.id,
            layout: field == 'layout' ? v : null,
            stem: field == 'stem' ? v : null,
            connector: field == 'connector' ? v : null,
          ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(buildsProvider);
    try {
      await ref.read(buildsProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final builds = ref.watch(buildsProvider);
    final selected = builds.value == null ? null : selectedBuild(builds.value!, ref.watch(selectedBuildIdProvider));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: Sp.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.sm),
                child: Row(
                  children: [
                    Expanded(child: Text('Build planner', style: context.tt.headlineMedium)),
                    if (selected != null)
                      Pressable(
                        key: const ValueKey('build.new'),
                        semanticLabel: 'New build',
                        onTap: _create,
                        child: Padding(
                          padding: const EdgeInsets.all(Sp.sm),
                          child: Icon(Icons.add_circle, size: 32, color: context.cs.primary),
                        ),
                      ),
                  ],
                ),
              ),
              ...builds.when(
                skipLoadingOnReload: true,
                loading: () => const [_PlannerSkeleton()],
                error: (e, _) => [
                  SizedBox(
                    height: 360,
                    child: StateMessage(
                      icon: Icons.cloud_off_outlined,
                      title: "Couldn't load your builds",
                      hint: e is ApiException ? e.message : 'Something went wrong.',
                      actionLabel: 'Try again',
                      actionKey: const ValueKey('build.retry'),
                      onAction: _refresh,
                    ),
                  ),
                ],
                data: (list) => list.isEmpty
                    ? [
                        SizedBox(
                          height: 360,
                          child: StateMessage(
                            icon: Icons.keyboard_outlined,
                            title: 'Plan your first build',
                            hint: 'Pick a board, switches, keycaps, stabilizers and a cable, and watch the keyboard come together.',
                            actionLabel: 'Start a build',
                            actionKey: const ValueKey('build.create'),
                            onAction: _create,
                          ),
                        ),
                      ]
                    : _content(list, selected!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(List<Build> list, Build b) {
    final cs = context.cs, tt = context.tt;
    final filled = {
      for (final s in BuildSlot.values)
        if (b.slots[s.name] != null) s,
    };
    final open = BuildSlot.values.length - filled.length;
    return [
      SizedBox(
        height: 52,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
          child: Row(
            children: [
              for (final x in list)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.sm),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: ChoiceChip(
                        key: ValueKey('build.chip.${x.id}'),
                        label: Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        selected: x.id == b.id,
                        showCheckmark: false,
                        onSelected: (_) => ref.read(selectedBuildIdProvider.notifier).set(x.id),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.sm, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(b.name, key: const ValueKey('build.name'), style: tt.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('build.menu'),
              tooltip: 'Build options',
              onSelected: (v) => v == 'rename' ? _rename(b) : _delete(b),
              itemBuilder: (_) => const [
                PopupMenuItem(key: ValueKey('build.rename'), value: 'rename', child: Text('Rename')),
                PopupMenuItem(key: ValueKey('build.delete'), value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
      KeyboardLayers(filled: filled, layout: KbLayout.fromApi(b.layout), colorway: _colorway),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final c in KeyboardColorway.presets)
            Pressable(
              key: ValueKey('build.colorway.${c.name.toLowerCase()}'),
              semanticLabel: '${c.name} colourway',
              onTap: () => setState(() => _colorway = c),
              child: AnimatedContainer(
                duration: Dur.base,
                margin: const EdgeInsets.all(Sp.xs),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.caseColor,
                  border: Border.all(color: _colorway == c ? cs.primary : cs.outline, width: _colorway == c ? 3 : 1.5),
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.mod),
                  ),
                ),
              ),
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, 0),
        child: KeycapCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL', style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2)),
                    const SizedBox(height: Sp.xs),
                    TweenAnimationBuilder<double>(
                      key: ValueKey('build.total.${b.id}'),
                      tween: Tween(begin: 0, end: b.total.toDouble()),
                      duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) =>
                          Text(formatPeso(v.round()), key: const ValueKey('build.total'), style: monoStyle(28, cs.onSurface, w: 800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.md),
              Flexible(
                child: Text(
                  open == 0 ? 'Build complete' : '$open of ${BuildSlot.values.length} slots open',
                  key: const ValueKey('build.open'),
                  textAlign: TextAlign.end,
                  style: tt.titleSmall!.copyWith(color: open == 0 ? context.keys.accepted : cs.primary),
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 0),
        child: Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.xs,
          children: [
            for (final (field, name, labels, v) in [
              ('layout', 'Layout', layoutLabels, b.layout),
              ('stem', 'Stem', stemLabels, b.stem),
              ('connector', 'Connector', connectorLabels, b.connector),
            ])
              ActionChip(
                key: ValueKey('build.spec.$field'),
                avatar: const Icon(Icons.edit_outlined, size: 16),
                label: Text('$name: ${v == null ? 'any' : labels[v] ?? v}'),
                onPressed: () => _pickSpec(b, field, labels, v),
              ),
          ],
        ),
      ),
      for (final s in BuildSlot.values)
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, 0),
          child: _SlotRow(
            slot: s,
            listing: b.slots[s.name],
            onFind: () => context.push(
              SearchFilterScreen(
                initial: ListingFilter(category: categoryOfSlot(s), buildId: b.id),
                title: 'Find ${slotLabels[s]!.toLowerCase()}',
              ),
            ),
            onRemove: () => _do(() => ref.read(buildsProvider.notifier).setSlot(b.id, s, null)),
          ),
        ),
    ];
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.listing, required this.onFind, required this.onRemove});
  final BuildSlot slot;
  final Listing? listing;
  final VoidCallback onFind, onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, tt = context.tt;
    final l = listing;
    final head = Row(
      children: [
        Icon(_slotIcons[slot], size: 20, color: l == null ? cs.onSurfaceVariant : cs.primary),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: Text(slotLabels[slot]!.toUpperCase(), style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1.2)),
        ),
        if (l != null)
          IconButton(
            key: ValueKey('build.slot.${slot.name}.remove'),
            tooltip: 'Remove ${slotLabels[slot]!.toLowerCase()}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.close),
            onPressed: onRemove,
          )
        else
          Text('Open', style: tt.labelMedium!.copyWith(color: cs.primary)),
      ],
    );
    if (l == null) {
      return KeycapCard(
        key: ValueKey('build.slot.${slot.name}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            const SizedBox(height: Sp.sm),
            KeyButton(
              key: ValueKey('build.slot.${slot.name}.find'),
              label: 'Find compatible',
              icon: Icons.search,
              secondary: true,
              onPressed: onFind,
            ),
          ],
        ),
      );
    }
    return KeycapCard(
      key: ValueKey('build.slot.${slot.name}'),
      onTap: () => context.push(ListingDetailScreen(listingId: l.id)),
      semanticLabel: '${slotLabels[slot]}: ${l.title}, ${formatPeso(l.price)}',
      child: Column(
        children: [
          head,
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Rad.sm),
                  child: ListingPhoto(url: l.photos.firstOrNull, cacheWidth: 200),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
              ),
              const SizedBox(width: Sp.md),
              Text(formatPeso(l.price), style: monoStyle(15, cs.onSurface, w: 700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlannerSkeleton extends StatelessWidget {
  const _PlannerSkeleton();
  @override
  Widget build(BuildContext context) => const Shimmer(
    child: Padding(
      padding: EdgeInsets.all(Sp.lg),
      child: Column(
        children: [
          SkeletonBox(height: 220, radius: Rad.lg),
          SizedBox(height: Sp.lg),
          SkeletonBox(height: 72, radius: Rad.lg),
          SizedBox(height: Sp.md),
          SkeletonBox(height: 72, radius: Rad.lg),
          SizedBox(height: Sp.md),
          SkeletonBox(height: 72, radius: Rad.lg),
        ],
      ),
    ),
  );
}
