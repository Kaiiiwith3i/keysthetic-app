// Dev tool, not a regression test: SCREENSHOTS=1 flutter test test/tool/browse_screenshots_test.dart
// writes PNGs to .dev-screens/ (gitignored). Demo data only (fake).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/models/build.dart';
import 'package:keysthetic/models/listing.dart';
import 'package:keysthetic/screens/build_planner_screen.dart';
import 'package:keysthetic/screens/feed_screen.dart';
import 'package:keysthetic/screens/listing_detail_screen.dart';
import 'package:keysthetic/screens/search_filter_screen.dart';
import 'package:keysthetic/services/browse.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:keysthetic/theme/app_theme.dart';
import 'package:keysthetic/widgets/keyboard_layers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// Builds kept in memory so the planner can be driven in demo mode (which refuses writes).
class _LocalBuilds extends BuildsNotifier {
  @override
  Future<List<Build>> build() async => [_make(const {})];

  static Build _make(Map<String, Listing> slots) => Build(
        id: 1, name: 'Cream 65% daily', layout: '65', stem: 'mx', connector: 'usb_c',
        slots: {for (final s in BuildSlot.values) s.name: slots[s.name]},
        total: slots.values.fold(0, (a, l) => a + l.price),
        openSlots: [for (final s in BuildSlot.values) if (slots[s.name] == null) s.name],
      );

  @override
  Future<void> setSlot(int id, BuildSlot slot, int? listingId) async {
    final cur = state.value!.first;
    final next = {for (final e in cur.slots.entries) if (e.value != null) e.key: e.value!};
    if (listingId == null) {
      next.remove(slot.name);
    } else {
      final j = (jsonDecode(File('assets/demo/demo.json').readAsStringSync())['listings'] as List).firstWhere((l) => l['id'] == listingId);
      next[slot.name] = Listing.fromJson(j as Map<String, dynamic>);
    }
    state = AsyncData([_make(next)]);
  }
}

void main() {
  final on = Platform.environment['SCREENSHOTS'] == '1';
  final shot = GlobalKey();

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

  /// Asset decoding is real IO; alternate real waits with frames so the photos fade in.
  Future<void> photos(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await settle(t, 500);
    }
  }

  Future<ProviderContainer> boot(WidgetTester t, ThemeMode mode, Widget home, {bool localBuilds = false}) async {
    await t.runAsync(loadFonts);
    useSize(t, const Size(412, 915));
    SharedPreferences.setMockInitialValues({'theme_mode': mode.name, 'session.demo': true});
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(p),
      if (localBuilds) buildsProvider.overrideWith(_LocalBuilds.new),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: RepaintBoundary(
        key: shot,
        child: MaterialApp(theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: mode, debugShowCheckedModeBanner: false, home: home),
      ),
    ));
    await photos(t);
    return c;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final m = mode.name;

    testWidgets('feed $m', (t) async {
      await boot(t, mode, const FeedScreen());
      await snap(t, 'browse_10_feed_$m');
      await t.tap(find.byKey(const ValueKey('feed.chip.keycaps')));
      await photos(t);
      await snap(t, 'browse_11_feed_keycaps_$m');
    }, skip: !on);

    testWidgets('search $m', (t) async {
      await boot(t, mode, const SearchFilterScreen());
      await t.tap(find.byKey(const ValueKey('search.filter')));
      await settle(t, 800);
      await t.tap(find.byKey(const ValueKey('filter.category.keyboard')));
      await t.tap(find.byKey(const ValueKey('filter.layout.75')));
      await t.tap(find.byKey(const ValueKey('filter.connection.wireless')));
      await settle(t, 300);
      await snap(t, 'browse_12_search_filters_$m');
      await t.ensureVisible(find.byKey(const ValueKey('filter.apply')));
      await t.tap(find.byKey(const ValueKey('filter.apply')));
      await photos(t);
      await snap(t, 'browse_13_search_results_$m');
    }, skip: !on);

    testWidgets('detail $m', (t) async {
      await boot(t, mode, const ListingDetailScreen(listingId: 57));
      await snap(t, 'browse_14_detail_top_$m');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -520));
      await settle(t, 500);
      await snap(t, 'browse_15_detail_mid_$m');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await settle(t, 500);
      await snap(t, 'browse_16_detail_legit_$m');
    }, skip: !on);

    testWidgets('planner $m', (t) async {
      final c = await boot(t, mode, const BuildPlannerScreen(), localBuilds: true);
      await snap(t, 'browse_17_planner_empty_$m');
      final n = c.read(buildsProvider.notifier);
      for (final (slot, id) in [(BuildSlot.board, 2), (BuildSlot.switches, 26), (BuildSlot.keycaps, 12)]) {
        await n.setSlot(1, slot, id);
        await settle(t, 200);
      }
      await settle(t, 2200);
      await snap(t, 'browse_18_planner_partial_$m');
      for (final (slot, id) in [(BuildSlot.stabilizers, 37), (BuildSlot.cable, 45)]) {
        await n.setSlot(1, slot, id);
      }
      await settle(t, 2600);
      await snap(t, 'browse_19_planner_full_$m');
      await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(t, 600);
      await snap(t, 'browse_20_planner_slots_$m');
      expect(t.takeException(), isNull);
    }, skip: !on);
  }
}
