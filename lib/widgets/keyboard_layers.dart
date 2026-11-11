import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/tokens.dart';

/// Build slots as named by the API.
enum BuildSlot {
  board,
  switches,
  keycaps,
  stabilizers,
  cable;

  static BuildSlot? fromApi(String s) => values.where((v) => v.name == s).firstOrNull;
}

/// Layout names as in the API enum (`40`, `60`, `65`, `75`, `tkl`, `full`).
enum KbLayout {
  k40('40'),
  k60('60'),
  k65('65'),
  k75('75'),
  tkl('tkl'),
  full('full');

  const KbLayout(this.api);
  final String api;
  static KbLayout fromApi(String? s) => values.firstWhere((l) => l.api == s, orElse: () => KbLayout.k65);
}

@immutable
class KeyboardColorway {
  const KeyboardColorway(this.name, {required this.caseColor, required this.plate, required this.keycap, required this.mod, required this.legend, required this.switchColor});
  final String name;
  final Color caseColor, plate, keycap, mod, legend, switchColor;

  static const carbon = KeyboardColorway('Carbon', caseColor: Color(0xFF2A2A2E), plate: Color(0xFF8D8F96), keycap: Color(0xFF3B3C42), mod: Color(0xFFFF4D1C), legend: Color(0xFFE9E6DD), switchColor: Color(0xFFD7D2C4));
  static const cream = KeyboardColorway('Cream', caseColor: Color(0xFFCFC6B2), plate: Color(0xFFB9B1A0), keycap: Color(0xFFF1EBDD), mod: Color(0xFF8A7F6A), legend: Color(0xFF4A4436), switchColor: Color(0xFFE05A3A));
  static const sakura = KeyboardColorway('Sakura', caseColor: Color(0xFFE9B7C4), plate: Color(0xFFD1A0AE), keycap: Color(0xFFFBE9EE), mod: Color(0xFFD9577E), legend: Color(0xFF7A3B4D), switchColor: Color(0xFFF8F3F0));
  static const terminal = KeyboardColorway('Terminal', caseColor: Color(0xFF14241C), plate: Color(0xFF3E5B4C), keycap: Color(0xFF1F3A2D), mod: Color(0xFF7CFFB0), legend: Color(0xFF7CFFB0), switchColor: Color(0xFFBFE6CF));
  static const presets = [carbon, cream, sakura, terminal];
}

/// Rows of key widths in units (1u = a standard key). Negative = a gap.
List<List<double>> _rows(KbLayout l) {
  const main = <List<double>>[
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
    [1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25],
    [2.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.75],
    [1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25],
  ];
  const fn = <double>[1, -1, 1, 1, 1, 1, -.5, 1, 1, 1, 1, -.5, 1, 1, 1, 1];
  switch (l) {
    case KbLayout.k40:
      return const [
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 2, 2, 1, 1, 1, 1],
      ];
    case KbLayout.k60:
      return main;
    case KbLayout.k65:
      return [for (final r in main) [...r, 1]];
    case KbLayout.k75:
      return [
        List.filled(16, 1.0),
        for (final r in main) [...r, 1],
      ];
    case KbLayout.tkl:
      return [
        [...fn, -.25, 1, 1, 1],
        [...main[0], -.25, 1, 1, 1],
        [...main[1], -.25, 1, 1, 1],
        [...main[2], -.25, 1, 1, 1],
        [...main[3], -1.25, 1],
        [...main[4], -.25, 1, 1, 1],
      ];
    case KbLayout.full:
      return [
        [...fn, -.25, 1, 1, 1, -.25, -4],
        [...main[0], -.25, 1, 1, 1, -.25, 1, 1, 1, 1],
        [...main[1], -.25, 1, 1, 1, -.25, 1, 1, 1, 1],
        [...main[2], -.25, 1, 1, 1, -.25, 1, 1, 1, 1],
        [...main[3], -1.25, 1, -1.25, 1, 1, 1, 1],
        [...main[4], -.25, 1, 1, 1, -.25, 2, 1, 1],
      ];
  }
}

/// Resolved key rectangles in unit space.
class _Geo {
  _Geo(KbLayout layout) {
    final rows = _rows(layout);
    var maxW = 0.0;
    for (var r = 0; r < rows.length; r++) {
      var x = 0.0;
      for (final w in rows[r]) {
        if (w > 0) keys.add(Rect.fromLTWH(x, r.toDouble(), w, 1));
        x += w.abs();
      }
      maxW = math.max(maxW, x);
    }
    width = maxW;
    height = rows.length.toDouble();
  }
  final keys = <Rect>[];
  late final double width, height;
}

enum _Layer { kase, plate, switches, keycaps, stabs, cable }

const _depth = {_Layer.kase: 0.0, _Layer.plate: 7.0, _Layer.stabs: 11.0, _Layer.switches: 15.0, _Layer.keycaps: 30.0, _Layer.cable: 20.0};
const _slotOf = {
  _Layer.kase: BuildSlot.board, _Layer.plate: BuildSlot.board, _Layer.switches: BuildSlot.switches,
  _Layer.keycaps: BuildSlot.keycaps, _Layer.stabs: BuildSlot.stabilizers, _Layer.cable: BuildSlot.cable,
};

/// The build planner centerpiece: a keyboard drawn as exploded layers (case,
/// plate, stabilizers, switches, keycaps, cable). A layer drops in and settles
/// with a spring when its slot is filled, and lifts away when cleared. Drag to
/// tilt (parallax by depth); it springs back on release.
/// Reduce-motion: layers fade, no drop, no tilt.
class KeyboardLayers extends StatefulWidget {
  const KeyboardLayers({
    super.key,
    required this.filled,
    this.layout = KbLayout.k65,
    this.colorway = KeyboardColorway.carbon,
  });

  final Set<BuildSlot> filled;
  final KbLayout layout;
  final KeyboardColorway colorway;

  @override
  State<KeyboardLayers> createState() => _KeyboardLayersState();
}

class _KeyboardLayersState extends State<KeyboardLayers> with TickerProviderStateMixin {
  static const _drop = SpringDescription(mass: 1, stiffness: 140, damping: 11);
  static const _back = SpringDescription(mass: 1, stiffness: 90, damping: 9);

  final _fill = <_Layer, AnimationController>{};
  late final _tx = AnimationController.unbounded(vsync: this, value: 0);
  late final _ty = AnimationController.unbounded(vsync: this, value: 0);
  late _Geo _geo = _Geo(widget.layout);
  // Snapshot, because callers may mutate the same Set instance in place.
  late Set<BuildSlot> _seen = {...widget.filled};

  @override
  void initState() {
    super.initState();
    for (final l in _Layer.values) {
      _fill[l] = AnimationController.unbounded(vsync: this, value: widget.filled.contains(_slotOf[l]) ? 1 : 0);
    }
  }

  @override
  void didUpdateWidget(KeyboardLayers old) {
    super.didUpdateWidget(old);
    if (old.layout != widget.layout) _geo = _Geo(widget.layout);
    final before = _seen;
    _seen = {...widget.filled};
    final reduce = context.reduceMotion;
    var order = 0;
    for (final l in _Layer.values) {
      final c = _fill[l]!;
      final want = widget.filled.contains(_slotOf[l]) ? 1.0 : 0.0;
      final had = before.contains(_slotOf[l]);
      if (had == (want == 1.0)) continue;
      if (reduce) {
        c.animateTo(want, duration: Dur.fast);
      } else {
        // Layers filled together cascade bottom-up.
        final delay = Duration(milliseconds: 70 * order++);
        Future.delayed(delay, () {
          if (!mounted) return;
          c.animateWith(SpringSimulation(want == 1 ? _drop : _back, c.value, want, c.velocity));
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in _fill.values) {
      c.dispose();
    }
    _tx.dispose();
    _ty.dispose();
    super.dispose();
  }

  void _release() {
    for (final c in [_tx, _ty]) {
      c.animateWith(SpringSimulation(_back, c.value, 0, c.velocity));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return Semantics(
      label: 'Keyboard build preview, ${widget.filled.length} of ${BuildSlot.values.length} parts chosen',
      child: LayoutBuilder(builder: (context, cons) {
        final w = cons.hasBoundedWidth ? cons.maxWidth : 320.0;
        final pad = 1.0; // case margin in units
        const head = 1.6; // room above the case for the cable
        final planeW = w * .8;
        final u = planeW / (_geo.width + pad * 2);
        final planeH = u * (_geo.height + pad * 2 + head);
        final boxH = planeH * .72 + 90 * (w / 360);
        final scale = w / 360;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: reduce ? null : (d) {
            _tx.value = (_tx.value + d.delta.dx * .006).clamp(-.6, .6);
            _ty.value = (_ty.value - d.delta.dy * .006).clamp(-.45, .45);
          },
          onPanEnd: reduce ? null : (_) => _release(),
          onPanCancel: reduce ? null : _release,
          child: SizedBox(
            width: w,
            height: boxH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final layer in _Layer.values)
                  _layer(layer, Size(planeW, planeH), u, pad, head, scale, reduce),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _layer(_Layer layer, Size plane, double u, double pad, double head, double scale, bool reduce) {
    final fill = _fill[layer]!;
    final ghostPaint = RepaintBoundary(
      child: CustomPaint(size: plane, painter: _LayerPainter(layer, _geo, widget.colorway, u, pad, head, ghost: true)),
    );
    final solidPaint = RepaintBoundary(
      child: CustomPaint(size: plane, painter: _LayerPainter(layer, _geo, widget.colorway, u, pad, head)),
    );
    Matrix4 at(double z) => Matrix4.identity()
      ..setEntry(3, 2, .0013)
      ..rotateX(.88 + _ty.value)
      ..rotateZ(-.32 + _tx.value)
      ..translateByDouble(0.0, 0.0, z * scale, 1.0);
    return AnimatedBuilder(
      animation: Listenable.merge([fill, _tx, _ty]),
      builder: (_, _) {
        final p = fill.value;
        final solid = p.clamp(0.0, 1.0);
        final rest = _depth[layer]!;
        return Stack(children: [
          // Ghost stays at the layer's resting depth; the solid part drops onto it.
          if (solid < 1) Transform(alignment: Alignment.center, transform: at(rest), child: Opacity(opacity: (1 - solid) * .55, child: ghostPaint)),
          if (solid > 0) Transform(alignment: Alignment.center, transform: at(rest + (reduce ? 0 : (1 - p) * 70)), child: Opacity(opacity: solid, child: solidPaint)),
        ]);
      },
    );
  }
}

class _LayerPainter extends CustomPainter {
  _LayerPainter(this.layer, this.geo, this.cw, this.u, this.pad, this.head, {this.ghost = false});
  final _Layer layer;
  final _Geo geo;
  final KeyboardColorway cw;
  final double u, pad, head;
  final bool ghost;

  Rect _key(Rect k) => Rect.fromLTWH((k.left + pad) * u, (k.top + pad + head) * u, k.width * u, k.height * u);

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, head * u, (geo.width + pad * 2) * u, (geo.height + pad * 2) * u);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = cw.legend.withValues(alpha: .5);
    switch (layer) {
      case _Layer.kase:
        final rr = RRect.fromRectAndRadius(body, Radius.circular(u * .6));
        if (ghost) return _dashed(canvas, rr, line);
        canvas.drawRRect(rr.shift(Offset(0, u * .22)), Paint()..color = Color.alphaBlend(Colors.black38, cw.caseColor));
        canvas.drawRRect(rr, Paint()..color = cw.caseColor);
        canvas.drawRRect(rr.deflate(u * .12), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white24);
      case _Layer.plate:
        final r = RRect.fromRectAndRadius(body.deflate(u * .38), Radius.circular(u * .3));
        if (ghost) return _dashed(canvas, r, line);
        canvas.drawRRect(r, Paint()..color = cw.plate);
        for (final k in geo.keys) {
          canvas.drawRect(_key(k).deflate(u * .26), Paint()..color = Color.alphaBlend(Colors.black45, cw.plate));
        }
      case _Layer.stabs:
        final p = Paint()
          ..color = ghost ? cw.legend.withValues(alpha: .5) : cw.legend
          ..strokeWidth = u * .09
          ..strokeCap = StrokeCap.round;
        final dot = Paint()..color = p.color;
        for (final k in geo.keys.where((k) => k.width >= 2)) {
          final r = _key(k);
          final inset = k.width >= 6 ? r.width * .27 : u * .42;
          final y = r.center.dy + u * .34;
          canvas.drawLine(Offset(r.left + inset, y), Offset(r.right - inset, y), p);
          for (final x in [r.left + inset, r.right - inset]) {
            canvas.drawCircle(Offset(x, y), u * .12, dot);
          }
        }
      case _Layer.switches:
        for (final k in geo.keys) {
          final r = Rect.fromCenter(center: _key(k).center, width: u * .62, height: u * .62);
          if (ghost) {
            canvas.drawRect(r, line..strokeWidth = 1);
          } else {
            canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(u * .1)), Paint()..color = cw.switchColor);
            canvas.drawRect(Rect.fromCenter(center: r.center, width: u * .22, height: u * .22), Paint()..color = Colors.black45);
          }
        }
      case _Layer.keycaps:
        for (final k in geo.keys) {
          final r = _key(k).deflate(u * .06);
          final base = k.width != 1 && k.width < 6 ? cw.mod : cw.keycap; // modifiers get the accent colour
          final rr = RRect.fromRectAndRadius(r, Radius.circular(u * .16));
          if (ghost) {
            canvas.drawRRect(rr, line..strokeWidth = 1);
            continue;
          }
          canvas.drawRRect(rr.shift(Offset(0, u * .1)), Paint()..color = Color.alphaBlend(Colors.black38, base));
          canvas.drawRRect(rr, Paint()..color = base);
          final top = RRect.fromRectAndRadius(r.deflate(u * .12).shift(Offset(0, -u * .03)), Radius.circular(u * .12));
          canvas.drawRRect(top, Paint()..color = Color.alphaBlend(Colors.white.withValues(alpha: .1), base));
          canvas.drawCircle(top.center.translate(-top.width * .2, -top.height * .15), u * .06, Paint()..color = cw.legend.withValues(alpha: .7));
        }
      case _Layer.cable:
        final cx = body.center.dx;
        final plug = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, head * u - u * .1), width: u * 1.1, height: u * .55), Radius.circular(u * .12));
        final path = Path()
          ..moveTo(cx, plug.top)
          ..cubicTo(cx, 0, cx + u * 2.2, u * .5, cx + u * 3.2, 0);
        if (ghost) {
          canvas.drawRRect(plug, line);
          canvas.drawPath(path, line);
        } else {
          canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = u * .2..strokeCap = StrokeCap.round..color = cw.mod);
          canvas.drawRRect(plug, Paint()..color = const Color(0xFFB5B8BF));
          canvas.drawRRect(plug.deflate(u * .12), Paint()..color = const Color(0xFF3A3C42));
        }
    }
  }

  void _dashed(Canvas canvas, RRect rr, Paint p) {
    final path = Path()..addRRect(rr);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 14) {
        canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_LayerPainter o) => o.geo != geo || o.cw != cw || o.u != u || o.ghost != ghost;
}
