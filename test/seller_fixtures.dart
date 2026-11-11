import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/models/legit.dart';
import 'package:keysthetic/models/listing.dart';
import 'package:keysthetic/models/user.dart';
import 'package:keysthetic/services/api.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:keysthetic/theme/app_theme.dart';
import 'package:keysthetic/widgets/legit_result_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// All data below is FAKE test data.
const _seller = UserSummary(id: 2, name: 'Test Seller', area: 'Test City');
Listing fakeListing(int id, {String status = 'active', String category = 'keyboard', LegitResult? legit}) => Listing(
      id: id, seller: _seller, title: 'Fake 75% hot-swap board with a long title to test wrapping', description: 'Fake description.',
      category: category, price: 4500, condition: 'like_new', kind: 'mechanical', layout: '75', connection: 'wired', meetupArea: 'Test City',
      photos: const ['/storage/fake/1.jpg', '/storage/fake/2.jpg'], status: status, legit: legit);

const fakeRef = LegitReference(id: 'fake-q1', brand: 'FakeBrand', model: 'Q1 Test', fields: {
  'layout': LegitField(value: '75', source: 'https://www.fakebrand.example/q1'),
  'switches': LegitField(value: ['Fake Red', 'Fake Brown'], source: 'https://fakebrand.example/switches'),
  'connection': null,
  'weight_g': null,
  'serial_format': null,
});

const fakeResult = LegitResult(
  referenceId: 'fake-q1', verdict: 'mods', verdictLabel: 'Declared mods', disclaimer: legitDisclaimer,
  fields: [
    LegitFieldResult(field: 'layout', label: 'Layout', expected: '75', given: '75', result: 'match'),
    LegitFieldResult(field: 'switch', label: 'Switches', expected: ['Fake Red', 'Fake Brown'], given: 'Fake Blue', result: 'mod', note: 'Declared in mods'),
    LegitFieldResult(field: 'connection', label: 'Connection', expected: 'wired', given: 'wireless', result: 'mismatch'),
    LegitFieldResult(field: 'weight_g', label: 'Weight', expected: null, given: 1800, result: 'unknown'),
  ],
);

class FakeApi extends Api {
  FakeApi({this.items = const [], this.deleteError}) : super(baseUrl: 'http://fake.test');
  final List<Listing> items;
  final ApiException? deleteError;
  @override
  Future<List<Listing>> listings({String? q, String? category, int? minPrice, int? maxPrice, String? condition, String? layout, String? connection, int? sellerId, int? buildId, String? sort}) async => items;
  @override
  Future<void> deleteListing(int id) async => deleteError != null ? throw deleteError! : null;
  @override
  Future<List<LegitReference>> legitReferences({String? q}) async => const [fakeRef];
  @override
  Future<User> me() async => const User(id: 2, email: 'x@fake.test', name: 'Test Seller', role: 'seller');
}

Future<void> pumpWith(WidgetTester t, Widget screen, {Api? api, ThemeMode mode = ThemeMode.light}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  await t.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(p), if (api != null) apiProvider.overrideWithValue(api)],
    child: MaterialApp(theme: buildTheme(Brightness.light), darkTheme: buildTheme(Brightness.dark), themeMode: mode, home: screen),
  ));
  await settle(t);
}

