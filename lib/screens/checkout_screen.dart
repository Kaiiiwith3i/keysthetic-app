import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/commerce_ui.dart';
import '../widgets/keycap_card.dart';
import '../widgets/order_parts.dart';
import '../widgets/routes.dart';
import '../widgets/snack.dart';
import 'order_detail_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _note = TextEditingController();
  String _method = 'cod';
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Order> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      refreshCommerce(ref, widget.orderId);
      await ref.read(orderProvider(widget.orderId).future);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: order.when(
          skipLoadingOnReload: true,
          loading: () => const ListSkeleton(),
          error: (e, _) => MessageState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load this order',
            body: errorText(e),
            actionKey: const ValueKey('checkout.retry'),
            onAction: () => ref.invalidate(orderProvider(widget.orderId)),
          ),
          data: (o) => ListView(
            padding: const EdgeInsets.all(Sp.lg),
            children: [
              OrderSummaryCard(o),
              const SizedBox(height: Sp.xl),
              ...switch (o.status) {
                'accepted' => _form(o),
                'awaiting_payment' => _payStep(o),
                _ => _done(o),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _form(Order o) {
    final hasQr = o.sellerQrUrl != null;
    return [
      Text('Payment', style: context.tt.titleMedium),
      const SizedBox(height: Sp.md),
      _MethodCard(
        k: 'checkout.method.cod',
        icon: Icons.handshake_outlined,
        title: 'Cash on meetup',
        body: 'Pay the seller in person when you meet.',
        selected: _method == 'cod',
        onTap: () => setState(() => _method = 'cod'),
      ),
      const SizedBox(height: Sp.md),
      _MethodCard(
        k: 'checkout.method.qr',
        icon: Icons.qr_code_2,
        title: 'Pay via seller\'s QR',
        body: hasQr
            ? 'Scan the seller\'s QR with your banking or wallet app.'
            : 'Not available: this seller has not added a payment QR.',
        selected: _method == 'qr' && hasQr,
        onTap: hasQr ? () => setState(() => _method = 'qr') : null,
      ),
      if (_method == 'qr' && hasQr) ...[const SizedBox(height: Sp.lg), QrPanel(o.sellerQrUrl!)],
      const SizedBox(height: Sp.xl),
      TextField(
        key: const ValueKey('checkout.note'),
        controller: _note,
        maxLength: 500,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Meetup note',
          hintText: 'Date, time and place, e.g. Sat 3 PM, Paseo de Santa Rosa',
        ),
      ),
      const SizedBox(height: Sp.md),
      KeyButton(
        key: const ValueKey('checkout.confirm'),
        label: _method == 'qr' && hasQr ? 'Confirm and pay via QR' : 'Confirm cash on meetup',
        busy: _busy,
        onPressed: () => _run(
          () => ref
              .read(apiProvider)
              .checkout(o.id, paymentMethod: hasQr ? _method : 'cod', meetupNote: _note.text.trim()),
        ),
      ),
    ];
  }

  List<Widget> _payStep(Order o) => [
    Text('Pay the seller', style: context.tt.titleMedium),
    const SizedBox(height: Sp.md),
    if (o.sellerQrUrl != null) QrPanel(o.sellerQrUrl!),
    if ((o.meetupNote ?? '').isNotEmpty) ...[
      const SizedBox(height: Sp.lg),
      Text('Meetup: ${o.meetupNote}', style: context.tt.bodyMedium),
    ],
    const SizedBox(height: Sp.xl),
    KeyButton(
      key: const ValueKey('checkout.paid'),
      label: 'I\'ve paid',
      icon: Icons.check_circle_outline,
      busy: _busy,
      onPressed: () => _run(() => ref.read(apiProvider).markPaid(o.id)),
    ),
  ];

  List<Widget> _done(Order o) => [
    KeycapCard(
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 44, color: context.keys.accepted),
          const SizedBox(height: Sp.sm),
          Text(o.status == 'payment_sent' ? 'Payment marked as sent' : 'You\'re all set', style: context.tt.titleLarge),
          const SizedBox(height: Sp.xs),
          StatusChip(o.status),
          const SizedBox(height: Sp.sm),
          Text(
            o.status == 'payment_sent'
                ? 'The seller will confirm your payment, then hand over the item.'
                : (o.meetupNote ?? '').isNotEmpty
                ? 'Meetup: ${o.meetupNote}'
                : 'Arrange the meetup with the seller in chat.',
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant),
          ),
        ],
      ),
    ),
    const SizedBox(height: Sp.lg),
    KeyButton(
      key: const ValueKey('checkout.view_order'),
      label: 'View order',
      onPressed: () => context.push(OrderDetailScreen(orderId: o.id)),
    ),
  ];
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.k,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });
  final String k, title, body;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Opacity(
      opacity: onTap == null ? .55 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.lg + 2),
          border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
        ),
        child: KeycapCard(
          key: ValueKey(k),
          padding: const EdgeInsets.all(Sp.md),
          semanticLabel: '$title. $body',
          onTap: onTap ?? () => showMessage(context, body),
          child: Row(
            children: [
              Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.titleSmall),
                    Text(body, style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
