import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bar waveform for audio playback. Bars bob while [playing]; bars left of
/// [progress] (0..1) are filled with the accent. Reduce-motion: static bars.
class Waveform extends StatefulWidget {
  const Waveform({super.key, this.progress = 0, this.playing = false, this.bars = 36, this.height = 48, this.seed = 7});

  final double progress;
  final bool playing;
  final int bars, seed;
  final double height;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Waveform old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.playing && !context.reduceMotion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      label: 'Audio waveform, ${(widget.progress * 100).round()} percent played',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _WavePainter(_c, widget.progress, widget.bars, widget.seed, cs.primary, cs.outline),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.anim, this.progress, this.n, this.seed, this.on, this.off) : super(repaint: anim);
  final Animation<double> anim;
  final double progress;
  final int n, seed;
  final Color on, off;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / n;
    final w = math.max(2.0, slot * .55);
    final rnd = math.Random(seed);
    final t = anim.value * math.pi * 2;
    for (var i = 0; i < n; i++) {
      final base = .25 + rnd.nextDouble() * .75;
      final bob = anim.isAnimating ? .8 + .2 * math.sin(t + i * .7) : 1.0;
      final h = math.max(4.0, size.height * base * bob);
      final x = slot * i + (slot - w) / 2;
      final filled = (i + .5) / n <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, (size.height - h) / 2, w, h), Radius.circular(w / 2)),
        Paint()..color = filled ? on : off,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.progress != progress || o.n != n || o.on != on || o.off != off;
}
