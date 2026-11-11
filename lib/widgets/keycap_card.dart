import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// The base surface: a keycap-like card with a lit top edge, a darker "lip"
/// along the bottom and a soft drop shadow. Pass [onTap] to make it pressable.
class KeycapCard extends StatelessWidget {
  const KeycapCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Sp.lg),
    this.radius = Rad.lg,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = context.keys;
    final r = BorderRadius.circular(radius);
    final card = RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [k.capTop, k.capBottom]),
          border: Border(bottom: BorderSide(color: k.capLip, width: 3)),
          boxShadow: [BoxShadow(color: k.shadow, blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, minSize: 0, child: card);
  }
}

/// Filled accent button in the same keycap idiom. [label] is the visible text.
class KeyButton extends StatelessWidget {
  const KeyButton({super.key, required this.label, required this.onPressed, this.icon, this.secondary = false, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary, busy;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final k = context.keys;
    final dark = cs.brightness == Brightness.dark;
    final bg = secondary ? (dark ? const Color(0xFF3C382F) : k.capTop) : cs.primary;
    final fg = secondary ? cs.onSurface : cs.onPrimary;
    final lip = secondary ? (dark ? const Color(0xFF0E0D0A) : k.capLip) : Color.alphaBlend(Colors.black.withValues(alpha: .28), cs.primary);
    final enabled = onPressed != null && !busy;
    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      minSize: 52,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border(bottom: BorderSide(color: lip, width: 4)),
            boxShadow: [BoxShadow(color: k.shadow, blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
              else if (icon != null)
                Icon(icon, size: 20, color: fg),
              if (busy || icon != null) const SizedBox(width: Sp.sm),
              Flexible(child: Text(label, textAlign: TextAlign.center, style: context.tt.labelLarge!.copyWith(color: fg, fontSize: 15))),
            ],
          ),
        ),
      ),
    );
  }
}
