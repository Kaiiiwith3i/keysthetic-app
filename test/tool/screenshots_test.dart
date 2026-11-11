// Dev tool, not a regression test: SCREENSHOTS=1 flutter test test/tool/screenshots_test.dart
// writes PNGs to .dev-screens/ (gitignored).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/app.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keysthetic/widgets/keyboard_layers.dart';

import '../helpers.dart';

void main() {
  final on = Platform.environment['SCREENSHOTS'] == '1';
  final shot = GlobalKey();

  // flutter test does not load app fonts by itself.
  Future<void> loadFonts() async {
    for (final f in {'Bricolage': 'BricolageGrotesque', 'InstrumentSans': 'InstrumentSans', 'JetBrainsMono': 'JetBrainsMono'}.entries) {
      final l = FontLoader(f.key)..addFont(rootBundle.load('assets/fonts/${f.value}.ttf'));
      await l.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();
  }

  Future<void> snap(WidgetTester t, String name) async {
    await t.runAsync(() async {
      final b = shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      Directory('.dev-screens').createSync();
      File('.dev-screens/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    });
  }

  Future<ProviderContainer> boot(WidgetTester t, ThemeMode mode, Map<String, Object> prefs) async {
    await t.runAsync(loadFonts);
    useSize(t, const Size(412, 915));
    SharedPreferences.setMockInitialValues({'theme_mode': mode.name, ...prefs});
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(p)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: RepaintBoundary(key: shot, child: const KeystheticApp())));
    await settle(t);
    return c;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final m = mode.name;
    testWidgets('connect + login $m', (t) async {
      await boot(t, mode, {});
      await snap(t, '01_connect_$m');
      await t.enterText(find.byKey(const ValueKey('connect.url')), '127.0.0.1:9');
      await t.tap(find.byKey(const ValueKey('connect.test')));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
      await settle(t, 600);
      await snap(t, '02_connect_failed_$m');
    }, skip: !on);

    testWidgets('login $m', (t) async {
      await boot(t, mode, {'session.base_url': 'http://127.0.0.1:9'});
      await snap(t, '03_login_$m');
    }, skip: !on);

    testWidgets('shell + lab $m', (t) async {
      await boot(t, mode, {'session.demo': true});
      await t.tap(find.byKey(const ValueKey('nav.build')));
      await settle(t);
      await snap(t, '04_shell_build_$m');
      await t.tap(find.byKey(const ValueKey('nav.profile')));
      await settle(t);
      await snap(t, '05_profile_$m');
      await t.tap(find.byKey(const ValueKey('profile.motion_lab')));
      await settle(t);
      await snap(t, '06_motion_lab_top_$m');
      for (final s in ['board', 'switches', 'keycaps', 'stabilizers', 'cable']) {
        final f = find.byKey(ValueKey('lab.slot.$s'));
        await t.scrollUntilVisible(f, 400, scrollable: find.byType(Scrollable).first);
        await t.tap(f);
        await settle(t, 200);
      }
      await Scrollable.ensureVisible(t.element(find.byType(KeyboardLayers)), alignment: .05);
      await settle(t, 2200);
      await snap(t, '07_motion_lab_keyboard_$m');
      final lay = find.byKey(const ValueKey('lab.layout.tkl'));
      await t.ensureVisible(lay);
      await t.tap(lay);
      await settle(t, 1500);
      await Scrollable.ensureVisible(t.element(find.byType(KeyboardLayers)), alignment: .05);
      await settle(t, 300);
      await snap(t, '08_motion_lab_tkl_$m');
      await t.drag(find.byType(ListView).first, const Offset(0, 300));
      await settle(t, 300);
      expect(t.takeException(), isNull);
    }, skip: !on);
  }
}
