import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/commerce_ui.dart';
import '../widgets/keycap_card.dart';
import '../widgets/price_chip.dart';
import '../widgets/routes.dart';
import '../widgets/stagger.dart';
import 'order_detail_screen.dart';

/// Buyers see what they bought; sellers get a Buying / Selling switch (default Selling).
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _side = 'seller';

  @override
  Widget build(BuildContext context) {
    final isSeller = ref.watch(sessionProvider.select((s) => s.role)) == 'seller';
    final side = isSeller ? _side : 'buyer';
    final orders = ref.watch(ordersProvider(side));
    final pushed = Navigator.of(context).canPop();
    final title = isSeller ? 'Orders' : 'My orders';
    return Scaffold(
      appBar: pushed ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!pushed)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.sm),
                child: Text(title, style: context.tt.headlineMedium),
              ),
            if (isSeller)
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.sm),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
                  segments: const [
                    ButtonSegment(
                      value: 'buyer',
                      label: Text('Buying', key: ValueKey('orders.seg.buying')),
                    ),
                    ButtonSegment(
                      value: 'seller',
                      label: Text('Selling', key: ValueKey('orders.seg.selling')),
                    ),
                  ],
                  selected: {_side},
                  onSelectionChanged: (s) => setState(() => _side = s.first),
                ),
              ),
            Expanded(
              child: orders.when(
                skipLoadingOnReload: true,
                loading: () => const ListSkeleton(),
                error: (e, _) => MessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load orders',
                  body: errorText(e),
                  actionKey: const ValueKey('orders.retry'),
                  onAction: () => ref.invalidate(ordersProvider),
                ),
                data: (list) {
                  final sorted = [...list]..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(ordersProvider);
                      await ref.read(ordersProvider(side).future);
                    },
                    child: sorted.isEmpty
                        ? MessageState(
                            icon: Icons.receipt_long_outlined,
                            title: side == 'seller' ? 'No sales yet' : 'No orders yet',
                            body: side == 'seller'
                                ? 'When a buyer\'s offer is accepted, the order shows up here.'
                                : 'Orders you place or whose offers get accepted will show up here.',
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xl),
                            itemCount: sorted.length,
                            separatorBuilder: (_, _) => const SizedBox(height: Sp.md),
                            itemBuilder: (_, i) => Stagger(index: i, child: _OrderRow(sorted[i], side)),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  const _OrderRow(this.o, this.side);
  final Order o;
  final String side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant);
    return KeycapCard(
      key: ValueKey('orders.row.${o.id}'),
      padding: const EdgeInsets.all(Sp.md),
      semanticLabel: 'Order ${o.listing.title}, ${statusLabel(o.status)}',
      onTap: () async {
        await context.push(OrderDetailScreen(orderId: o.id));
        if (context.mounted) ref.invalidate(ordersProvider);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingThumb(o.listing.photo, size: 64),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
                Text(
                  '${side == 'seller' ? 'Buyer' : 'Seller'}: ${side == 'seller' ? o.buyer.name : o.seller.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                const SizedBox(height: Sp.sm),
                Wrap(
                  spacing: Sp.sm,
                  runSpacing: Sp.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(formatPeso(o.price), style: monoStyle(16, context.cs.onSurface, w: 700)),
                    StatusChip(o.status),
                    Text(whenShort(o.createdAt), style: muted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
