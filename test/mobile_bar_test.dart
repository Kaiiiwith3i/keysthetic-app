import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/screens/connect_screen.dart';
import 'package:keysthetic/screens/login_screen.dart';
import 'package:keysthetic/screens/motion_lab_screen.dart';
import 'package:keysthetic/screens/profile_screen.dart';
import 'package:keysthetic/screens/register_screen.dart';

import 'package:keysthetic/services/providers.dart';

import 'helpers.dart';

/// 360x780 and 412x915, text scale 1.3, light and dark: no overflow exceptions.
void main() {
  final screens = <String, Widget>{
    'connect': const ConnectScreen(),
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'profile': const ProfileScreen(),
    'motion lab': const MotionLabScreen(),
  };
  for (final size in phoneSizes) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final e in screens.entries) {
        testWidgets('${e.key} @${size.width.toInt()} x1.3 ${mode.name}', (t) async {
          useSize(t, size, textScale: 1.3);
          await pumpScreen(t, e.value, mode: mode);
          if (e.key == 'motion lab') {
            for (var i = 0; i < 9; i++) {
              await t.drag(find.byType(ListView).first, const Offset(0, -500));
              await settle(t, 300);
            }
          }
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('full app shell (demo, each role) @360 x1.3', (t) async {
    useSize(t, phoneSizes.first, textScale: 1.3);
    final c = await pumpFullApp(t, prefs: {'session.demo': true});
    for (final role in ['buyer', 'seller', 'admin']) {
      c.read(sessionProvider.notifier).demoRole(role);
      await settle(t);
      expect(t.takeException(), isNull, reason: role);
    }
  });
}
