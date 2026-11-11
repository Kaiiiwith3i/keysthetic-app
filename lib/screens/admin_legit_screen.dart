import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/legit.dart';
import '../services/api.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/admin_bits.dart';
import '../widgets/keycap_card.dart';
import '../widgets/routes.dart';
import '../widgets/stagger.dart';
import 'admin_legit_edit_screen.dart';

/// Admin tab: the Legit DB reference list. Tap a row to edit; "New reference" to add.
class AdminLegitScreen extends ConsumerStatefulWidget {
  const AdminLegitScreen({super.key});
  @override
  ConsumerState<AdminLegitScreen> createState() => _AdminLegitScreenState();
}

class _AdminLegitScreenState extends ConsumerState<AdminLegitScreen> {
  List<LegitReference>? _items;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).legitReferences();
      if (mounted) setState(() { _items = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not load references.');
    }
  }

  Future<void> _open([LegitReference? r]) async {
    final changed = await context.push<bool>(AdminLegitEditScreen(reference: r));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final r in _items ?? const <LegitReference>[])
        if (q.isEmpty || '${r.brand} ${r.model} ${r.id}'.toLowerCase().contains(q)) r
    ];
    return Scaffold(
      body: SafeArea(
        child: AdminListBody(
          keyPrefix: 'admin_legit',
          loading: _items == null && _error == null,
          error: _items == null ? _error : null,
          onRefresh: _load,
          emptyIcon: Icons.search_off,
          emptyText: 'No references match.',
          header: AdminHeader(
            title: 'Legit DB',
            searchKey: const ValueKey('admin_legit.search'),
            hint: 'Search brand or model',
            onChanged: (v) => setState(() => _q = v),
            below: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.md),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 20, color: context.cs.onSurfaceVariant),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      'Reference data compares listings to published stock specs. It does not prove authenticity.',
                      key: const ValueKey('admin_legit.note'),
                      style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.sm),
                child: KeyButton(key: const ValueKey('admin_legit.new'), label: 'New reference', icon: Icons.add, secondary: true, onPressed: () => _open()),
              ),
            ],
          ),
          children: [
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: Stagger(index: i, child: _Row(reference: shown[i], onTap: () => _open(shown[i]))),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.reference, required this.onTap});
  final LegitReference reference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = reference;
    final missing = legitFieldDefs.where((d) => r.fields[d.$1]?.value == null).length;
    return KeycapCard(
      key: ValueKey('admin_legit.row.${r.id}'),
      onTap: onTap,
      semanticLabel: 'Edit ${r.brand} ${r.model}',
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.brand} ${r.model}', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
            Text(r.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: monoStyle(12, context.cs.onSurfaceVariant)),
            const SizedBox(height: Sp.xs),
            Text(
              missing == 0 ? 'All ${legitFieldDefs.length} fields sourced' : '$missing of ${legitFieldDefs.length} fields: No published source',
              style: context.tt.bodySmall!.copyWith(color: missing == 0 ? context.keys.accepted : context.keys.offer),
            ),
          ]),
        ),
        Icon(Icons.chevron_right, color: context.cs.onSurfaceVariant),
      ]),
    );
  }
}
