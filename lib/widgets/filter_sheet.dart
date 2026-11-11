import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/build.dart';
import '../services/browse.dart';
import '../theme/tokens.dart';
import 'keycap_card.dart';

/// Bottom sheet for category, price, condition, layout, connection, sort and
/// "fits my build". Resolves to the new filter (the text query is kept as is),
/// or null when dismissed.
Future<ListingFilter?> showFilterSheet(BuildContext context, ListingFilter current, List<Build> builds) =>
    showModalBottomSheet<ListingFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(current, builds),
    );

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(this.initial, this.builds);
  final ListingFilter initial;
  final List<Build> builds;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListingFilter _f = widget.initial;
  late final _min = TextEditingController(text: widget.initial.minPrice?.toString() ?? '');
  late final _max = TextEditingController(text: widget.initial.maxPrice?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  ListingFilter _apply() {
    var lo = int.tryParse(_min.text), hi = int.tryParse(_max.text);
    if (lo != null && hi != null && lo > hi) (lo, hi) = (hi, lo);
    return _f.copyWith(minPrice: lo, maxPrice: hi);
  }

  void _reset() {
    _min.clear();
    _max.clear();
    setState(() => _f = ListingFilter(q: _f.q));
  }

  Widget _section(String title, String keyPrefix, Map<String, String> options, String? value, void Function(String?) set) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: context.tt.titleSmall),
          const SizedBox(height: Sp.sm),
          Wrap(spacing: Sp.sm, runSpacing: Sp.xs, children: [
            for (final e in options.entries)
              ChoiceChip(
                key: ValueKey('filter.$keyPrefix.${e.key}'),
                label: Text(e.value),
                selected: value == e.key,
                showCheckmark: false,
                onSelected: (on) => setState(() => set(on ? e.key : null)),
              ),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final field = InputDecoration(prefixText: '₱ ');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Filters', style: context.tt.titleLarge),
          const SizedBox(height: Sp.lg),
          _section('Category', 'category', categoryLabels, _f.category, (v) => _f = _f.copyWith(category: v)),
          Text('Price', style: context.tt.titleSmall),
          const SizedBox(height: Sp.sm),
          Row(children: [
            for (final (k, c, hint) in [('min', _min, 'Min'), ('max', _max, 'Max')]) ...[
              if (k == 'max') const SizedBox(width: Sp.md),
              Expanded(
                child: TextField(
                  key: ValueKey('filter.$k'),
                  controller: c,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: field.copyWith(hintText: hint),
                ),
              ),
            ],
          ]),
          const SizedBox(height: Sp.lg),
          _section('Condition', 'condition', conditionLabels, _f.condition, (v) => _f = _f.copyWith(condition: v)),
          _section('Layout', 'layout', layoutLabels, _f.layout, (v) => _f = _f.copyWith(layout: v)),
          _section('Connection', 'connection', connectionLabels, _f.connection, (v) => _f = _f.copyWith(connection: v)),
          if (widget.builds.isNotEmpty)
            _section('Fits my build', 'build', {for (final b in widget.builds) '${b.id}': b.name}, _f.buildId?.toString(),
                (v) => _f = _f.copyWith(buildId: v == null ? null : int.parse(v))),
          _section('Sort by', 'sort', sortLabels, _f.sort, (v) => _f = _f.copyWith(sort: v)),
          Row(children: [
            Expanded(child: KeyButton(key: const ValueKey('filter.reset'), label: 'Reset', secondary: true, onPressed: _reset)),
            const SizedBox(width: Sp.md),
            Expanded(child: KeyButton(key: const ValueKey('filter.apply'), label: 'Show results', onPressed: () => Navigator.pop(context, _apply()))),
          ]),
        ]),
      ),
    );
  }
}
