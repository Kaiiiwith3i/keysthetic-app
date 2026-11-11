import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/fly_to_target.dart';
import '../widgets/hero_tags.dart';
import '../widgets/keyboard_layers.dart';
import '../widgets/keycap_card.dart';
import '../widgets/pressable.dart';
import '../widgets/price_chip.dart';
import '../widgets/reveal_list.dart';
import '../widgets/routes.dart';
import '../widgets/shimmer.dart';
import '../widgets/stagger.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/waveform.dart';

// Fake 1x1 orange PNG so the fly demo needs no asset.
final _demoThumb = MemoryImage(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP47ysDAAO3AWlCBiukAAAAAElFTkSuQmCC'));

/// Every motion widget in isolation. Debug-ish; reached from Profile.
class MotionLabScreen extends StatefulWidget {
  const MotionLabScreen({super.key});
  @override
  State<MotionLabScreen> createState() => _MotionLabScreenState();
}

class _MotionLabScreenState extends State<MotionLabScreen> {
  bool _reduce = false;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: _reduce),
      child: Scaffold(
        appBar: AppBar(title: const Text('Motion lab')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.xxl),
          children: [
            SwitchListTile(
              key: const ValueKey('lab.reduce'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulate reduce-motion'),
              value: _reduce,
              onChanged: (v) => setState(() => _reduce = v),
            ),
            const _Section('Pressable + KeyButton', _PressDemo()),
            const _Section('Stagger', _StaggerDemo()),
            const _Section('Shimmer skeletons', _ShimmerDemo()),
            const _Section('Hero (listing-photo-<id>)', _HeroDemo()),
            const _Section('FlyToTarget', _FlyDemo()),
            const _Section('PriceChip', _PriceDemo()),
            const _Section('Waveform', _WaveDemo()),
            const _Section('KeyboardLayers', _KeyboardDemo()),
            const _Section('RevealList', _RevealDemo()),
            const _Section('Theme toggle', ThemeToggle()),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Sp.lg),
        child: KeycapCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: context.tt.titleMedium),
            const SizedBox(height: Sp.md),
            child,
          ]),
        ),
      );
}

class _PressDemo extends StatelessWidget {
  const _PressDemo();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KeyButton(label: 'Press me', icon: Icons.touch_app, onPressed: () {}),
        const SizedBox(height: Sp.md),
        KeyButton(label: 'Secondary', secondary: true, onPressed: () {}),
        const SizedBox(height: Sp.md),
        KeycapCard(onTap: () {}, semanticLabel: 'Pressable card', child: const Text('Pressable card')),
      ]);
}

class _StaggerDemo extends StatefulWidget {
  const _StaggerDemo();
  @override
  State<_StaggerDemo> createState() => _StaggerDemoState();
}

class _StaggerDemoState extends State<_StaggerDemo> {
  int _run = 0;
  @override
  Widget build(BuildContext context) => Column(children: [
        KeyedSubtree(
          key: ValueKey(_run),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Sp.sm,
            crossAxisSpacing: Sp.sm,
            children: [
              for (var i = 0; i < 8; i++)
                Stagger(index: i, child: DecoratedBox(decoration: BoxDecoration(color: context.cs.primary.withValues(alpha: .15 + i * .1), borderRadius: BorderRadius.circular(Rad.sm)))),
            ],
          ),
        ),
        const SizedBox(height: Sp.sm),
        KeyButton(label: 'Replay', secondary: true, onPressed: () => setState(() => _run++)),
      ]);
}

class _ShimmerDemo extends StatelessWidget {
  const _ShimmerDemo();
  @override
  Widget build(BuildContext context) => const Column(children: [
        Row(children: [Expanded(child: ListingCardSkeleton()), SizedBox(width: Sp.md), Expanded(child: ListingCardSkeleton())]),
        SizedBox(height: Sp.md),
        ListRowSkeleton(),
      ]);
}

class _HeroDemo extends StatelessWidget {
  const _HeroDemo();
  @override
  Widget build(BuildContext context) => Row(children: [
        Pressable(
          key: const ValueKey('lab.hero'),
          semanticLabel: 'Open hero demo',
          onTap: () => context.push(const _HeroDetail()),
          child: ListingHero(listingId: 0, child: Container(width: 96, height: 96, decoration: BoxDecoration(color: context.cs.primary, borderRadius: BorderRadius.circular(Rad.md)))),
        ),
        const SizedBox(width: Sp.lg),
        const Expanded(child: Text('Tap the tile: it grows into the detail page.')),
      ]);
}

class _HeroDetail extends StatelessWidget {
  const _HeroDetail();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail')),
        body: Align(
          alignment: Alignment.topCenter,
          child: AspectRatio(
            aspectRatio: 1,
            child: ListingHero(listingId: 0, child: Container(margin: const EdgeInsets.all(Sp.lg), decoration: BoxDecoration(color: context.cs.primary, borderRadius: BorderRadius.circular(Rad.lg)))),
          ),
        ),
      );
}

class _FlyDemo extends StatefulWidget {
  const _FlyDemo();
  @override
  State<_FlyDemo> createState() => _FlyDemoState();
}

class _FlyDemoState extends State<_FlyDemo> {
  final _from = GlobalKey(), _to = GlobalKey();
  final _landed = ValueNotifier<int>(0);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(key: _from, width: 72, height: 72, decoration: BoxDecoration(image: DecorationImage(image: _demoThumb, fit: BoxFit.cover), borderRadius: BorderRadius.circular(Rad.md))),
        const SizedBox(width: Sp.md),
        Expanded(child: KeyButton(key: const ValueKey('lab.fly'), label: 'Add to build', icon: Icons.add, onPressed: () => flyToBuild(context, _from, _demoThumb, targetKey: _to, landed: _landed))),
        const SizedBox(width: Sp.lg),
        LandingBounce(landed: _landed, child: Icon(Icons.keyboard, key: _to, size: 32, color: context.cs.primary)),
      ]);
}

class _PriceDemo extends StatefulWidget {
  const _PriceDemo();
  @override
  State<_PriceDemo> createState() => _PriceDemoState();
}

class _PriceDemoState extends State<_PriceDemo> {
  static const _amounts = [4000, 4300, 4500, 3800];
  int _i = 0;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: Sp.sm, runSpacing: Sp.sm, children: [
          PriceChip(amount: _amounts[_i], kind: PriceKind.offer),
          PriceChip(amount: _amounts[(_i + 1) % 4], kind: PriceKind.counter),
          PriceChip(amount: _amounts[(_i + 2) % 4], kind: PriceKind.accepted),
          PriceChip(amount: _amounts[(_i + 3) % 4], kind: PriceKind.declined),
        ]),
        const SizedBox(height: Sp.md),
        KeyButton(label: 'Change amounts', secondary: true, onPressed: () => setState(() => _i = (_i + 1) % 4)),
      ]);
}

class _WaveDemo extends StatefulWidget {
  const _WaveDemo();
  @override
  State<_WaveDemo> createState() => _WaveDemoState();
}

class _WaveDemoState extends State<_WaveDemo> {
  Timer? _t;
  double _p = .35;
  bool get _playing => _t != null;

  void _toggle() {
    if (_playing) {
      _t!.cancel();
      _t = null;
    } else {
      _t = Timer.periodic(const Duration(milliseconds: 100), (_) => setState(() => _p = _p >= 1 ? 0 : _p + .01));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Waveform(progress: _p, playing: _playing),
        const SizedBox(height: Sp.md),
        KeyButton(label: _playing ? 'Pause' : 'Play', icon: _playing ? Icons.pause : Icons.play_arrow, secondary: true, onPressed: _toggle),
      ]);
}

class _KeyboardDemo extends StatefulWidget {
  const _KeyboardDemo();
  @override
  State<_KeyboardDemo> createState() => _KeyboardDemoState();
}

class _KeyboardDemoState extends State<_KeyboardDemo> {
  final _filled = <BuildSlot>{BuildSlot.board};
  KbLayout _layout = KbLayout.k65;
  KeyboardColorway _cw = KeyboardColorway.carbon;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KeyboardLayers(filled: _filled, layout: _layout, colorway: _cw),
        Text('Drag the keyboard to tilt it.', style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: Sp.md),
        Wrap(spacing: Sp.sm, children: [
          for (final s in BuildSlot.values)
            FilterChip(
              key: ValueKey('lab.slot.${s.name}'),
              label: Text(s.name),
              selected: _filled.contains(s),
              onSelected: (v) => setState(() => v ? _filled.add(s) : _filled.remove(s)),
            ),
        ]),
        const SizedBox(height: Sp.sm),
        Wrap(spacing: Sp.sm, children: [
          for (final l in KbLayout.values)
            ChoiceChip(key: ValueKey('lab.layout.${l.api}'), label: Text(l.api), selected: _layout == l, onSelected: (_) => setState(() => _layout = l)),
        ]),
        const SizedBox(height: Sp.sm),
        Wrap(spacing: Sp.sm, children: [
          for (final c in KeyboardColorway.presets)
            ChoiceChip(key: ValueKey('lab.cw.${c.name}'), label: Text(c.name), selected: _cw == c, onSelected: (_) => setState(() => _cw = c)),
        ]),
      ]);
}

class _RevealDemo extends StatefulWidget {
  const _RevealDemo();
  @override
  State<_RevealDemo> createState() => _RevealDemoState();
}

class _RevealDemoState extends State<_RevealDemo> {
  int _run = 0;
  // Fake demo rows, not real product data.
  static const _rows = [('Layout', '75%', true), ('Switches', 'Linear (demo)', true), ('Weight', '1.7 kg vs 1.1 kg', false), ('Serial', 'Unknown', true)];

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RevealList(
          key: ValueKey(_run),
          children: [
            for (final (label, value, ok) in _rows)
              Container(
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(color: (ok ? context.keys.accepted : context.keys.declined).withValues(alpha: .12), borderRadius: BorderRadius.circular(Rad.sm)),
                child: Row(children: [
                  Icon(ok ? Icons.check_circle : Icons.cancel, size: 20, color: ok ? context.keys.accepted : context.keys.declined),
                  const SizedBox(width: Sp.sm),
                  Text(label, style: context.tt.labelLarge),
                  const Spacer(),
                  Flexible(child: Text(value, textAlign: TextAlign.end, style: monoStyle(13, context.cs.onSurface))),
                ]),
              ),
          ],
        ),
        const SizedBox(height: Sp.md),
        KeyButton(label: 'Replay', secondary: true, onPressed: () => setState(() => _run++)),
      ]);
}
