import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keysthetic/screens/build_planner_screen.dart';
import 'package:keysthetic/screens/chat_thread_screen.dart';
import 'package:keysthetic/screens/checkout_screen.dart';
import 'package:keysthetic/screens/feed_screen.dart';
import 'package:keysthetic/screens/listing_detail_screen.dart';
import 'package:keysthetic/screens/search_filter_screen.dart';
import 'package:keysthetic/services/api.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:keysthetic/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// All data comes from assets/demo/demo.json (fake seed data).
final _demo = jsonDecode(File('assets/demo/demo.json').readAsStringSync()) as Map<String, dynamic>;
final _listings = (_demo['listings'] as List).cast<Map<String, dynamic>>();
Map<String, dynamic> _l(int id) => _listings.firstWhere((l) => l['id'] == id);
Map<String, dynamic> _summary(Map<String, dynamic> l) => {
  'id': l['id'],
  'title': l['title'],
  'price': l['price'],
  'photo': (l['photos'] as List).first,
  'status': l['status'],
  'category': l['category'],
};

const _slots = ['board', 'switches', 'keycaps', 'stabilizers', 'cable'];

Map<String, dynamic> _build(int id, String name, Map<String, int?> filled) {
  final slots = {for (final s in _slots) s: filled[s] == null ? null : _l(filled[s]!)};
  return {
    'id': id,
    'name': name,
    'layout': '65',
    'stem': 'mx',
    'connector': 'usb_c',
    'slots': slots,
    'total': slots.values.fold<int>(0, (a, l) => a + (l == null ? 0 : l['price'] as int)),
    'open_slots': [
      for (final s in _slots)
        if (slots[s] == null) s,
    ],
  };
}

/// Fake server: listings from the demo bundle, one mutable build list, records writes.
class FakeBrowseServer {
  FakeBrowseServer({Map<String, int?> filled = const {}}) {
    builds = [_build(1, 'My first 65%', filled)];
  }
  late List<Map<String, dynamic>> builds;
  final calls = <String>[];
  bool failListings = false;

  http.Response _json(Object o, [int code = 200]) => http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    final key = '${r.method} ${r.url.path}';
    calls.add(r.url.query.isEmpty ? key : '$key?${r.url.query}');
    final p = r.url.path;
    if (r.method == 'GET' && p == '/listings') {
      if (failListings) return _json({'error': 'Server is down'}, 500);
      final q = r.url.queryParameters;
      return _json(_listings.where((l) => q['category'] == null || l['category'] == q['category']).toList());
    }
    if (r.method == 'GET' && p.startsWith('/listings/')) return _json(_l(int.parse(p.split('/').last)));
    if (r.method == 'GET' && p == '/builds') return _json(builds);
    if (r.method == 'POST' && p == '/builds') {
      final b = _build(builds.length + 1, (jsonDecode(r.body) as Map)['name'] as String, {});
      builds.add(b);
      return _json(b, 201);
    }
    if (r.method == 'PUT' && p.startsWith('/builds/')) {
      final id = int.parse(p.split('/').last);
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final cur = builds.firstWhere((b) => b['id'] == id);
      final filled = {for (final s in _slots) s: (cur['slots'][s] as Map?)?['id'] as int?};
      (body['slots'] as Map? ?? {}).forEach((k, v) => filled[k as String] = v as int?);
      final next = _build(id, (body['name'] ?? cur['name']) as String, filled)..['layout'] = body['layout'] ?? cur['layout'];
      builds[builds.indexOf(cur)] = next;
      return _json(next);
    }
    if (r.method == 'DELETE' && p.startsWith('/builds/')) {
      builds.removeWhere((b) => b['id'] == int.parse(p.split('/').last));
      return _json({'ok': true});
    }
    if (r.method == 'POST' && p == '/threads') {
      final l = _l((jsonDecode(r.body) as Map)['listing_id'] as int);
      return _json({
        'id': 5,
        'listing': _summary(l),
        'buyer': {'id': 14, 'name': 'Buyer (fake)'},
        'seller': l['seller'],
        'last_message': null,
        'pending_offer': null,
        'order_id': null,
        'updated_at': '2026-11-03T08:00:00.000Z',
      });
    }
    if (r.method == 'POST' && p == '/threads/5/offer') {
      return _json({
        'id': 1,
        'thread_id': 5,
        'sender_id': 14,
        'kind': 'offer',
        'body': null,
        'amount': (jsonDecode(r.body) as Map)['amount'],
        'created_at': '',
      }, 201);
    }
    if (r.method == 'POST' && p == '/orders') {
      final l = _l((jsonDecode(r.body) as Map)['listing_id'] as int);
      return _json({
        'id': 7,
        'listing': _summary(l),
        'buyer': {'id': 14, 'name': 'Buyer (fake)'},
        'seller': l['seller'],
        'price': l['price'],
        'status': 'accepted',
        'history': [],
        'created_at': '',
        'updated_at': '',
      }, 201);
    }
    return _json({'error': 'not found in fake'}, 404);
  }
}

Future<void> pump(
  WidgetTester t,
  Widget screen, {
  FakeBrowseServer? server,
  bool demo = false,
  ThemeMode mode = ThemeMode.light,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({if (demo) 'session.demo': true, ...prefs});
  final p = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(p),
        if (server != null) apiProvider.overrideWithValue(Api(baseUrl: 'http://fake', token: 'x', client: MockClient(server.handle))),
      ],
      child: MaterialApp(theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: mode, home: screen),
    ),
  );
  if (demo) await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150))); // bundle reads are real IO
  await settle(t);
}

/// Tap by key, scrolling it into view first (the outermost Scrollable is the screen's list).
Future<void> tapK(WidgetTester t, String key, {bool list = false, int ms = 600}) async {
  final f = find.byKey(ValueKey(key));
  if (list) await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.tap(f);
  await settle(t, ms);
}

void main() {
  // Overflow bar: both phone sizes, text scale 1.3, light and dark, demo data.
  for (final size in phoneSizes) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final tag = '@${size.width.toInt()} x1.3 ${mode.name}';
      final screens = <String, Widget>{
        'feed': const FeedScreen(),
        'search': const SearchFilterScreen(),
        'detail (sound + legit)': const ListingDetailScreen(listingId: 57),
        'detail (cable)': const ListingDetailScreen(listingId: 52),
        'planner': const BuildPlannerScreen(),
      };
      for (final e in screens.entries) {
        testWidgets('${e.key} $tag', (t) async {
          useSize(t, size, textScale: 1.3);
          await pump(t, e.value, demo: true, mode: mode);
          expect(find.byType(Scrollable), findsWidgets);
          for (var i = 0; i < 4; i++) {
            await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
            await settle(t, 300);
          }
          expect(t.takeException(), isNull);
        });
      }

      testWidgets('full planner + filter sheet $tag', (t) async {
        useSize(t, size, textScale: 1.3);
        final s = FakeBrowseServer(filled: {'board': 2, 'switches': 26, 'keycaps': 12, 'stabilizers': 37, 'cable': 45});
        await pump(t, const BuildPlannerScreen(), server: s, mode: mode);
        for (var i = 0; i < 4; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
          await settle(t, 300);
        }
        expect(t.takeException(), isNull);
        await pump(t, const SearchFilterScreen(), server: s, mode: mode);
        await t.tap(find.byKey(const ValueKey('search.filter')));
        await settle(t);
        for (var i = 0; i < 3; i++) {
          await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -400));
          await settle(t, 200);
        }
        expect(find.byKey(const ValueKey('filter.apply')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('feed: chips filter the query, error state retries', (t) async {
    useSize(t, phoneSizes.first);
    final s = FakeBrowseServer()..failListings = true;
    await pump(t, const FeedScreen(), server: s);
    expect(find.byKey(const ValueKey('feed.retry')), findsOneWidget);
    expect(find.text('Server is down'), findsOneWidget);
    s.failListings = false;
    await t.tap(find.byKey(const ValueKey('feed.retry')));
    await settle(t);
    expect(find.byKey(const ValueKey('feed.card.62')), findsOneWidget);
    expect(find.byKey(const ValueKey('feed.fits')), findsOneWidget); // buyer with a build
    await tapK(t, 'feed.chip.cable');
    expect(s.calls.where((c) => c == 'GET /listings?category=cable'), isNotEmpty);
    expect(find.byKey(const ValueKey('feed.card.62')), findsNothing);
    expect(find.byKey(const ValueKey('feed.card.52')), findsOneWidget);
    await tapK(t, 'feed.fits');
    expect(s.calls.last, startsWith('GET /listings?category=cable&build_id=1'));
  });

  testWidgets('feed cards show Reserved and Legit-checked badges; tap opens detail', (t) async {
    useSize(t, phoneSizes.first);
    await pump(t, const FeedScreen(), demo: true);
    await tapK(t, 'feed.chip.switches');
    expect(find.text('Reserved'), findsWidgets);
    await tapK(t, 'feed.chip.keyboard');
    expect(find.text('Legit-checked'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('feed.card.62')));
    await settle(t);
    expect(find.byType(ListingDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('detail.buy')), findsOneWidget);
  });

  testWidgets('search: debounce, filter sheet, removable chips', (t) async {
    useSize(t, phoneSizes.first);
    final s = FakeBrowseServer();
    await pump(t, const SearchFilterScreen(), server: s);
    await t.enterText(find.byKey(const ValueKey('search.field')), 'corsair');
    await t.pump(const Duration(milliseconds: 100));
    expect(s.calls.where((c) => c.contains('q=')), isEmpty); // still debouncing
    await settle(t, 600);
    expect(s.calls.last, 'GET /listings?q=corsair');
    await t.tap(find.byKey(const ValueKey('search.filter')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('filter.category.keyboard')));
    await t.tap(find.byKey(const ValueKey('filter.condition.like_new')));
    await t.enterText(find.byKey(const ValueKey('filter.min')), '1000');
    await t.ensureVisible(find.byKey(const ValueKey('filter.sort.price_asc')));
    await t.tap(find.byKey(const ValueKey('filter.sort.price_asc')));
    await t.ensureVisible(find.byKey(const ValueKey('filter.apply')));
    await t.tap(find.byKey(const ValueKey('filter.apply')));
    await settle(t);
    expect(find.byKey(const ValueKey('search.chip.category')), findsOneWidget);
    expect(find.byKey(const ValueKey('search.chip.condition')), findsOneWidget);
    expect(find.byKey(const ValueKey('search.chip.price')), findsOneWidget);
    expect(
      s.calls.last,
      allOf(
        contains('category=keyboard'),
        contains('condition=like_new'),
        contains('min_price=1000'),
        contains('sort=price_asc'),
        contains('q=corsair'),
      ),
    );
    await tapK(t, 'search.chip.condition');
    expect(find.byKey(const ValueKey('search.chip.condition')), findsNothing);
    expect(s.calls.last, isNot(contains('condition')));
  });

  testWidgets('detail: gallery opens viewer; legit + disclaimer shown; hear-it-first present', (t) async {
    useSize(t, phoneSizes.first);
    await pump(t, const ListingDetailScreen(listingId: 57), demo: true);
    expect(find.byKey(const ValueKey('detail.sound.play')), findsOneWidget);
    expect(find.text('Hear it first'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const ValueKey('detail.legit')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('not proof of authenticity'), findsOneWidget);
    await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await settle(t, 300);
    await t.tap(find.byKey(const ValueKey('detail.photo.0')));
    await settle(t);
    expect(find.byKey(const ValueKey('detail.viewer.close')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('detail.viewer.close')));
    await settle(t);
    expect(find.byKey(const ValueKey('detail.viewer.close')), findsNothing);
  });

  testWidgets('detail: buyer actions are >= 48dp and demo writes explain themselves', (t) async {
    useSize(t, phoneSizes.first, textScale: 1.3);
    await pump(t, const ListingDetailScreen(listingId: 2), demo: true);
    for (final k in ['detail.buy', 'detail.offer', 'detail.message', 'detail.add_to_build']) {
      final s = t.getSize(find.byKey(ValueKey(k)));
      expect(s.height >= 48 && s.width >= 48, isTrue, reason: '$k is $s');
    }
    await t.tap(find.byKey(const ValueKey('detail.message')));
    await settle(t, 400);
    expect(find.text('Connect to a server to do this'), findsOneWidget);
  });

  testWidgets('detail: reserved listing hides actions', (t) async {
    useSize(t, phoneSizes.first);
    await pump(t, const ListingDetailScreen(listingId: 31), demo: true);
    expect(find.byKey(const ValueKey('detail.buy')), findsNothing);
    expect(find.byKey(const ValueKey('detail.unavailable')), findsOneWidget);
  });

  testWidgets('detail: message, offer and buy now call the API and navigate', (t) async {
    useSize(t, phoneSizes.first);
    final s = FakeBrowseServer();
    await pump(t, const ListingDetailScreen(listingId: 2), server: s);

    await t.tap(find.byKey(const ValueKey('detail.message')));
    await settle(t);
    expect(s.calls, contains('POST /threads'));
    expect(find.byType(ChatThreadScreen), findsOneWidget);
    Navigator.of(t.element(find.byType(ChatThreadScreen))).pop();
    await settle(t);

    await t.tap(find.byKey(const ValueKey('detail.offer')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('detail.offer.amount')), '99999999');
    await t.tap(find.byKey(const ValueKey('detail.offer.send')));
    await settle(t, 300);
    expect(find.textContaining('Enter an amount up to'), findsOneWidget); // over asking
    await t.enterText(find.byKey(const ValueKey('detail.offer.amount')), '1000');
    await t.tap(find.byKey(const ValueKey('detail.offer.send')));
    await settle(t);
    expect(s.calls, contains('POST /threads/5/offer'));
    expect(find.byType(ChatThreadScreen), findsOneWidget);
    Navigator.of(t.element(find.byType(ChatThreadScreen))).pop();
    await settle(t);

    await t.tap(find.byKey(const ValueKey('detail.buy')));
    await settle(t);
    expect(s.calls, contains('POST /orders'));
    expect(find.byType(CheckoutScreen), findsOneWidget);
  });

  testWidgets('detail: the seller sees Edit on their own listing, not buyer actions', (t) async {
    useSize(t, phoneSizes.first);
    final seller = _l(2)['seller'] as Map<String, dynamic>;
    await pump(
      t,
      const ListingDetailScreen(listingId: 2),
      server: FakeBrowseServer(),
      prefs: {
        'session.token': 'x',
        'session.user': jsonEncode({'id': seller['id'], 'email': 's@fake', 'name': seller['name'], 'role': 'seller'}),
      },
    );
    await t.scrollUntilVisible(find.byKey(const ValueKey('detail.edit')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('detail.edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail.buy')), findsNothing);
  });

  testWidgets('detail: add to build fills the slot; planner reflects it, remove clears it', (t) async {
    useSize(t, phoneSizes.first);
    final s = FakeBrowseServer();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(
          await (() async {
            SharedPreferences.setMockInitialValues({});
            return SharedPreferences.getInstance();
          })(),
        ),
        apiProvider.overrideWithValue(Api(baseUrl: 'http://fake', token: 'x', client: MockClient(s.handle))),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const ListingDetailScreen(listingId: 52)),
      ),
    );
    await settle(t);
    await t.tap(find.byKey(const ValueKey('detail.add_to_build')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('detail.build.1')));
    await settle(t);
    final put = s.calls.firstWhere((c) => c.startsWith('PUT /builds/1'));
    expect(put, 'PUT /builds/1');
    expect((s.builds.first['slots'] as Map)['cable']['id'], 52);
    expect(find.text('Added to My first 65%'), findsOneWidget);

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Brightness.light), home: const BuildPlannerScreen()),
      ),
    );
    await settle(t);
    expect(find.text('4 of 5 slots open'), findsOneWidget);
    await settle(t, 5000); // let the snackbar go
    await tapK(t, 'build.slot.cable.remove', list: true);
    expect(find.byKey(const ValueKey('build.slot.cable.remove')), findsNothing);
    await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await settle(t, 300);
    expect(find.text('5 of 5 slots open'), findsOneWidget);
  });

  testWidgets('planner: empty state creates a build; rename; delete; spec chip; find compatible opens filtered search', (t) async {
    useSize(t, phoneSizes.first);
    final s = FakeBrowseServer()..builds = [];
    await pump(t, const BuildPlannerScreen(), server: s);
    expect(find.text('Build planner'), findsOneWidget);
    expect(find.byKey(const ValueKey('build.create')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('build.create')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('build.name.field')), 'Cream 65%');
    await t.tap(find.byKey(const ValueKey('build.name.save')));
    await settle(t);
    expect(find.text('Cream 65%'), findsWidgets);
    expect(find.text('5 of 5 slots open'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('build.spec.layout')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('build.spec.layout.tkl')));
    await settle(t);
    expect(s.builds.first['layout'], 'tkl');
    expect(find.text('Layout: TKL'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('build.menu')));
    await settle(t, 300);
    await t.tap(find.byKey(const ValueKey('build.rename')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('build.name.field')), 'Daily driver');
    await t.tap(find.byKey(const ValueKey('build.name.save')));
    await settle(t);
    expect(find.text('Daily driver'), findsWidgets);

    await tapK(t, 'build.slot.keycaps.find', list: true);
    expect(find.byType(SearchFilterScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('search.chip.category')), findsOneWidget);
    expect(find.byKey(const ValueKey('search.chip.build')), findsOneWidget);
    expect(s.calls.last, 'GET /listings?category=keycaps&build_id=1');
    Navigator.of(t.element(find.byType(SearchFilterScreen))).pop();
    await settle(t);

    await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await settle(t, 300);
    await tapK(t, 'build.menu', ms: 300);
    await tapK(t, 'build.delete');
    await tapK(t, 'build.delete.confirm');
    expect(s.builds, isEmpty);
    expect(find.byKey(const ValueKey('build.create')), findsOneWidget);
  });

  testWidgets('planner: slot and thumb tap targets, error retry', (t) async {
    useSize(t, phoneSizes.first, textScale: 1.3);
    final s = FakeBrowseServer(filled: {'board': 2, 'cable': 45});
    await pump(t, const BuildPlannerScreen(), server: s);
    for (final c in ['carbon', 'cream', 'sakura', 'terminal']) {
      final sz = t.getSize(find.byKey(ValueKey('build.colorway.$c')));
      expect(sz.width >= 48 && sz.height >= 48, isTrue, reason: '$c is $sz');
    }
    await t.scrollUntilVisible(find.byKey(const ValueKey('build.slot.cable.remove')), 200, scrollable: find.byType(Scrollable).first);
    final r = t.getSize(find.byKey(const ValueKey('build.slot.cable.remove')));
    expect(r.width >= 48 && r.height >= 48, isTrue, reason: '$r');
    await t.scrollUntilVisible(find.byKey(const ValueKey('build.slot.keycaps.find')), 200, scrollable: find.byType(Scrollable).first);
    final f = t.getSize(find.byKey(const ValueKey('build.slot.keycaps.find')));
    expect(f.height >= 48, isTrue, reason: '$f');
  });
}
