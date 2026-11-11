import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/tokens.dart';

/// Reveals [children] one after another (Legit Check result fields): each
/// slides in from the left with a fade. Give it a new `Key` to replay.
/// Reduce-motion: all children fade in together.
class RevealList extends StatelessWidget {
  const RevealList({super.key, required this.children, this.step = const Duration(milliseconds: 160), this.gap = Sp.sm});

  final List<Widget> children;
  final Duration step;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == children.length - 1 ? 0 : gap),
            child: reduce
                ? children[i].animate().fadeIn(duration: Dur.fast)
                : children[i]
                    .animate(delay: step * i)
                    .fadeIn(duration: Dur.base)
                    .slideX(begin: -.08, end: 0, duration: Dur.slow, curve: Curves.easeOutCubic),
          ),
      ],
    );
  }
}
