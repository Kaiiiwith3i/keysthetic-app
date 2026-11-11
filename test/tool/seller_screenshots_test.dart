// Dev tool: SCREENSHOTS=1 flutter test test/tool/seller_screenshots_test.dart -> .dev-screens/seller_*.png (FAKE data).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/screens/legit_check_screen.dart';
import 'package:keysthetic/screens/my_listings_screen.dart';
import 'package:keysthetic/screens/post_listing_screen.dart';
import 'package:keysthetic/widgets/legit_result_view.dart';

import '../helpers.dart';
import '../seller_fixtures.dart';

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

  Future<void> show(WidgetTester t, Widget screen, ThemeMode mode) async {
    await t.runAsync(loadFonts);
    useSize(t, const Size(412, 915));
    await pumpWith(t, RepaintBoundary(key: shot, child: screen), api: FakeApi(items: [fakeListing(1, legit: fakeResult), fakeListing(2, status: 'reserved'), fakeListing(3, status: 'sold', category: 'cable')]), mode: mode);
  }

  Future<void> scroll(WidgetTester t, double dy) async {
    await t.drag(find.byType(ListView).first, Offset(0, -dy));
    await settle(t, 600);
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final m = mode.name;
    testWidgets('seller screens $m', (t) async {
      await show(t, const MyListingsScreen(), mode);
      await snap(t, 'seller_1_my_listings_$m');
      await show(t, PostListingScreen(listing: fakeListing(1)), mode);
      await snap(t, 'seller_2_post_top_$m');
      await scroll(t, 700);
      await snap(t, 'seller_3_post_mid_$m');
      await scroll(t, 700);
      await snap(t, 'seller_4_post_bottom_$m');
      await show(t, const LegitCheckScreen(), mode);
      await snap(t, 'seller_5_legit_pick_$m');
      await t.tap(find.byKey(const ValueKey('legit.ref.fake-q1')));
      await settle(t, 600);
      await scroll(t, 450);
      await snap(t, 'seller_6_legit_form_$m');
      await show(t, const Scaffold(body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(16), child: LegitResultView(result: fakeResult, reference: fakeRef)))), mode);
      await settle(t, 2000);
      await snap(t, 'seller_7_legit_result_$m');
      expect(t.takeException(), isNull);
    }, skip: !on);
  }
}
