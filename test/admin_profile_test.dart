import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/models/legit.dart';
import 'package:keysthetic/models/listing.dart';
import 'package:keysthetic/models/user.dart';
import 'package:keysthetic/screens/admin_legit_edit_screen.dart';
import 'package:keysthetic/screens/admin_legit_screen.dart';
import 'package:keysthetic/screens/admin_listings_screen.dart';
import 'package:keysthetic/screens/admin_users_screen.dart';
import 'package:keysthetic/screens/profile_screen.dart';
import 'package:keysthetic/services/api.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:keysthetic/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// Fake data for tests only.
Listing _l(int id, String status, {String title = 'Fake Board'}) => Listing.fromJson({
      'id': id, 'seller': {'id': 2, 'name': 'Fake Seller With A Rather Long Name', 'area': 'Nowhere'}, 'title': '$title $id with a very long title to test wrapping',
      'description': '', 'category': 'keyboard', 'price': 1200 * id, 'condition': 'used', 'photos': <String>[], 'status': status,
    });
User _u(int id, String role, {bool banned = false}) =>
    User(id: id, email: 'fake$id@keysthetic.demo', name: 'Fake User $id', role: role, area: 'Nowhere', banned: banned);

class FakeApi extends Api {
  FakeApi({this.fail = false, this.slow = false}) : super(baseUrl: 'http://fake');
  final bool fail, slow;
  final calls = <String>[];
  Object? lastBody;
  List<Listing> listingsData = [_l(1, 'active'), _l(2, 'hidden'), _l(3, 'sold'), _l(4, 'reserved')];
  List<User> usersData = [_u(1, 'admin'), _u(2, 'seller'), _u(3, 'buyer'), _u(4, 'buyer', banned: true)];
  List<LegitReference> refsData = [
    LegitReference.fromJson({'id': 'fake-board', 'brand': 'Fake', 'model': 'Board', 'fields': {
      'layout': {'value': '75%', 'source': 'https://example.com/x', 'accessed': '2026-11-12'},
      'switches': {'value': ['Red', 'Brown'], 'source': 'https://example.com/x', 'accessed': '2026-11-12'},
      'weight_g': null,
    }}),
  ];

  Future<T> _gate<T>(T v) async {
    if (slow) await Future<void>.delayed(const Duration(seconds: 30));
    if (fail) throw const ApiException(0, 'Cannot reach the server');
    return v;
  }

  @override
  Future<List<Listing>> adminListings({String? status}) => _gate(listingsData);
  @override
  Future<Listing> hideListing(int id, bool hidden) async {
    calls.add('hide $id $hidden');
    final l = listingsData.firstWhere((x) => x.id == id);
    return _l(id, hidden ? 'hidden' : 'active', title: 'Fake Board').let((n) => n.id == l.id ? n : l);
  }
  @override
  Future<List<User>> adminUsers() => _gate(usersData);
  @override
  Future<User> banUser(int id, bool banned) async {
    calls.add('ban $id $banned');
    final u = usersData.firstWhere((x) => x.id == id);
    return User(id: u.id, email: u.email, name: u.name, role: u.role, area: u.area, banned: banned);
  }
  @override
  Future<List<LegitReference>> legitReferences({String? q}) => _gate(refsData);
  @override
  Future<void> adminCreateReference(Map<String, dynamic> ref) async {
    calls.add('create');
    lastBody = ref;
  }
  @override
  Future<void> adminUpdateReference(String id, Map<String, dynamic> ref) async {
    calls.add('update $id');
    lastBody = ref;
  }
  @override
  Future<void> adminDeleteReference(String id) async => calls.add('delete $id');
  @override
  Future<User> updateMe({String? name, String? area, String? paymentQrUrl}) async {
    calls.add('me $name|$area');
    return User(id: 3, email: 'fake3@keysthetic.demo', name: name!, role: 'buyer', area: area);
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

Future<void> pump(WidgetTester t, Widget screen, FakeApi api, {ThemeMode mode = ThemeMode.light, String role = 'buyer'}) async {
  SharedPreferences.setMockInitialValues({
    'session.base_url': 'http://fake',
    'session.token': 'tok',
    'session.user': jsonEncode(User(id: 3, email: 'fake3@keysthetic.demo', name: 'Fake User 3', role: role, area: 'Nowhere').toJson()),
  });
  final p = await SharedPreferences.getInstance();
  await t.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(p), apiProvider.overrideWithValue(api)],
    child: MaterialApp(theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: mode, home: screen),
  ));
  await settle(t);
}

void main() {
  final screens = <String, (Widget, String)>{
    'admin listings': (const AdminListingsScreen(), 'buyer'),
    'admin users': (const AdminUsersScreen(), 'buyer'),
    'admin legit': (const AdminLegitScreen(), 'buyer'),
    'legit edit': (AdminLegitEditScreen(reference: FakeApi().refsData.first), 'buyer'),
    'legit new': (const AdminLegitEditScreen(), 'buyer'),
    'profile buyer': (const ProfileScreen(), 'buyer'),
    'profile seller': (const ProfileScreen(), 'seller'),
    'profile admin': (const ProfileScreen(), 'admin'),
  };
  for (final size in phoneSizes) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final e in screens.entries) {
        testWidgets('${e.key} @${size.width.toInt()} x1.3 ${mode.name}', (t) async {
          useSize(t, size, textScale: 1.3);
          await pump(t, e.value.$1, FakeApi(), mode: mode, role: e.value.$2);
          if (e.key.startsWith('legit')) {
            // open every optional field so the long form is exercised
            for (final k in ['layout', 'weight_g', 'serial_format']) {
              final f = find.byKey(ValueKey('legit_edit.$k.value'));
              if (f.evaluate().isNotEmpty) {
                await t.ensureVisible(f);
                await t.enterText(f, '5');
                await settle(t, 400);
              }
            }
          }
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('error and retry on admin listings', (t) async {
    useSize(t, phoneSizes.first);
    await pump(t, const AdminListingsScreen(), FakeApi(fail: true));
    expect(find.byKey(const ValueKey('admin_listings.retry')), findsOneWidget);
    expect(find.text('Cannot reach the server'), findsOneWidget);
  });

  testWidgets('loading skeleton shows before data', (t) async {
    useSize(t, phoneSizes.first);
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await t.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(p), apiProvider.overrideWithValue(FakeApi(slow: true))],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const AdminUsersScreen()),
    ));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('admin_users.loading')), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // dispose before the fake 30 s delay fires
    await t.pump(const Duration(seconds: 31));
  });

  testWidgets('listings: filter, search, hide with confirm updates status', (t) async {
    useSize(t, phoneSizes.first);
    final api = FakeApi();
    await pump(t, const AdminListingsScreen(), api);
    expect(find.byKey(const ValueKey('admin_listings.row.1')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('admin_listings.filter.hidden')));
    await settle(t, 600);
    expect(find.byKey(const ValueKey('admin_listings.row.1')), findsNothing);
    expect(find.byKey(const ValueKey('admin_listings.row.2')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('admin_listings.filter.all')));
    await settle(t, 600);
    await t.enterText(find.byKey(const ValueKey('admin_listings.search')), 'board 3');
    await settle(t, 400);
    expect(find.byKey(const ValueKey('admin_listings.row.3')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin_listings.row.1')), findsNothing);
    expect(find.byKey(const ValueKey('admin_listings.hide.3')), findsNothing, reason: 'sold listings cannot be hidden');
    await t.enterText(find.byKey(const ValueKey('admin_listings.search')), '');
    await settle(t, 400);
    await t.tap(find.byKey(const ValueKey('admin_listings.hide.1')));
    await settle(t, 400);
    await t.tap(find.byKey(const ValueKey('admin_listings.confirm.cancel')));
    await settle(t, 400);
    expect(api.calls, isEmpty);
    await t.tap(find.byKey(const ValueKey('admin_listings.hide.1')));
    await settle(t, 400);
    await t.tap(find.byKey(const ValueKey('admin_listings.confirm.confirm')));
    await settle(t, 600);
    expect(api.calls, ['hide 1 true']);
    expect(find.text('HIDDEN'), findsWidgets);
    expect(find.text('Listing hidden.'), findsOneWidget);
  });

  testWidgets('users: counts, admins have no ban button, ban flow', (t) async {
    useSize(t, phoneSizes.first);
    final api = FakeApi();
    await pump(t, const AdminUsersScreen(), api);
    expect(find.text('All 4'), findsOneWidget);
    expect(find.text('Buyer 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin_users.ban.1')), findsNothing, reason: 'admin cannot be banned');
    expect(find.text('Unban'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('admin_users.ban.2')));
    await settle(t, 400);
    await t.tap(find.byKey(const ValueKey('admin_users.confirm.confirm')));
    await settle(t, 600);
    expect(api.calls, ['ban 2 true']);
    expect(find.text('BANNED'), findsNWidgets(2));
  });

  testWidgets('legit: note visible, null fields flagged, id validation, create payload', (t) async {
    useSize(t, const Size(412, 4000)); // tall so the whole form is built
    final api = FakeApi();
    await pump(t, const AdminLegitScreen(), api);
    expect(find.byKey(const ValueKey('admin_legit.note')), findsOneWidget);
    expect(find.textContaining('No published source'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('admin_legit.new')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('legit_edit.id')), 'Bad ID');
    await t.tap(find.byKey(const ValueKey('legit_edit.save')));
    await settle(t, 400);
    expect(find.textContaining('Lowercase letters'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('legit_edit.id')), 'fake-new');
    await t.enterText(find.byKey(const ValueKey('legit_edit.brand')), 'Fake');
    await t.enterText(find.byKey(const ValueKey('legit_edit.model')), 'New');
    final sw = find.byKey(const ValueKey('legit_edit.switches.value'));
    await t.enterText(sw, 'Red, Blue ,');
    await settle(t, 400);
    await t.enterText(find.byKey(const ValueKey('legit_edit.switches.source')), 'not a url');
    await settle(t, 400);
    await settle(t, 400);
    await t.tap(find.byKey(const ValueKey('legit_edit.save')));
    await settle(t, 400);
    expect(find.textContaining('http(s) link', skipOffstage: false), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('legit_edit.switches.source')), 'https://example.com/spec');
    await settle(t, 400);
    await t.tap(find.byKey(const ValueKey('legit_edit.save')));
    await settle(t, 800);
    expect(api.calls, ['create']);
    final f = (api.lastBody as Map)['fields'] as Map;
    expect((f['switches'] as Map)['value'], ['Red', 'Blue']);
    expect(f['layout'], isNull);
    expect(find.byKey(const ValueKey('admin_legit.new')), findsOneWidget, reason: 'popped back to list');
  });

  testWidgets('legit: delete asks for confirmation', (t) async {
    useSize(t, const Size(412, 4000)); // tall so the whole form is built
    final api = FakeApi();
    await pump(t, const AdminLegitScreen(), api);
    await t.tap(find.byKey(const ValueKey('admin_legit.row.fake-board')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('legit_edit.delete')));
    await settle(t, 400);
    expect(api.calls, isEmpty);
    await t.tap(find.byKey(const ValueKey('legit_edit.delete_confirm.confirm')));
    await settle(t, 800);
    expect(api.calls, ['delete fake-board']);
  });

  testWidgets('profile: role sections and edit', (t) async {
    useSize(t, phoneSizes.first);
    final api = FakeApi();
    await pump(t, const ProfileScreen(), api, role: 'buyer');
    expect(find.byKey(const ValueKey('profile.orders')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile.builds')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile.payment_qr')), findsNothing);
    await t.scrollUntilVisible(find.byKey(const ValueKey('profile.about')), 300);
    expect(find.byKey(const ValueKey('profile.server')), findsOneWidget);
    await t.drag(find.byType(ListView).first, const Offset(0, 2000));
    await settle(t, 300);
    await t.tap(find.byKey(const ValueKey('profile.edit')));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('profile.edit.name')), 'New Name');
    await t.tap(find.byKey(const ValueKey('profile.edit.save')));
    await settle(t, 800);
    expect(api.calls, ['me New Name|Nowhere']);
    expect(find.text('New Name'), findsOneWidget);
  });

  testWidgets('profile: seller sees payment QR row, not orders', (t) async {
    useSize(t, phoneSizes.first);
    await pump(t, const ProfileScreen(), FakeApi(), role: 'seller');
    expect(find.byKey(const ValueKey('profile.payment_qr')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile.orders')), findsNothing);
  });
}
