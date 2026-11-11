// Frame-timing measurements on the live server (run with `flutter drive --profile`,
// see run_perf.sh). Each scenario is wrapped in IntegrationTestWidgetsFlutterBinding.watchPerformance;
// test_driver/perf_driver.dart turns the reported summaries into PERF-RESULTS.md.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keysthetic/widgets/keyboard_layers.dart';

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('frame timings', (t) async {
    // ---- preconditions over HTTP: a seller with parts, a buyer with a 65% build.
    final seller = await Srv.register('seller');
    final buyer = await Srv.register('buyer');
    const stem = {'stem': 'mx'};
    final board = await Srv.listing(seller,
        title: 'E2E Perf ${uniq('pf')} 65% board', tags: {'kind': 'mechanical', 'layout': '65', 'stem': 'mx', 'connector': 'usb_c'});
    final switches = await Srv.listing(seller, title: 'E2E Perf ${uniq('pf')} switches', category: 'switches', price: 900, tags: {...stem, 'switch_type': 'linear'});
    final keycaps = await Srv.listing(seller, title: 'E2E Perf ${uniq('pf')} keycaps', category: 'keycaps', price: 1500, tags: stem);
    final b = await Srv.call('POST', '/builds',
        token: buyer.token, expect: 201, body: {'name': 'Perf build', 'layout': '65', 'stem': 'mx', 'connector': 'usb_c'}) as Map<String, dynamic>;
    await Srv.call('PUT', '/builds/${b['id']}', token: buyer.token, body: {'slots': {'switches': switches['id'], 'keycaps': keycaps['id']}});

    await launchSignedIn(t, buyer);
    await pumpUntilFound(t, keyed('feed.card.'));
    await settle(t, 1500);

    Future<void> measure(String key, Future<void> Function() body) => binding.watchPerformance(body, reportKey: key);

    // ---- 1. feed scroll
    final feed = find.byType(CustomScrollView).first;
    await measure('feed_scroll', () async {
      for (var i = 0; i < 4; i++) {
        await t.fling(feed, const Offset(0, -600), 1800);
        await settle(t, 900);
      }
      for (var i = 0; i < 4; i++) {
        await t.fling(feed, const Offset(0, 600), 1800);
        await settle(t, 900);
      }
    });

    // ---- 2. open a listing (hero) and back
    await measure('listing_open_hero', () async {
      for (var i = 0; i < 3; i++) {
        await t.tap(keyed('feed.card.').first);
        await pumpUntilFound(t, find.text('Specs'));
        await settle(t, 600);
        await t.pageBack();
        await settle(t, 700);
      }
    });

    // ---- 3. tab switching
    await measure('tab_switch', () async {
      for (var round = 0; round < 3; round++) {
        for (final n in ['search', 'build', 'chats', 'profile', 'home']) {
          await t.tap(k('nav.$n'));
          await settle(t, 600);
        }
      }
    });

    // ---- 4. build planner: tilt, clear, fill
    await tapKey(t, 'nav.build');
    await reveal(t, k('build.slot.switches.remove'), low: true); // build loaded with 2 parts filled
    await reveal(t, k('build.slot.keycaps.remove'), low: true);
    await scrollToTop(t);
    await settle(t, 1200);
    final layers = find.byType(KeyboardLayers);
    await measure('build_tilt', () async {
      for (final d in const [Offset(90, 30), Offset(-90, -30), Offset(40, 80), Offset(-40, -80)]) {
        await t.timedDrag(layers, d, const Duration(milliseconds: 500));
        await settle(t, 700); // springs back on release
      }
    });
    // The remove buttons sit below the keyboard picture: tap, then scroll back up to watch the layer lift.
    await measure('build_clear', () async {
      for (final slot in ['switches', 'keycaps']) {
        await tapKey(t, 'build.slot.$slot.remove', low: true);
        await scrollToTop(t);
        await settle(t, 1200);
      }
    });
    await measure('build_fill', () async {
      await tapKey(t, 'build.slot.board.find');
      await pumpUntilFound(t, k('feed.card.${board['id']}'));
      await tapKey(t, 'feed.card.${board['id']}');
      await tapKey(t, 'detail.add_to_build');
      await tapKey(t, 'detail.build.${b['id']}');
      await pumpUntilFound(t, find.text('Added to Perf build'));
      await settle(t, 1500); // the part flies to the build
      await backToShell(t);
      await reveal(t, k('build.slot.board.remove'), low: true);
      await scrollToTop(t);
      await settle(t, 1200);
    });
  });
}
