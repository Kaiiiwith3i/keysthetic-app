import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/app.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:keysthetic/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const phoneSizes = [Size(360, 780), Size(412, 915)];

/// Pumps ~1.5 s of frames: enough for entrances, safe with endless shimmers.
Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void useSize(WidgetTester t, Size size, {double textScale = 1.0}) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<ProviderContainer> pumpFullApp(WidgetTester t, {Map<String, Object> prefs = const {}, ThemeMode mode = ThemeMode.light}) async {
  SharedPreferences.setMockInitialValues({'theme_mode': mode.name, ...prefs});
  final p = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(p)]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KeystheticApp()));
  await settle(t);
  return c;
}

/// One screen in the real theme, no shell.
Future<void> pumpScreen(WidgetTester t, Widget screen, {ThemeMode mode = ThemeMode.light}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  await t.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(p)],
    child: MaterialApp(theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: mode, home: screen),
  ));
  await settle(t);
}
