import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listing.dart';
import '../screens/listing_detail_screen.dart';
import '../services/api.dart';
import '../services/browse.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'hero_tags.dart';
import 'keycap_card.dart';
import 'price_chip.dart';
import 'routes.dart';
import 'shimmer.dart';
import 'stagger.dart';

/// Pull-to-refresh / retry for a listing query.
Future<void> reloadListings(WidgetRef ref, ListingFilter f) async {
  ref.invalidate(listingsProvider(f));
  try {
    await ref.read(listingsProvider(f).future);
  } catch (_) {} // the error state renders it
}

/// Small outlined tag ("75%", "Wireless") used on cards and in the detail header.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.sm - 4),
          border: Border.all(color: context.cs.outline),
        ),
        child: Text(label, style: context.tt.labelSmall!.copyWith(color: context.cs.onSurfaceVariant)),
      );
}

/// Pill badge drawn over a photo ("Reserved", "Legit-checked").
class PhotoBadge extends StatelessWidget {
  const PhotoBadge(this.label, {super.key, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final bg = color ?? context.cs.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.sm)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: Colors.white), const SizedBox(width: 3)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.labelSmall!.copyWith(color: Colors.white))),
      ]),
    );
  }
}

/// Rounded photo that follows the Hero convention; used by cards and the detail gallery.
class ListingPhoto extends ConsumerWidget {
  const ListingPhoto({super.key, required this.url, this.fit = BoxFit.cover, this.cacheWidth = 600});
  final String? url;
  final BoxFit fit;
  final int cacheWidth;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ph = ColoredBox(color: context.keys.skeleton, child: Icon(Icons.keyboard_outlined, color: context.cs.onSurfaceVariant));
    if (url == null) return ph;
    return Image(
      image: ResizeImage(mediaImage(ref, url!), width: cacheWidth, policy: ResizeImagePolicy.fit),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => ph,
      frameBuilder: (_, child, frame, sync) => sync
          ? child
          : AnimatedSwitcher(duration: Dur.base, child: frame == null ? const Shimmer(child: SkeletonBox(height: double.infinity, radius: 0)) : child),
    );
  }
}

/// A grid card: keycap surface, photo with Hero, title, price, condition and area, tags, badges.
class ListingCard extends ConsumerWidget {
  const ListingCard({super.key, required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = listing;
    final cs = context.cs, tt = context.tt;
    final tags = [
      if (l.layout != null) layoutLabels[l.layout] ?? l.layout!,
      if (l.connection != null) connectionLabels[l.connection] ?? l.connection!,
      if (l.switchType != null) switchTypeLabels[l.switchType] ?? l.switchType!,
    ].take(3);
    // Offstage tabs (IndexedStack) have tickers off; two live Heroes with one tag would assert.
    final heroOn = TickerMode.valuesOf(context).enabled;
    final photo = ClipRRect(borderRadius: BorderRadius.circular(Rad.md), child: ListingPhoto(url: l.photos.firstOrNull));
    return KeycapCard(
      key: ValueKey('feed.card.${l.id}'),
      padding: EdgeInsets.zero,
      semanticLabel: '${l.title}, ${formatPeso(l.price)}, ${conditionLabels[l.condition] ?? l.condition}',
      onTap: () => context.push(ListingDetailScreen(listingId: l.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: AspectRatio(
            aspectRatio: 4 / 3, // seeded renders are 800x600; keep the whole keyboard visible
            child: Stack(fit: StackFit.expand, children: [
              heroOn ? ListingHero(listingId: l.id, child: photo) : photo,
              Positioned(
                left: Sp.sm,
                right: Sp.sm,
                top: Sp.sm,
                child: Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [
                  if (l.status == 'reserved') PhotoBadge('Reserved', color: context.keys.offer.withValues(alpha: .95)),
                  if (l.legit != null) const PhotoBadge('Legit-checked', icon: Icons.verified, color: Color(0xE61E8A4C)),
                ]),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.xs, Sp.md, Sp.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
            const SizedBox(height: Sp.xs),
            Text(formatPeso(l.price), style: monoStyle(17, cs.onSurface, w: 800)),
            const SizedBox(height: Sp.xs),
            Text(
              [conditionLabels[l.condition] ?? l.condition, if (l.meetupArea != null) l.meetupArea!].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: Sp.sm),
              Wrap(spacing: Sp.xs, runSpacing: Sp.xs, children: [for (final t in tags) TagChip(t)]),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Friendly centred message (empty / error) with an optional action.
class StateMessage extends StatelessWidget {
  const StateMessage({super.key, required this.icon, required this.title, required this.hint, this.actionLabel, this.onAction, this.actionKey});
  final IconData icon;
  final String title, hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: context.cs.onSurfaceVariant),
            const SizedBox(height: Sp.md),
            Text(title, textAlign: TextAlign.center, style: context.tt.titleLarge),
            const SizedBox(height: Sp.sm),
            Text(hint, textAlign: TextAlign.center, style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
            if (actionLabel != null) ...[
              const SizedBox(height: Sp.lg),
              KeyButton(key: actionKey, label: actionLabel!, onPressed: onAction),
            ],
          ]),
        ),
      );
}

/// Two-column staggered layout (alternating photo heights). Not lazy: fine for a few dozen cards.
class _Masonry extends StatelessWidget {
  const _Masonry(this.children);
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    Widget col(int start) => Expanded(
          child: Column(children: [
            for (var i = start; i < children.length; i += 2) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: children[i]),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.lg, Sp.xl),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [col(0), const SizedBox(width: Sp.md), col(1)]),
    );
  }
}

/// Listing results with the three standard states and pull-to-refresh.
class ListingsBody extends StatelessWidget {
  const ListingsBody({super.key, required this.value, required this.onRefresh, required this.emptyTitle, required this.emptyHint, this.retryKey});
  final AsyncValue<List<Listing>> value;
  final Future<void> Function() onRefresh;
  final String emptyTitle, emptyHint;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    Widget fill(Widget w) => SliverFillRemaining(child: w);
    final Widget sliver = value.when(
      skipLoadingOnRefresh: true,
      loading: () => SliverToBoxAdapter(
        child: _Masonry([for (var i = 0; i < 6; i++) ListingCardSkeleton(key: ValueKey('feed.skeleton.$i'))]),
      ),
      error: (e, _) => fill(StateMessage(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load listings",
        hint: e is ApiException ? e.message : 'Something went wrong.',
        actionLabel: 'Try again',
        actionKey: retryKey ?? const ValueKey('feed.retry'),
        onAction: onRefresh,
      )),
      data: (items) => items.isEmpty
          ? fill(StateMessage(icon: Icons.search_off, title: emptyTitle, hint: emptyHint))
          : SliverToBoxAdapter(
              child: _Masonry([for (final (i, l) in items.indexed) Stagger(index: i, child: ListingCard(listing: l))]),
            ),
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [sliver]),
    );
  }
}
