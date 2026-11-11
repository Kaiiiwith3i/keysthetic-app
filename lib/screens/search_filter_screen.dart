import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/build.dart';
import '../services/browse.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/listing_card.dart';
import '../widgets/pressable.dart';
import '../widgets/price_chip.dart';

/// Search tab, and the "Find compatible" destination when pushed with an
/// [initial] filter (then it has a back button and shows [title]).
class SearchFilterScreen extends ConsumerStatefulWidget {
  const SearchFilterScreen({super.key, this.initial = const ListingFilter(), this.title});
  final ListingFilter initial;
  final String? title;
  @override
  ConsumerState<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends ConsumerState<SearchFilterScreen> {
  late ListingFilter _f = widget.initial;
  final _text = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onText(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = v.trim();
      if (mounted) setState(() => _f = _f.copyWith(q: q.isEmpty ? null : q));
    });
  }

  Future<void> _openFilters(bool isBuyer) async {
    final List<Build> builds = isBuyer ? ref.read(buildsProvider).value ?? const [] : const [];
    final r = await showFilterSheet(context, _f, builds);
    if (r != null) setState(() => _f = r);
  }

  @override
  Widget build(BuildContext context) {
    final isBuyer = ref.watch(sessionProvider.select((s) => s.role)) == 'buyer';
    final List<Build> builds = isBuyer ? ref.watch(buildsProvider).value ?? const [] : const [];
    final value = ref.watch(listingsProvider(_f));
    final pushed = Navigator.of(context).canPop();
    final chips = <(String, String, ListingFilter)>[
      if (_f.category != null) ('category', categoryLabels[_f.category] ?? _f.category!, _f.copyWith(category: null)),
      if (_f.buildId != null)
        ('build', 'Fits ${builds.where((b) => b.id == _f.buildId).firstOrNull?.name ?? 'my build'}', _f.copyWith(buildId: null)),
      if (_f.minPrice != null || _f.maxPrice != null)
        (
          'price',
          _f.minPrice != null && _f.maxPrice != null
              ? '${formatPeso(_f.minPrice!)} to ${formatPeso(_f.maxPrice!)}'
              : _f.minPrice != null
              ? 'From ${formatPeso(_f.minPrice!)}'
              : 'Up to ${formatPeso(_f.maxPrice!)}',
          _f.copyWith(minPrice: null, maxPrice: null),
        ),
      if (_f.condition != null) ('condition', conditionLabels[_f.condition] ?? _f.condition!, _f.copyWith(condition: null)),
      if (_f.layout != null) ('layout', layoutLabels[_f.layout] ?? _f.layout!, _f.copyWith(layout: null)),
      if (_f.connection != null) ('connection', connectionLabels[_f.connection] ?? _f.connection!, _f.copyWith(connection: null)),
      if (_f.sort != null && _f.sort != 'new') ('sort', sortLabels[_f.sort] ?? _f.sort!, _f.copyWith(sort: null)),
    ];
    final cs = context.cs;
    return Scaffold(
      appBar: pushed ? AppBar(title: Text(widget.title ?? 'Search')) : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!pushed)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.sm),
                child: Text('Search', style: context.tt.headlineMedium),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('search.field'),
                      controller: _text,
                      onChanged: _onText,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(hintText: 'Search listings', prefixIcon: Icon(Icons.search)),
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Pressable(
                    key: const ValueKey('search.filter'),
                    semanticLabel: 'Filters',
                    minSize: 56,
                    onTap: () => _openFilters(isBuyer),
                    child: Badge(
                      isLabelVisible: chips.isNotEmpty,
                      label: Text('${chips.length}'),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: context.keys.capTop,
                          borderRadius: BorderRadius.circular(Rad.md),
                          border: Border.all(color: cs.outlineVariant, width: 1.5),
                        ),
                        child: Icon(Icons.tune, color: cs.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (chips.isNotEmpty)
              SizedBox(
                height: 52,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                  child: Row(
                    children: [
                      for (final c in chips)
                        Padding(
                          padding: const EdgeInsets.only(right: Sp.sm),
                          child: Center(
                            child: ActionChip(
                              key: ValueKey('search.chip.${c.$1}'),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(c.$2),
                                  const SizedBox(width: Sp.xs),
                                  const Icon(Icons.close, size: 16),
                                ],
                              ),
                              onPressed: () => setState(() => _f = c.$3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ListingsBody(
                value: value,
                retryKey: const ValueKey('search.retry'),
                onRefresh: () => reloadListings(ref, _f),
                emptyTitle: 'No matches',
                emptyHint: 'Try fewer filters or a different search.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
