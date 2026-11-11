import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/legit.dart';
import '../models/listing.dart';
import '../services/api.dart';
import '../services/browse.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/build_sheets.dart';
import '../widgets/fly_to_target.dart';
import '../widgets/hero_tags.dart';
import '../widgets/keycap_card.dart';
import '../widgets/listing_card.dart';
import '../widgets/pressable.dart';
import '../widgets/price_chip.dart';
import '../widgets/routes.dart';
import '../widgets/shimmer.dart';
import '../widgets/snack.dart';
import '../widgets/sound_player.dart';
import 'chat_thread_screen.dart';
import 'checkout_screen.dart';
import 'post_listing_screen.dart';

const _legitDisclaimer = "This compares the seller's answers to published stock specs. It is not proof of authenticity.";

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});
  final int listingId;
  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _photoKey = GlobalKey(debugLabel: 'detail.photo');
  String? _busy; // which action is in flight

  Future<void> _run(String name, Future<void> Function() job) async {
    if (_busy != null) return;
    setState(() => _busy = name);
    try {
      await job();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _refresh() => ref.invalidate(listingProvider(widget.listingId));

  Future<void> _message(Listing l) => _run('message', () async {
        final t = await ref.read(apiProvider).createThread(l.id);
        if (mounted) await context.push(ChatThreadScreen(threadId: t.id));
      });

  Future<void> _offer(Listing l) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _OfferSheet(price: l.price),
    );
    if (amount == null) return;
    await _run('offer', () async {
      final api = ref.read(apiProvider);
      final t = await api.createThread(l.id);
      await api.sendOffer(t.id, amount);
      if (mounted) await context.push(ChatThreadScreen(threadId: t.id));
    });
  }

  Future<void> _buy(Listing l) => _run('buy', () async {
        final o = await ref.read(apiProvider).createOrder(l.id);
        if (!mounted) return;
        await context.push(CheckoutScreen(orderId: o.id));
        _refresh(); // it is reserved now
      });

  Future<void> _addToBuild(Listing l) async {
    final slot = slotOfCategory(l.category);
    if (slot == null) return;
    await _run('build', () async {
      final notifier = ref.read(buildsProvider.notifier);
      final builds = await ref.read(buildsProvider.future);
      if (!mounted) return;
      final pick = await pickBuildForSlot(context, builds, slot, listing: l);
      if (pick == null || !mounted) return;
      var build = pick.build;
      if (pick.create) {
        final name = await promptBuildName(context, title: 'Name your build');
        if (name == null) return;
        build = await notifier.create(name);
      }
      await notifier.setSlot(build!.id, slot, l.id);
      if (!mounted) return;
      showMessage(context, 'Added to ${build.name}');
      if (l.photos.isNotEmpty) await flyToBuild(context, _photoKey, mediaImage(ref, l.photos.first));
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(listingProvider(widget.listingId));
    return Scaffold(
      appBar: AppBar(),
      body: async.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load this listing",
          hint: e is ApiException ? e.message : 'Something went wrong.',
          actionLabel: 'Try again',
          actionKey: const ValueKey('detail.retry'),
          onAction: _refresh,
        ),
        data: _content,
      ),
    );
  }

  Widget _content(Listing l) {
    final session = ref.watch(sessionProvider);
    final mine = session.user?.id == l.seller.id;
    final isBuyer = session.role == 'buyer' && !mine;
    final cs = context.cs, tt = context.tt;
    final tags = [
      if (l.layout != null) layoutLabels[l.layout] ?? l.layout!,
      if (l.connection != null) connectionLabels[l.connection] ?? l.connection!,
      if (l.switchType != null) switchTypeLabels[l.switchType] ?? l.switchType!,
      if (l.stem != null) stemLabels[l.stem] ?? l.stem!,
      if (l.connector != null) connectorLabels[l.connector] ?? l.connector!,
    ];
    final specs = <(String, String)>[
      ('Category', categoryLabels[l.category] ?? l.category),
      ('Condition', conditionLabels[l.condition] ?? l.condition),
      if (l.kind != null) ('Type', l.kind![0].toUpperCase() + l.kind!.substring(1)),
      if (l.layout != null) ('Layout', layoutLabels[l.layout] ?? l.layout!),
      if (l.connection != null) ('Connection', connectionLabels[l.connection] ?? l.connection!),
      if (l.switchType != null) ('Switch feel', switchTypeLabels[l.switchType] ?? l.switchType!),
      if (l.stem != null) ('Stem', stemLabels[l.stem] ?? l.stem!),
      if (l.connector != null) ('Connector', connectorLabels[l.connector] ?? l.connector!),
    ];
    Widget title(String t) => Padding(padding: const EdgeInsets.only(top: Sp.xl, bottom: Sp.sm), child: Text(t, style: tt.titleMedium));
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            _refresh();
            try {
              await ref.read(listingProvider(l.id).future);
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.xl),
            children: [
              _Gallery(key: _photoKey, listing: l),
              const SizedBox(height: Sp.lg),
              Text(l.title, style: tt.headlineSmall),
              const SizedBox(height: Sp.sm),
              Row(children: [
                Text(formatPeso(l.price), style: monoStyle(26, cs.onSurface, w: 800)),
                const SizedBox(width: Sp.md),
                if (l.status != 'active') Flexible(child: PhotoBadge(l.status == 'reserved' ? 'Reserved' : l.status == 'sold' ? 'Sold' : 'Unavailable', color: context.keys.offer)),
              ]),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: Sp.md),
                Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [for (final t in tags) TagChip(t)]),
              ],
              if (l.soundUrl != null) ...[
                title('Hear it first'),
                SoundPlayer(key: ValueKey('detail.sound.${l.id}'), url: l.soundUrl!),
              ],
              title('Specs'),
              KeycapCard(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
                child: Column(children: [
                  for (final (i, s) in specs.indexed) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.$1, style: tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(width: Sp.md),
                        Expanded(child: Text(s.$2, textAlign: TextAlign.end, style: tt.titleSmall)),
                      ]),
                    ),
                  ],
                ]),
              ),
              title('Seller'),
              KeycapCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 22, backgroundColor: cs.primary.withValues(alpha: .15), child: Text(l.seller.name.isEmpty ? '?' : l.seller.name[0].toUpperCase(), style: tt.titleMedium!.copyWith(color: cs.primary))),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.seller.name, style: tt.titleMedium),
                        if (l.seller.area != null) Text(l.seller.area!, style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                  if (l.meetupArea != null) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: Sp.md), child: Divider()),
                    Row(children: [
                      Icon(Icons.place_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: Sp.sm),
                      Expanded(child: Text('Meetup: ${l.meetupArea}', style: tt.bodyMedium)),
                    ]),
                  ],
                ]),
              ),
              if (l.description.isNotEmpty) ...[title('Description'), Text(l.description, style: tt.bodyLarge)],
              if (l.legit != null) ...[title('Legit Check'), _LegitCard(l.legit!)],
              if (mine) ...[
                const SizedBox(height: Sp.xl),
                KeycapCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Icon(Icons.storefront_outlined, color: cs.primary),
                      const SizedBox(width: Sp.md),
                      Expanded(child: Text('This is your listing.', key: const ValueKey('detail.own'), style: tt.titleSmall)),
                    ]),
                    const SizedBox(height: Sp.md),
                    KeyButton(
                      key: const ValueKey('detail.edit'),
                      label: 'Edit listing',
                      icon: Icons.edit_outlined,
                      secondary: true,
                      onPressed: () async {
                        await context.push(PostListingScreen(listing: l));
                        _refresh();
                      },
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
      if (isBuyer)
        _ActionBar(listing: l, busy: _busy, onMessage: () => _message(l), onOffer: () => _offer(l), onBuy: () => _buy(l), onAdd: () => _addToBuild(l)),
    ]);
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.listing, required this.busy, required this.onMessage, required this.onOffer, required this.onBuy, required this.onAdd});
  final Listing listing;
  final String? busy;
  final VoidCallback onMessage, onOffer, onBuy, onAdd;

  @override
  Widget build(BuildContext context) {
    final canAdd = slotOfCategory(listing.category) != null;
    Widget btn(String key, String label, IconData icon, VoidCallback fn, String id, {bool secondary = true}) => Expanded(
          child: KeyButton(key: ValueKey(key), label: label, icon: icon, secondary: secondary, busy: busy == id, onPressed: busy != null && busy != id ? null : fn),
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: context.cs.surface, boxShadow: [BoxShadow(color: context.keys.shadow, blurRadius: 18, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Sp.md),
          child: listing.status != 'active'
              ? Row(children: [
                  Icon(Icons.lock_outline, color: context.cs.onSurfaceVariant),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Text(
                      listing.status == 'reserved' ? 'Reserved: someone has an open order on this.' : 'This listing is no longer available.',
                      key: const ValueKey('detail.unavailable'),
                      style: context.tt.bodyMedium,
                    ),
                  ),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    btn('detail.buy', 'Buy now', Icons.shopping_bag_outlined, onBuy, 'buy', secondary: false),
                    const SizedBox(width: Sp.md),
                    btn('detail.offer', 'Make offer', Icons.local_offer_outlined, onOffer, 'offer'),
                  ]),
                  const SizedBox(height: Sp.md),
                  Row(children: [
                    btn('detail.message', 'Message', Icons.chat_bubble_outline, onMessage, 'message'),
                    if (canAdd) ...[
                      const SizedBox(width: Sp.md),
                      btn('detail.add_to_build', 'Add to build', Icons.keyboard_outlined, onAdd, 'build'),
                    ],
                  ]),
                ]),
        ),
      ),
    );
  }
}

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.price});
  final int price;
  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _c = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _send() {
    final v = int.tryParse(_c.text);
    if (v == null || v < 1 || v > widget.price) {
      setState(() => _error = 'Enter an amount up to ${formatPeso(widget.price)}');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('Make an offer', style: context.tt.titleLarge),
            const SizedBox(height: Sp.xs),
            Text('Asking ${formatPeso(widget.price)}. The seller can accept, counter or decline.', style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
            const SizedBox(height: Sp.lg),
            TextField(
              key: const ValueKey('detail.offer.amount'),
              controller: _c,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(prefixText: '₱ ', hintText: 'Your offer', errorText: _error),
            ),
            const SizedBox(height: Sp.lg),
            KeyButton(key: const ValueKey('detail.offer.send'), label: 'Send offer', onPressed: _send),
          ]),
        ),
      );
}

class _LegitCard extends StatelessWidget {
  const _LegitCard(this.r);
  final LegitResult r;
  @override
  Widget build(BuildContext context) {
    final k = context.keys, tt = context.tt;
    final (color, icon) = switch (r.verdict) {
      'match' => (k.accepted, Icons.check_circle),
      'mods' => (k.offer, Icons.build_circle),
      _ => (k.declined, Icons.warning_rounded),
    };
    return KeycapCard(
      key: const ValueKey('detail.legit'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: Sp.md),
          Expanded(child: Text(r.verdictLabel, style: tt.titleMedium!.copyWith(color: color))),
        ]),
        const SizedBox(height: Sp.md),
        for (final f in r.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: Sp.xs),
            child: Row(children: [
              Expanded(child: Text(f.label, style: tt.bodyMedium)),
              Text(
                switch (f.result) { 'match' => 'Matches', 'mod' => 'Declared mod', 'mismatch' => 'Differs', _ => 'No source' },
                style: tt.labelMedium!.copyWith(color: switch (f.result) { 'match' => k.accepted, 'mod' => k.offer, 'mismatch' => k.declined, _ => context.cs.onSurfaceVariant }),
              ),
            ]),
          ),
        const SizedBox(height: Sp.sm),
        Text(_legitDisclaimer, style: tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// Swipeable photos with a dot indicator; tap opens the full-screen viewer.
class _Gallery extends StatefulWidget {
  const _Gallery({super.key, required this.listing});
  final Listing listing;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final photos = widget.listing.photos;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.xs),
      child: AspectRatio(
        aspectRatio: 1.15,
        child: Stack(children: [
          Positioned.fill(
            child: PageView.builder(
              key: const ValueKey('detail.gallery'),
              itemCount: photos.isEmpty ? 1 : photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final photo = ClipRRect(borderRadius: BorderRadius.circular(Rad.lg), child: ListingPhoto(url: photos.isEmpty ? null : photos[i], cacheWidth: 1000));
                return Pressable(
                  key: ValueKey('detail.photo.$i'),
                  semanticLabel: 'Photo ${i + 1} of ${photos.length}, open full screen',
                  minSize: 0,
                  haptic: false,
                  onTap: photos.isEmpty ? null : () => Navigator.of(context).push(appRoute(_PhotoViewer(photos: photos, start: i))),
                  child: i == 0 ? ListingHero(listingId: widget.listing.id, child: photo) : photo,
                );
              },
            ),
          ),
          if (photos.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: Sp.md,
              child: IgnorePointer(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < photos.length; i++)
                    AnimatedContainer(
                      duration: Dur.base,
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _page ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
                      ),
                    ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.start});
  final List<String> photos;
  final int start;
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late int _i = widget.start;
  late final _page = PageController(initialPage: widget.start);
  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => InteractiveViewer(maxScale: 4, child: ListingPhoto(url: widget.photos[i], fit: BoxFit.contain, cacheWidth: 1600)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Sp.sm),
              child: Row(children: [
                IconButton(
                  key: const ValueKey('detail.viewer.close'),
                  iconSize: 28,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Close',
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text('${_i + 1} / ${widget.photos.length}', style: monoStyle(14, Colors.white)),
                const SizedBox(width: Sp.md),
              ]),
            ),
          ),
        ]),
      );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => const Shimmer(
        child: Padding(
          padding: EdgeInsets.all(Sp.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 1.15, child: SkeletonBox(height: double.infinity, radius: Rad.lg)),
            SizedBox(height: Sp.lg),
            SkeletonBox(width: 260, height: 24),
            SizedBox(height: Sp.md),
            SkeletonBox(width: 120, height: 28),
            SizedBox(height: Sp.xl),
            SkeletonBox(height: 90, radius: Rad.lg),
          ]),
        ),
      );
}
