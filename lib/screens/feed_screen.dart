import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/browse.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/listing_card.dart';

/// Home tab: category chips, optional "Fits my build" chip, staggered card grid.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  String? _category;
  bool _fits = false;

  @override
  Widget build(BuildContext context) {
    final isBuyer = ref.watch(sessionProvider.select((s) => s.role)) == 'buyer';
    final build = isBuyer ? selectedBuild(ref.watch(buildsProvider).value ?? const [], ref.watch(selectedBuildIdProvider)) : null;
    final filter = ListingFilter(category: _category, buildId: _fits ? build?.id : null);
    final value = ref.watch(listingsProvider(filter));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.sm),
              child: Text('Keysthetic', style: context.tt.headlineMedium),
            ),
            SizedBox(
              height: 52,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                child: Row(
                  children: [
                    if (build != null)
                      _Chip(
                        key: const ValueKey('feed.fits'),
                        label: _fits ? 'Fits ${build.name}' : 'Fits my build',
                        icon: Icons.keyboard_outlined,
                        selected: _fits,
                        onTap: () => setState(() => _fits = !_fits),
                      ),
                    _Chip(
                      key: const ValueKey('feed.chip.all'),
                      label: 'All',
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final e in categoryLabels.entries)
                      _Chip(
                        key: ValueKey('feed.chip.${e.key}'),
                        label: e.value,
                        selected: _category == e.key,
                        onTap: () => setState(() => _category = e.key),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListingsBody(
                value: value,
                onRefresh: () => reloadListings(ref, filter),
                emptyTitle: _fits ? 'Nothing fits yet' : 'No listings here yet',
                emptyHint: _fits
                    ? 'No active listings match the open slots of ${build?.name ?? 'your build'}. Try All.'
                    : 'Check back soon, or try another category.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: Sp.sm),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        ),
      ),
    ),
  );
}
