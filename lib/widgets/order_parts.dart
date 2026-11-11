import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'commerce_ui.dart';
import 'keycap_card.dart';
import 'price_chip.dart';

/// Photo, title, agreed price, seller and meetup area.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard(this.order, {super.key, this.trailing});
  final Order order;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final muted = context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant);
    return KeycapCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingThumb(order.listing.photo, size: 72),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
                const SizedBox(height: Sp.xs),
                Text(formatPeso(order.price), style: monoStyle(20, context.cs.primary, w: 800)),
                if (order.price != order.listing.price) Text('Asking ${formatPeso(order.listing.price)}', style: muted),
                const SizedBox(height: Sp.xs),
                Text('Seller: ${order.seller.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                if (order.seller.area != null) Text('Meetup area: ${order.seller.area}', style: muted),
                if (trailing != null) ...[const SizedBox(height: Sp.sm), trailing!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The seller's payment QR, large, with the "outside the app" disclaimer.
class QrPanel extends ConsumerWidget {
  const QrPanel(this.url, {super.key});
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Container(
        key: const ValueKey('order.qr'),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: context.keys.capLip),
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image(
            image: mediaImage(ref, url),
            fit: BoxFit.contain,
            semanticLabel: 'Seller payment QR code',
            errorBuilder: (_, _, _) => const Center(child: Icon(Icons.qr_code_2, size: 64, color: Colors.black38)),
          ),
        ),
      ),
      const SizedBox(height: Sp.md),
      Text(
        'Pay outside the app, then tap I\'ve paid. Keysthetic never processes money.',
        textAlign: TextAlign.center,
        style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant),
      ),
    ],
  );
}
