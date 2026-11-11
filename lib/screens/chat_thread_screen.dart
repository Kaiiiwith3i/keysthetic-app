import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thread.dart';
import '../services/api.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/amount_sheet.dart';
import '../widgets/commerce_ui.dart';
import '../widgets/keycap_card.dart';
import '../widgets/message_bubble.dart';
import '../widgets/price_chip.dart';
import '../widgets/routes.dart';
import '../widgets/snack.dart';
import 'checkout_screen.dart';
import 'listing_detail_screen.dart';
import 'order_detail_screen.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.threadId});
  final int threadId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  Thread? _thread;
  List<Message> _msgs = const [];
  Object? _error;
  Timer? _timer;
  bool _polling = false, _busy = false;
  int _seenUpTo = 0; // messages with a higher id arrived live and animate in

  Api get _api => ref.read(apiProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _startPolling();
      _poll();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([_api.thread(widget.threadId), _api.messages(widget.threadId)]);
      if (!mounted) return;
      final msgs = r[1] as List<Message>;
      setState(() {
        _thread = r[0] as Thread;
        _msgs = msgs;
        _seenUpTo = msgs.isEmpty ? 0 : msgs.last.id;
      });
      _startPolling();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  /// Fetch anything newer than the last message; refresh the thread when something arrived.
  Future<void> _poll() async {
    if (_polling || _thread == null || !mounted) return;
    _polling = true;
    try {
      final fresh = await _api.messages(widget.threadId, after: _msgs.isEmpty ? null : _msgs.last.id);
      if (!mounted || fresh.isEmpty) return;
      final t = await _api.thread(widget.threadId);
      if (!mounted) return;
      setState(() {
        _merge(fresh);
        _thread = t;
      });
      refreshCommerce(ref);
    } catch (_) {
      // Transient network error: the next tick tries again.
    } finally {
      _polling = false;
    }
  }

  void _merge(List<Message> add) {
    final have = {for (final m in _msgs) m.id};
    _msgs = [..._msgs, ...add.where((m) => !have.contains(m.id))]..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Runs a write, then pulls the messages and thread it changed.
  Future<void> _act(Future<void> Function() write, {String? conflict}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await write();
      final fresh = await _api.messages(widget.threadId, after: _msgs.isEmpty ? null : _msgs.last.id);
      final t = await _api.thread(widget.threadId);
      if (!mounted) return;
      setState(() {
        _merge(fresh);
        _thread = t;
      });
      refreshCommerce(ref);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.status == 409 && conflict != null) {
        showMessage(context, conflict);
        _poll();
        _api.thread(widget.threadId).then((t) => mounted ? setState(() => _thread = t) : null, onError: (_) {});
      } else {
        showApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await _act(() async {
      final m = await _api.sendMessage(widget.threadId, text);
      _merge([m]);
      _input.clear();
    });
  }

  Future<void> _offer(bool buyer) async {
    final amount = await showAmountSheet(
      context,
      title: buyer ? 'Make an offer' : 'Send a counter',
      cta: buyer ? 'Offer' : 'Counter',
      hint: _thread?.listing.price,
    );
    if (amount == null || !mounted) return;
    await _act(
      () async => _merge([await _api.sendOffer(widget.threadId, amount)]),
      conflict: 'This chat already has an order, so offers are closed.',
    );
  }

  Future<void> _accept() => _act(() async {
    final r = await _api.acceptOffer(widget.threadId);
    _merge([r.message]);
  }, conflict: 'That offer is no longer pending. The other side may have changed it.');

  Future<void> _decline() => _act(
    () async => _merge([await _api.declineOffer(widget.threadId)]),
    conflict: 'That offer is no longer pending.',
  );

  OfferState _stateOf(int i) {
    for (var j = i + 1; j < _msgs.length; j++) {
      switch (_msgs[j].kind) {
        case 'accept':
          return OfferState.accepted;
        case 'decline':
          return OfferState.declined;
        case 'offer' || 'counter':
          return OfferState.replaced;
      }
    }
    return _thread?.pendingOffer?.id == _msgs[i].id ? OfferState.pending : OfferState.replaced;
  }

  @override
  Widget build(BuildContext context) {
    final t = _thread;
    final uid = ref.watch(sessionProvider.select((s) => s.user?.id));
    final buyer = t == null ? true : isBuyerSide(ref, t.buyer.id, t.seller.id);
    final other = t == null ? null : (buyer ? t.seller : t.buyer);
    return Scaffold(
      appBar: AppBar(title: Text(other?.name ?? 'Chat', overflow: TextOverflow.ellipsis)),
      body: t == null
          ? (_error != null
                ? MessageState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not open this chat',
                    body: errorText(_error!),
                    actionKey: const ValueKey('chat.retry'),
                    onAction: _load,
                  )
                : const ListSkeleton())
          : SafeArea(
              child: Column(
                children: [
                  _ListingStrip(t),
                  Expanded(child: _messages(t, uid, buyer)),
                  if (t.orderId != null) _OrderBanner(t.orderId!, buyer),
                  _composer(t, buyer),
                ],
              ),
            ),
    );
  }

  Widget _messages(Thread t, int? uid, bool buyer) {
    if (_msgs.isEmpty) {
      return MessageState(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        body: buyer ? 'Ask about the part, or make an offer.' : 'No messages yet.',
      );
    }
    return ListView.builder(
      key: const ValueKey('chat.messages'),
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
      itemCount: _msgs.length,
      itemBuilder: (_, r) {
        final i = _msgs.length - 1 - r;
        final m = _msgs[i];
        final mine = m.senderId != null && m.senderId == uid;
        final state = m.kind == 'offer' || m.kind == 'counter' ? _stateOf(i) : OfferState.pending;
        final canRespond = state == OfferState.pending && !mine && t.orderId == null;
        return MessageBubble(
          key: ValueKey('chat.msg.${m.id}'),
          message: m,
          mine: mine,
          offerState: state,
          busy: _busy,
          animate: m.id > _seenUpTo,
          onAccept: canRespond ? _accept : null,
          onDecline: canRespond ? _decline : null,
        );
      },
    );
  }

  Widget _composer(Thread t, bool buyer) {
    final canOffer = t.orderId == null && t.listing.status == 'active';
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.sm),
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(top: BorderSide(color: context.cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canOffer)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm),
              child: OutlinedButton.icon(
                key: const ValueKey('chat.offer'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _busy ? null : () => _offer(buyer),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: Text(buyer ? 'Make offer' : 'Counter'),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chat.input'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Message', counterText: ''),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: Sp.sm),
              IconButton.filled(
                key: const ValueKey('chat.send'),
                tooltip: 'Send',
                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListingStrip extends ConsumerWidget {
  const _ListingStrip(this.t);
  final Thread t;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.sm),
    child: KeycapCard(
      key: const ValueKey('chat.listing'),
      padding: const EdgeInsets.all(Sp.sm),
      radius: Rad.md,
      semanticLabel: 'Open listing ${t.listing.title}',
      onTap: () => context.push(ListingDetailScreen(listingId: t.listing.id)),
      child: Row(
        children: [
          ListingThumb(t.listing.photo, size: 44),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Text(t.listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
          ),
          const SizedBox(width: Sp.sm),
          Text(formatPeso(t.listing.price), style: monoStyle(14, context.cs.onSurface, w: 700)),
          Icon(Icons.chevron_right, color: context.cs.onSurfaceVariant),
        ],
      ),
    ),
  );
}

/// Shown once the thread has an order: where to go next.
class _OrderBanner extends ConsumerWidget {
  const _OrderBanner(this.orderId, this.buyer);
  final int orderId;
  final bool buyer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId)).value;
    final checkout = buyer && order?.status == 'accepted';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.sm),
      child: KeycapCard(
        padding: const EdgeInsets.all(Sp.md),
        radius: Rad.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderId${order == null ? '' : ' at ${formatPeso(order.price)}'}',
                    style: context.tt.titleSmall,
                  ),
                ),
                if (order != null) StatusChip(order.status),
              ],
            ),
            const SizedBox(height: Sp.sm),
            KeyButton(
              key: ValueKey(checkout ? 'chat.checkout' : 'chat.view_order'),
              label: checkout ? 'Go to checkout' : 'View order',
              onPressed: order == null
                  ? null
                  : () async {
                      await context.push<void>(
                        checkout ? CheckoutScreen(orderId: orderId) : OrderDetailScreen(orderId: orderId),
                      );
                      if (context.mounted) refreshCommerce(ref, orderId);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
