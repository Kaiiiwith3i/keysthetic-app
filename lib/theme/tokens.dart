import 'package:flutter/material.dart';

/// Spacing scale (dp). Use these, not literals.
class Sp {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
}

/// Corner radii. Keycap-like: generous but not pill-everything.
class Rad {
  static const double sm = 10, md = 16, lg = 22, xl = 28;
}

/// Motion durations shared across widgets.
class Dur {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
}

/// Keysthetic colours that Material's ColorScheme has no slot for.
@immutable
class KeysColors extends ThemeExtension<KeysColors> {
  const KeysColors({
    required this.capTop,
    required this.capBottom,
    required this.capLip,
    required this.shadow,
    required this.offer,
    required this.counter,
    required this.accepted,
    required this.declined,
    required this.skeleton,
    required this.skeletonHi,
  });

  final Color capTop, capBottom, capLip, shadow;
  final Color offer, counter, accepted, declined;
  final Color skeleton, skeletonHi;

  static const light = KeysColors(
    capTop: Color(0xFFFFFFFF),
    capBottom: Color(0xFFF3EFE6),
    capLip: Color(0xFFD9D2C3),
    shadow: Color(0x2E3B2F1A),
    offer: Color(0xFFB7791F),
    counter: Color(0xFF2B6CB0),
    accepted: Color(0xFF1E8A4C),
    declined: Color(0xFFC53030),
    skeleton: Color(0xFFE6E0D3),
    skeletonHi: Color(0xFFF7F3EA),
  );

  static const dark = KeysColors(
    capTop: Color(0xFF2E2B25),
    capBottom: Color(0xFF24211C),
    capLip: Color(0xFF0E0D0A),
    shadow: Color(0x99000000),
    offer: Color(0xFFF0B04A),
    counter: Color(0xFF6BA8F0),
    accepted: Color(0xFF4CC785),
    declined: Color(0xFFFF7A7A),
    skeleton: Color(0xFF2B2823),
    skeletonHi: Color(0xFF3A362F),
  );

  @override
  KeysColors copyWith() => this;

  @override
  KeysColors lerp(KeysColors? other, double t) => t < .5 ? this : (other ?? this);
}

extension KeysTheme on BuildContext {
  KeysColors get keys => Theme.of(this).extension<KeysColors>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
