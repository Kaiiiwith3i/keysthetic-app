import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../services/api.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/commerce_ui.dart';
import '../widgets/keycap_card.dart';
import '../widgets/order_parts.dart';
import '../widgets/order_timeline.dart';
import '../widgets/routes.dart';
import '../widgets/snack.dart';
import 'chat_thread_screen.dart';
import 'checkout_screen.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<Order> Function(Api api) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(apiProvider));
      refreshCommerce(ref, widget.orderId);
      await ref.read(orderProvider(widget.orderId).future);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.status == 409) {
        showMessage(context, 'This order has changed. Refreshed to the latest status.');
        refreshCommerce(ref, widget.orderId);
      } else {
        showApiError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('The listing goes back on sale. This cannot be undone.'),
        actions: [
          TextButton(
            key: const ValueKey('order.cancel.dismiss'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            key: const ValueKey('order.cancel.confirm'),
            style: TextButton.styleFrom(foregroundColor: ctx.keys.declined),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _run((a) => a.cancelOrder(widget.orderId));
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: SafeArea(
        child: order.when(
          skipLoadingOnReload: true,
          loading: () => const ListSkeleton(),
          error: (e, _) => MessageState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load this order',
            body: errorText(e),
            actionKey: const ValueKey('order.retry'),
            onAction: () => ref.invalidate(orderProvider(widget.orderId)),
          ),
          data: (o) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(orderProvider(widget.orderId));
              await ref.read(orderProvider(widget.orderId).future);
            },
            child: _body(o),
          ),
        ),
      ),
    );
  }

  Widget _body(Order o) {
    final buyer = isBuyerSide(ref, o.buyer.id, o.seller.id);
    final s = o.status;
    final other = buyer ? o.seller : o.buyer;
    final hint = switch ((buyer, s)) {
      (true, 'accepted') => 'Choose how you will pay and set the meetup.',
      (true, 'meetup_set') => 'Meet the seller and pay in cash. They will mark the item handed over.',
      (true, 'awaiting_payment') => 'Scan the seller\'s QR, pay outside the app, then tap I\'ve paid.',
      (true, 'payment_sent') => 'Waiting for the seller to confirm your payment.',
      (true, 'paid') => 'Payment confirmed. Waiting for the seller to hand over the item.',
      (true, 'handed_over') => 'Got the item? Confirm to complete the order.',
      (false, 'accepted') => 'Waiting for the buyer to check out.',
      (false, 'meetup_set') => 'Meet the buyer, collect cash, then mark the item handed over.',
      (false, 'awaiting_payment') => 'Waiting for the buyer to pay by QR.',
      (false, 'payment_sent') => 'The buyer says they paid. Check your account, then confirm.',
      (false, 'paid') => 'Payment confirmed. Hand over the item at the meetup.',
      (false, 'handed_over') => 'Waiting for the buyer to confirm receipt.',
      (_, 'completed') => 'This order is complete.',
      _ => 'This order was cancelled. The listing is back on sale.',
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Sp.lg),
      children: [
        OrderSummaryCard(
          o,
          trailing: Align(alignment: Alignment.centerLeft, child: StatusChip(s)),
        ),
        const SizedBox(height: Sp.lg),
        Text(
          hint,
          key: const ValueKey('order.hint'),
          style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant),
        ),
        if (buyer && s == 'awaiting_payment' && o.sellerQrUrl != null) ...[
          const SizedBox(height: Sp.lg),
          QrPanel(o.sellerQrUrl!),
        ],
        if ((o.meetupNote ?? '').isNotEmpty) ...[
          const SizedBox(height: Sp.lg),
          KeycapCard(
            padding: const EdgeInsets.all(Sp.md),
            radius: Rad.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, color: context.cs.primary),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meetup', style: context.tt.labelSmall!.copyWith(color: context.cs.onSurfaceVariant)),
                      Text(o.meetupNote!, style: context.tt.bodyMedium),
                      if (o.paymentMethod != null)
                        Text(
                          o.paymentMethod == 'qr' ? 'Paying via QR' : 'Cash on meetup',
                          style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Sp.xl),
        Text('Progress', style: context.tt.titleMedium),
        const SizedBox(height: Sp.md),
        OrderTimeline(o),
        const SizedBox(height: Sp.md),
        ..._actions(o, buyer),
        if (o.threadId != null) ...[
          const SizedBox(height: Sp.md),
          KeyButton(
            key: const ValueKey('order.chat'),
            label: 'Chat with ${other.name}',
            icon: Icons.chat_bubble_outline,
            secondary: true,
            onPressed: () => context.push(ChatThreadScreen(threadId: o.threadId!)),
          ),
        ],
      ],
    );
  }

  List<Widget> _actions(Order o, bool buyer) {
    final s = o.status;
    Widget btn(String k, String label, VoidCallback onTap, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: KeyButton(key: ValueKey(k), label: label, icon: icon, busy: _busy, onPressed: onTap),
    );
    return [
      if (buyer && s == 'accepted')
        btn('order.checkout', 'Checkout', () async {
          await context.push<void>(CheckoutScreen(orderId: o.id));
          if (mounted) refreshCommerce(ref, o.id);
        }, icon: Icons.payments_outlined),
      if (buyer && s == 'awaiting_payment')
        btn('order.paid', 'I\'ve paid', () => _run((a) => a.markPaid(o.id)), icon: Icons.check_circle_outline),
      if (buyer && s == 'handed_over')
        btn(
          'order.complete',
          'Confirm received',
          () => _run((a) => a.completeOrder(o.id)),
          icon: Icons.inventory_2_outlined,
        ),
      if (!buyer && s == 'payment_sent')
        btn(
          'order.confirm_payment',
          'Confirm payment',
          () => _run((a) => a.confirmPayment(o.id)),
          icon: Icons.verified_outlined,
        ),
      if (!buyer && (s == 'meetup_set' || s == 'paid'))
        btn('order.handover', 'Mark handed over', () => _run((a) => a.handover(o.id)), icon: Icons.handshake_outlined),
      if (!{'handed_over', 'completed', 'cancelled'}.contains(s))
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.md),
          child: KeyButton(
            key: const ValueKey('order.cancel'),
            label: 'Cancel order',
            secondary: true,
            onPressed: _busy ? null : _cancel,
          ),
        ),
    ];
  }
}
