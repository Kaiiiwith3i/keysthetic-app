import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listing.dart';
import '../services/api.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/keycap_card.dart';
import '../widgets/price_chip.dart';
import '../widgets/routes.dart';
import '../widgets/shimmer.dart';
import '../widgets/snack.dart';
import '../widgets/stagger.dart';
import 'legit_check_screen.dart';
import 'post_listing_screen.dart';

final myListingsProvider = FutureProvider.autoDispose<List<Listing>>((ref) {
  final api = ref.watch(apiProvider);
  final me = ref.watch(sessionProvider.select((s) => s.user?.id));
  return api.listings(sellerId: me);
});

/// Seller tab: own listings with status, legit badge, edit / remove / Legit Check.
class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  Future<void> _post(BuildContext context, WidgetRef ref, [Listing? edit]) async {
    await context.push(PostListingScreen(listing: edit));
    ref.invalidate(myListingsProvider);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Listing l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove this listing?'),
        content: Text('"${l.title}" will disappear from the marketplace.'),
        actions: [
          TextButton(key: const ValueKey('my_listings.remove.cancel'), style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(d, false), child: const Text('Keep it')),
          TextButton(key: const ValueKey('my_listings.remove.confirm'), style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: d.cs.error), onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).deleteListing(l.id);
      ref.invalidate(myListingsProvider);
      if (context.mounted) showMessage(context, 'Listing removed.');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      showMessage(context, e.status == 409 ? 'This listing has an open order. Cancel the order first, then remove it.' : e.message);
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myListingsProvider);
    return Scaffold(
      floatingActionButton: KeyButton(key: const ValueKey('my_listings.post'), label: 'Post listing', icon: Icons.add, onPressed: () => _post(context, ref)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myListingsProvider);
            await ref.read(myListingsProvider.future).catchError((_) => <Listing>[]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, 112),
            children: [
              Text('My listings', style: context.tt.headlineMedium),
              const SizedBox(height: Sp.lg),
              ...list.when(
                loading: () => [const _Skeleton()],
                error: (e, _) => [_Message(icon: Icons.cloud_off, title: 'Could not load your listings', body: e is ApiException ? e.message : 'Something went wrong.', retry: () => ref.invalidate(myListingsProvider))],
                data: (items) => items.isEmpty
                    ? [const _Message(icon: Icons.sell_outlined, title: 'Nothing for sale yet', body: 'Post your first part. Add photos and a short clip so buyers can hear it first.')]
                    : [
                        for (var i = 0; i < items.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.md),
                            child: Stagger(index: i, child: _Row(items[i], onEdit: () => _post(context, ref, items[i]), onRemove: () => _remove(context, ref, items[i]), onLegit: () async {
                              await context.push(LegitCheckScreen(listing: items[i]));
                              ref.invalidate(myListingsProvider);
                            })),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row(this.l, {required this.onEdit, required this.onRemove, required this.onLegit});
  final Listing l;
  final VoidCallback onEdit, onRemove, onLegit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.keys, cs = context.cs, tt = context.tt;
    final (statusColor, statusText) = switch (l.status) {
      'reserved' => (k.offer, 'Reserved'),
      'sold' => (cs.onSurfaceVariant, 'Sold'),
      _ => (k.accepted, 'Active'),
    };
    final (legitColor, legitText) = switch (l.legit?.verdict) {
      'match' => (k.accepted, 'Legit Check: matches stock'),
      'mods' => (k.offer, 'Legit Check: declared mods'),
      'mismatch' => (k.declined, 'Legit Check: mismatch'),
      _ => (cs.onSurfaceVariant, ''),
    };
    const btn = Size(48, 48);
    return KeycapCard(
      key: ValueKey('my_listings.card.${l.id}'),
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Rad.sm),
            child: SizedBox(
              width: 72,
              height: 72,
              child: l.photos.isEmpty
                  ? ColoredBox(color: k.skeleton)
                  : Image(image: mediaImage(ref, l.photos.first), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: k.skeleton, child: Icon(Icons.keyboard, color: cs.onSurfaceVariant))),
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, style: tt.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: Sp.xs),
              Text(formatPeso(l.price), style: monoStyle(16, cs.onSurface, w: 700)),
              const SizedBox(height: Sp.xs),
              Wrap(spacing: Sp.sm, runSpacing: Sp.xs, children: [
                _Pill(key: ValueKey('my_listings.status.${l.id}'), text: statusText, color: statusColor, icon: Icons.circle),
                if (legitText.isNotEmpty) _Pill(key: ValueKey('my_listings.legit.${l.id}'), text: legitText, color: legitColor, icon: Icons.verified_outlined),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: Sp.xs),
        Wrap(children: [
          TextButton.icon(key: ValueKey('my_listings.edit.${l.id}'), style: TextButton.styleFrom(minimumSize: btn), onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
          if (l.category == 'keyboard')
            TextButton.icon(key: ValueKey('my_listings.legit_check.${l.id}'), style: TextButton.styleFrom(minimumSize: btn), onPressed: onLegit, icon: const Icon(Icons.fact_check_outlined, size: 18), label: Text(l.legit == null ? 'Run Legit Check' : 'Re-run Legit Check')),
          if (l.status != 'sold')
            TextButton.icon(key: ValueKey('my_listings.remove.${l.id}'), style: TextButton.styleFrom(minimumSize: btn, foregroundColor: cs.error), onPressed: onRemove, icon: const Icon(Icons.delete_outline, size: 18), label: const Text('Remove')),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(Rad.sm)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: Sp.xs),
            Flexible(child: Text(text, style: context.tt.labelSmall!.copyWith(color: color))),
          ]),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.retry});
  final IconData icon;
  final String title, body;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.xxl),
        child: Column(children: [
          Icon(icon, size: 48, color: context.cs.onSurfaceVariant),
          const SizedBox(height: Sp.md),
          Text(title, style: context.tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Sp.sm),
          Text(body, style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant), textAlign: TextAlign.center),
          if (retry != null) ...[
            const SizedBox(height: Sp.lg),
            KeyButton(key: const ValueKey('my_listings.retry'), label: 'Try again', secondary: true, onPressed: retry),
          ],
        ]),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) => Shimmer(
        child: Column(children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 150,
              margin: const EdgeInsets.only(bottom: Sp.md),
              decoration: BoxDecoration(color: context.keys.skeleton, borderRadius: BorderRadius.circular(Rad.lg)),
            ),
        ]),
      );
}
