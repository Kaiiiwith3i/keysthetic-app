import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum PriceKind { offer, counter, accepted, declined }

String formatPeso(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₱${v < 0 ? '-' : ''}$b';
}

/// Chat price chip. The number counts to its new value when [amount] changes;
/// colour is by [kind]. Reduce-motion: values and colours switch instantly.
class PriceChip extends StatelessWidget {
  const PriceChip({super.key, required this.amount, required this.kind, this.fromZero = true});

  final int amount;
  final PriceKind kind;
  /// Count up from 0 the first time the chip appears.
  final bool fromZero;

  static String label(PriceKind k) => switch (k) {
        PriceKind.offer => 'Offer',
        PriceKind.counter => 'Counter',
        PriceKind.accepted => 'Accepted',
        PriceKind.declined => 'Declined',
      };

  Color _color(KeysColors k) => switch (kind) {
        PriceKind.offer => k.offer,
        PriceKind.counter => k.counter,
        PriceKind.accepted => k.accepted,
        PriceKind.declined => k.declined,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(context.keys);
    final reduce = context.reduceMotion;
    return Semantics(
      label: '${label(kind)} ${formatPeso(amount)}',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : Dur.base,
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(Rad.sm),
            border: Border.all(color: color.withValues(alpha: .55), width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label(kind).toUpperCase(), style: context.tt.labelSmall!.copyWith(color: color, letterSpacing: 1)),
            const SizedBox(width: Sp.sm),
            TweenAnimationBuilder<double>(
              key: ValueKey(fromZero),
              tween: Tween(begin: fromZero && !reduce ? 0 : amount.toDouble(), end: amount.toDouble()),
              duration: reduce ? Duration.zero : const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(
                formatPeso(v.round()),
                style: monoStyle(16, color, w: 700).copyWith(
                  decoration: kind == PriceKind.declined ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
