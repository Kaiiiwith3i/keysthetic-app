import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/tokens.dart';

/// Staggered entrance for list/grid items: fade + small rise, delayed by index.
/// Delay is capped so long lists don't make the tail wait. Reduce-motion: plain short fade.
class Stagger extends StatelessWidget {
  const Stagger({super.key, required this.index, required this.child, this.step = const Duration(milliseconds: 45), this.maxSteps = 5});

  final int index;
  final Widget child;
  final Duration step;
  final int maxSteps;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child.animate().fadeIn(duration: Dur.fast);
    return child
        .animate(delay: step * index.clamp(0, maxSteps))
        .fadeIn(duration: Dur.base, curve: Curves.easeOut)
        .slideY(begin: .12, end: 0, duration: Dur.slow, curve: Curves.easeOutCubic);
  }
}
