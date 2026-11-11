import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Anchor for the Build tab icon in the bottom nav, plus the "landed" signal
/// its [LandingBounce] listens to.
class BuildNavAnchor {
  static final key = GlobalKey(debugLabel: 'nav.build.icon');
  static final landed = ValueNotifier<int>(0);
}

/// Flies a thumbnail from the widget behind [fromKey] into the Build nav icon
/// (or [targetKey]), then bumps [landed] so the icon bounces.
/// Reduce-motion: no flight; the icon is notified straight away.
Future<void> flyToBuild(
  BuildContext context,
  GlobalKey fromKey,
  ImageProvider image, {
  GlobalKey? targetKey,
  ValueNotifier<int>? landed,
}) async {
  final done = landed ?? BuildNavAnchor.landed;
  final from = _rectOf(fromKey);
  final to = _rectOf(targetKey ?? BuildNavAnchor.key);
  if (from == null || to == null || context.reduceMotion) {
    done.value++;
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Flight(from: from, to: to, image: image, onDone: () {
        entry.remove();
        done.value++;
      }));
  overlay.insert(entry);
}

Rect? _rectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _Flight extends StatefulWidget {
  const _Flight({required this.from, required this.to, required this.image, required this.onDone});
  final Rect from, to;
  final ImageProvider image;
  final VoidCallback onDone;
  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.from.center, b = widget.to.center;
    final ctrl = Offset((a.dx + b.dx) / 2, math.min(a.dy, b.dy) - 140); // arc apex
    final startSize = math.min(widget.from.width, widget.from.height);
    const endSize = 26.0;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final p = Offset(
            math.pow(1 - t, 2) * a.dx + 2 * (1 - t) * t * ctrl.dx + t * t * b.dx,
            math.pow(1 - t, 2) * a.dy + 2 * (1 - t) * t * ctrl.dy + t * t * b.dy,
          );
          final size = startSize + (endSize - startSize) * t;
          return Stack(children: [
            Positioned(
              left: p.dx - size / 2,
              top: p.dy - size / 2,
              width: size,
              height: size,
              child: Opacity(
                opacity: 1 - math.pow(t, 6).toDouble() * .3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Rad.sm + 6 * (1 - t)),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 6))],
                    image: DecorationImage(image: widget.image, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Wrap the target icon: bounces whenever [landed] changes.
class LandingBounce extends StatefulWidget {
  const LandingBounce({super.key, required this.child, this.landed});
  final Widget child;
  final ValueNotifier<int>? landed;
  @override
  State<LandingBounce> createState() => _LandingBounceState();
}

class _LandingBounceState extends State<LandingBounce> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final ValueNotifier<int> _n = widget.landed ?? BuildNavAnchor.landed;

  void _go() {
    if (!context.reduceMotion) _c.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _n.addListener(_go);
  }

  @override
  void dispose() {
    _n.removeListener(_go);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final t = _c.value;
          // 1 -> 1.45 -> 1 with a springy tail
          final s = t == 0 ? 1.0 : 1 + .45 * math.sin(t * math.pi) * math.pow(1 - t, 1.2);
          return Transform.scale(scale: s, child: child);
        },
      );
}
