import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listing.dart';
import '../services/api.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/admin_bits.dart';
import '../widgets/keycap_card.dart';
import '../widgets/price_chip.dart';
import '../widgets/routes.dart';
import '../widgets/snack.dart';
import '../widgets/stagger.dart';
import 'listing_detail_screen.dart';

const _statuses = ['all', 'active', 'reserved', 'sold', 'hidden'];

Color statusColor(BuildContext context, String status) {
  final k = context.keys;
  return switch (status) { 'active' => k.accepted, 'reserved' => k.offer, 'sold' => k.counter, _ => k.declined };
}

/// Admin tab: every listing, filter by status, hide / unhide.
class AdminListingsScreen extends ConsumerStatefulWidget {
  const AdminListingsScreen({super.key});
  @override
  ConsumerState<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends ConsumerState<AdminListingsScreen> {
  List<Listing>? _items;
  String? _error;
  String _status = 'all', _q = '';
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).adminListings();
      if (mounted) setState(() { _items = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not load listings.');
    }
  }

  Future<void> _toggleHidden(Listing l) async {
    final hide = l.status != 'hidden';
    final ok = await confirmAction(context,
        title: hide ? 'Hide this listing?' : 'Unhide this listing?',
        body: hide ? '"${l.title}" disappears from the feed and search. Its seller still sees that it was removed.' : '"${l.title}" goes back to active and shows in the feed again.',
        confirmLabel: hide ? 'Hide' : 'Unhide',
        keyPrefix: 'admin_listings.confirm',
        destructive: hide);
    if (!ok || !mounted) return;
    setState(() => _busy.add(l.id));
    try {
      final u = await ref.read(apiProvider).hideListing(l.id, hide);
      if (!mounted) return;
      setState(() => _items = [for (final x in _items!) x.id == l.id ? u : x]);
      showMessage(context, hide ? 'Listing hidden.' : 'Listing is active again.');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(l.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _items ?? const <Listing>[];
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final l in all)
        if ((_status == 'all' || l.status == _status) && (q.isEmpty || '${l.title} ${l.seller.name}'.toLowerCase().contains(q))) l
    ];
    int count(String s) => s == 'all' ? all.length : all.where((l) => l.status == s).length;
    return Scaffold(
      body: SafeArea(
        child: AdminListBody(
          keyPrefix: 'admin_listings',
          loading: _items == null && _error == null,
          error: _items == null ? _error : null,
          onRefresh: _load,
          emptyIcon: Icons.inventory_2_outlined,
          emptyText: 'No listings match.',
          header: AdminHeader(
            title: 'Listings',
            searchKey: const ValueKey('admin_listings.search'),
            hint: 'Search title or seller',
            onChanged: (v) => setState(() => _q = v),
            below: [
              ChipFilterRow(
                keyPrefix: 'admin_listings.filter',
                selected: _status,
                onSelected: (v) => setState(() => _status = v),
                options: [for (final s in _statuses) (s, s[0].toUpperCase() + s.substring(1), count(s))],
              ),
            ],
          ),
          children: [
            for (var i = 0; i < shown.length; i++)
              Padding(
                key: ValueKey('admin_listings.row.${shown[i].id}'),
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: Stagger(index: i, child: _Row(listing: shown[i], busy: _busy.contains(shown[i].id), onToggle: () => _toggleHidden(shown[i]))),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.listing, required this.busy, required this.onToggle});
  final Listing listing;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = listing;
    final hidden = l.status == 'hidden';
    return KeycapCard(
      key: ValueKey('admin_listings.open.${l.id}'),
      onTap: () => context.push(ListingDetailScreen(listingId: l.id)),
      semanticLabel: 'Open ${l.title}',
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Rad.sm),
            child: SizedBox(
              width: 64,
              height: 64,
              child: l.photos.isEmpty
                  ? ColoredBox(color: context.keys.skeleton, child: Icon(Icons.keyboard_outlined, color: context.cs.onSurfaceVariant))
                  : Image(
                      image: ref.read(apiProvider).mediaImage(l.photos.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: context.keys.skeleton, child: Icon(Icons.broken_image_outlined, color: context.cs.onSurfaceVariant)),
                    ),
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
              Text('by ${l.seller.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
              const SizedBox(height: Sp.xs),
              Text(formatPeso(l.price), style: monoStyle(15, context.cs.onSurface, w: 700)),
            ]),
          ),
        ]),
        const SizedBox(height: Sp.sm),
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: Sp.sm, children: [
          StatusPill(label: l.status, color: statusColor(context, l.status)),
          if (l.status != 'sold')
            KeyButton(
              key: ValueKey('admin_listings.hide.${l.id}'),
              label: hidden ? 'Unhide' : 'Hide',
              icon: hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              secondary: true,
              busy: busy,
              onPressed: onToggle,
            ),
        ]),
      ]),
    );
  }
}
