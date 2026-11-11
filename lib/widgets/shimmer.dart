import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Wrap skeleton bones in a [Shimmer] to get one shared light sweep.
/// Reduce-motion: static bones.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;
    final hi = context.keys.skeletonHi;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            colors: [hi.withValues(alpha: 0), hi, hi.withValues(alpha: 0)],
            stops: const [.35, .5, .65],
            transform: _Slide(_c.value),
          ).createShader(r),
          child: child,
        ),
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.t);
  final double t;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 3 - 1.5), 0, 0);
}

/// A flat bone. Place inside a [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});
  final double? width;
  final double height, radius;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.keys.skeleton, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Placeholder for a listing grid card (photo + 2 lines + price).
class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Shimmer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 1, child: SkeletonBox(height: double.infinity, radius: Rad.lg)),
          SizedBox(height: Sp.md),
          SkeletonBox(width: 120),
          SizedBox(height: Sp.sm),
          SkeletonBox(width: 70, height: 18),
        ]),
      );
}

/// Placeholder for a chat / order row (avatar + 2 lines).
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Shimmer(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Sp.sm),
          child: Row(children: [
            SkeletonBox(width: 56, height: 56, radius: Rad.md),
            SizedBox(width: Sp.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 160),
              SizedBox(height: Sp.sm),
              SkeletonBox(),
            ])),
          ]),
        ),
      );
}
