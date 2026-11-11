import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/order.dart';
import '../theme/tokens.dart';
import 'commerce_ui.dart';

class _Step {
  const _Step(this.status, this.label, this.at, this.done);
  final String status, label;
  final String? at;
  final bool done;
}

/// Vertical timeline: offer accepted -> meetup/payment -> handed over -> completed.
/// Timestamps come from [Order.history]; a cancelled order ends in a red step.
/// Dots pop in and the connectors draw down in sequence (reduce-motion: static).
class OrderTimeline extends StatelessWidget {
  const OrderTimeline(this.order, {super.key});
  final Order order;

  List<_Step> _steps() {
    final at = {for (final e in order.history) e.status: e.at};
    bool has(String s) => at.containsKey(s);
    final pay = switch (order.paymentMethod) {
      'qr' => const [
        ('awaiting_payment', 'Checked out, pay by QR'),
        ('payment_sent', 'Payment sent'),
        ('paid', 'Payment confirmed'),
      ],
      'cod' => const [('meetup_set', 'Meetup set')],
      _ => const [('meetup_set', 'Payment or meetup set')],
    };
    final all = [('accepted', 'Offer accepted'), ...pay, ('handed_over', 'Handed over'), ('completed', 'Completed')];
    final steps = [
      for (final (s, l) in all) _Step(s, l, at[s], has(s) || (s == 'meetup_set' && has('awaiting_payment'))),
    ];
    if (order.status != 'cancelled') return steps;
    // Keep what happened, then the cancellation; drop the steps that never will.
    return [...steps.where((s) => s.done), _Step('cancelled', 'Cancelled', at['cancelled'], true)];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    final k = context.keys;
    final reduce = context.reduceMotion;
    final currentIdx = steps.indexWhere((s) => !s.done);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            key: ValueKey('order.step.${steps[i].status}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      _dot(context, steps[i], i == currentIdx, i, reduce),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Center(
                            child: _line(
                              steps[i].done && steps[i + 1].done
                                  ? (steps[i + 1].status == 'cancelled' ? k.declined : k.accepted)
                                  : context.cs.outlineVariant,
                              i,
                              reduce,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Sp.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          style: context.tt.titleSmall!.copyWith(
                            color: steps[i].done || i == currentIdx
                                ? context.cs.onSurface
                                : context.cs.onSurfaceVariant,
                          ),
                        ),
                        if (steps[i].at != null)
                          Text(
                            whenLong(steps[i].at),
                            style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(BuildContext context, _Step s, bool current, int i, bool reduce) {
    final k = context.keys;
    final color = s.status == 'cancelled'
        ? k.declined
        : (s.done ? k.accepted : (current ? k.offer : context.cs.outlineVariant));
    Widget d = Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: s.done ? color : Colors.transparent,
        border: Border.all(color: color, width: 2.5),
      ),
      child: s.done
          ? Icon(s.status == 'cancelled' ? Icons.close : Icons.check, size: 14, color: context.cs.surface)
          : null,
    );
    if (reduce) return d;
    d = d
        .animate(delay: Dur.base * i)
        .scale(begin: const Offset(.3, .3), duration: Dur.slow, curve: Curves.easeOutBack)
        .fadeIn(duration: Dur.base);
    return d;
  }

  Widget _line(Color c, int i, bool reduce) {
    final line = Container(width: 3, color: c);
    if (reduce) return line;
    return line
        .animate(delay: Dur.base * i + Dur.fast)
        .scaleY(begin: 0, end: 1, alignment: Alignment.topCenter, duration: Dur.slow, curve: Curves.easeOutCubic);
  }
}
