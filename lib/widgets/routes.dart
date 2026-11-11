import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The shared page transition: a soft rise + fade, with the outgoing page
/// easing back. Reduce-motion: a short plain fade.
/// Use `Navigator.push(context, appRoute(const SomeScreen()))` everywhere.
Route<T> appRoute<T>(Widget page, {String? name}) => PageRouteBuilder<T>(
      settings: RouteSettings(name: name),
      transitionDuration: Dur.slow,
      reverseTransitionDuration: Dur.base,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, anim, secondary, child) {
        if (context.reduceMotion) {
          return FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child);
        }
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(curved),
            child: ScaleTransition(
              scale: Tween(begin: .98, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );

extension AppNav on BuildContext {
  Future<T?> push<T>(Widget page, {String? name}) => Navigator.of(this).push<T>(appRoute<T>(page, name: name));
  void popToRoot() => Navigator.of(this).popUntil((r) => r.isFirst);
}
