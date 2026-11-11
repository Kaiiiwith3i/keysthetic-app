import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/thread.dart';
import '../theme/tokens.dart';
import 'commerce_ui.dart';
import 'keycap_card.dart';
import 'price_chip.dart';

/// How an offer/counter card ended up (derived from later messages).
enum OfferState { pending, accepted, declined, replaced }

/// One chat message. Text -> bubble; offer/counter -> card with an animated
/// [PriceChip] (+ Accept/Decline when [onAccept] is given); accept/decline ->
/// centred chip; system -> centred subdued line.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.offerState = OfferState.pending,
    this.onAccept,
    this.onDecline,
    this.busy = false,
    this.animate = false,
  });

  final Message message;
  final bool mine, animate, busy;
  final OfferState offerState;
  final VoidCallback? onAccept, onDecline;

  @override
  Widget build(BuildContext context) {
    final w = _content(context);
    if (!animate) return w;
    if (context.reduceMotion) return w.animate().fadeIn(duration: Dur.fast);
    return w
        .animate()
        .fadeIn(duration: Dur.base)
        .slideY(begin: .15, end: 0, duration: Dur.slow, curve: Curves.easeOutCubic);
  }

  Widget _content(BuildContext context) {
    final m = message;
    final tt = context.tt;
    final muted = tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant);
    switch (m.kind) {
      case 'system':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.sm, horizontal: Sp.xl),
          child: Text(m.body ?? '', textAlign: TextAlign.center, style: muted),
        );
      case 'accept':
      case 'decline':
        final ok = m.kind == 'accept';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.sm),
          child: Center(
            child: m.amount != null
                ? PriceChip(amount: m.amount!, kind: ok ? PriceKind.accepted : PriceKind.declined)
                : Text(ok ? 'Offer accepted' : 'Offer declined', style: muted),
          ),
        );
      case 'offer':
      case 'counter':
        return _offerCard(context);
      default:
        final cs = context.cs;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: Sp.xs),
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm + 2),
            decoration: BoxDecoration(
              color: mine ? cs.primary : context.keys.capTop,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(Rad.md),
                topRight: const Radius.circular(Rad.md),
                bottomLeft: Radius.circular(mine ? Rad.md : 4),
                bottomRight: Radius.circular(mine ? 4 : Rad.md),
              ),
              border: mine ? null : Border(bottom: BorderSide(color: context.keys.capLip, width: 2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.body ?? '', style: tt.bodyMedium!.copyWith(color: mine ? cs.onPrimary : cs.onSurface)),
                const SizedBox(height: 2),
                Text(
                  whenShort(m.createdAt),
                  style: tt.labelSmall!.copyWith(
                    color: (mine ? cs.onPrimary : cs.onSurfaceVariant).withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _offerCard(BuildContext context) {
    final m = message;
    final isCounter = m.kind == 'counter';
    final kind = switch (offerState) {
      OfferState.accepted => PriceKind.accepted,
      OfferState.declined => PriceKind.declined,
      OfferState.pending || OfferState.replaced => isCounter ? PriceKind.counter : PriceKind.offer,
    };
    final tt = context.tt;
    final sub = switch (offerState) {
      OfferState.pending => mine ? 'Waiting for a reply' : null,
      OfferState.replaced => 'Replaced by a newer offer',
      OfferState.declined => 'Declined',
      OfferState.accepted => 'Accepted',
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .86),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.xs),
          child: KeycapCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: offerState == OfferState.replaced ? .5 : 1,
                  child: PriceChip(amount: m.amount ?? 0, kind: kind),
                ),
                if (m.body != null && m.body!.isNotEmpty) ...[
                  const SizedBox(height: Sp.sm),
                  Text(m.body!, style: tt.bodyMedium),
                ],
                const SizedBox(height: Sp.xs),
                Text(
                  [whenShort(m.createdAt), ?sub].join(' · '),
                  style: tt.labelSmall!.copyWith(color: context.cs.onSurfaceVariant),
                ),
                if (onAccept != null) ...[
                  const SizedBox(height: Sp.md),
                  Row(
                    children: [
                      Expanded(
                        child: KeyButton(
                          key: const ValueKey('chat.accept'),
                          label: 'Accept',
                          busy: busy,
                          onPressed: onAccept,
                        ),
                      ),
                      const SizedBox(width: Sp.sm),
                      Expanded(
                        child: KeyButton(
                          key: const ValueKey('chat.decline'),
                          label: 'Decline',
                          secondary: true,
                          onPressed: busy ? null : onDecline,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
