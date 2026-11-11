import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Springy press feedback for buttons and cards. No ripple: the child squishes
/// like a keycap and overshoots back. Always >= 48dp, always has semantics.
/// Reduce-motion: no scale, a brief opacity dip instead.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.pressedScale = .95,
    this.minSize = 48,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final String? semanticLabel;
  final double pressedScale, minSize;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  // value 0 = rest, 1 = fully pressed; unbounded so the spring can overshoot.
  late final _c = AnimationController.unbounded(vsync: this, value: 0);
  static const _spring = SpringDescription(mass: 1, stiffness: 520, damping: 17);

  void _to(double target) => _c.animateWith(SpringSimulation(_spring, _c.value, target, _c.velocity));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final reduce = context.reduceMotion;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _to(1) : null,
        onTapUp: enabled ? (_) => _to(0) : null,
        onTapCancel: enabled ? () => _to(0) : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: LayoutBuilder(
          builder: (context, c) => ConstrainedBox(
            constraints: BoxConstraints(minWidth: widget.minSize, minHeight: widget.minSize),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, child) => reduce
                  ? Opacity(opacity: 1 - .15 * _c.value.clamp(0, 1), child: child)
                  : Transform.scale(scale: 1 - (1 - widget.pressedScale) * _c.value, child: child),
              // Shrink-wrap and centre in loose space; fill when the parent is tight (e.g. a stretched column).
              child: ExcludeSemantics(
                child: Align(
                  widthFactor: c.hasTightWidth ? null : 1,
                  heightFactor: c.hasTightHeight ? null : 1,
                  // Infinity clamps to the (tight) incoming size, so a stretched button stays full width.
                  child: SizedBox(width: c.hasTightWidth ? double.infinity : null, height: c.hasTightHeight ? double.infinity : null, child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
