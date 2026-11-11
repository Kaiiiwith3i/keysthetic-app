// Shared helpers for the end-to-end flows. Everything here runs on the Android
// emulator against the live server at http://10.0.2.2:8080.
//
// UI drives the behaviour a flow is named after; direct HTTP (class [Srv]) is used
// only for preconditions (fresh users, listings, builds) and to cross-check results.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:keysthetic/app.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the user types on the Connect screen (the Mac as seen from the emulator).
const serverAddress = '10.0.2.2:8080';
const serverBase = 'http://10.0.2.2:8080';
const testPassword = 'e2e-pass-1234';
const demoPassword = 'demo1234';
const adminEmail = 'admin@keysthetic.demo';

/// Unique per run so reruns never collide on emails or listing titles.
final String runId = DateTime.now().millisecondsSinceEpoch.toString();
int _seq = 0;
String uniq([String prefix = 'e2e']) => '$prefix${runId.substring(runId.length - 7)}${_seq++}';

// ---------------------------------------------------------------- pumping

/// Visible text and keys on screen, appended to timeouts so a failure says what the user would have seen.
String screenDump() {
  final texts = <String>[], keys = <String>[];
  for (final e in find.byType(Text).evaluate().take(60)) {
    final d = (e.widget as Text).data;
    if (d != null && d.trim().isNotEmpty) texts.add(d.replaceAll('\n', ' '));
  }
  for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String>).evaluate().take(60)) {
    keys.add((e.widget.key! as ValueKey<String>).value);
  }
  return '\n  on screen text: $texts\n  on screen keys: $keys';
}

/// Polls frames (real time) until [cond] is true. No fixed long sleeps.
Future<void> pumpUntil(WidgetTester t, bool Function() cond,
    {Duration timeout = const Duration(seconds: 25), String what = 'condition'}) async {
  lastAction = 'waiting for $what';
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > timeout) {
      throw TestFailure('Timed out after ${timeout.inSeconds}s waiting for $what${screenDump()}');
    }
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pump(const Duration(milliseconds: 50));
}

Future<void> pumpUntilFound(WidgetTester t, Finder f,
        {Duration timeout = const Duration(seconds: 25)}) =>
    pumpUntil(t, () => f.evaluate().isNotEmpty, timeout: timeout, what: 'to find ${f.describeMatch(Plurality.one)}');

Future<void> pumpUntilGone(WidgetTester t, Finder f,
        {Duration timeout = const Duration(seconds: 25)}) =>
    pumpUntil(t, () => f.evaluate().isEmpty, timeout: timeout, what: 'to lose ${f.describeMatch(Plurality.one)}');

/// A few frames so a transition or a sheet finishes (bounded, not a wait for state).
Future<void> settle(WidgetTester t, [int ms = 400]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Finder k(String key) => find.byKey(ValueKey(key));

/// First vertical Scrollable on screen (the page body, or the sheet in front).
final _vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

/// Waits for [f], scrolls it into view when its page scrolls.
Future<void> reveal(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 25), bool low = false}) async {
  final sw = Stopwatch()..start();
  while (f.evaluate().isEmpty) {
    if (sw.elapsed > timeout) throw TestFailure('Timed out waiting for ${f.describeMatch(Plurality.one)}${screenDump()}');
    if (_vertical.hitTestable().evaluate().isNotEmpty) {
      if (low) {
        await _dragLow(t, -220);
      } else {
        // outermost scrollable: a multiline text field's own scrollable is nested inside it
        await t.drag(_vertical.hitTestable().first, const Offset(0, -220), warnIfMissed: false);
      }
    }
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 100));
}

/// Drags from low on the screen: a pan on a widget in the middle (e.g. the build's
/// KeyboardLayers) would tilt it instead of scrolling the page.
Future<void> _dragLow(WidgetTester t, double dy) async {
  final size = t.view.physicalSize / t.view.devicePixelRatio;
  await t.dragFrom(Offset(size.width / 2, size.height * (dy < 0 ? 0.8 : 0.5)), Offset(0, dy));
}

/// Scrolls the page in front back to its top.
Future<void> scrollToTop(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await _dragLow(t, 700);
    await t.pump(const Duration(milliseconds: 100));
  }
  await settle(t, 300);
}

Future<void> tap(WidgetTester t, Finder f, {bool low = false}) async {
  lastAction = 'tap ${f.describeMatch(Plurality.one)}';
  await reveal(t, f, low: low);
  if (f.evaluate().isEmpty) throw TestFailure('${f.describeMatch(Plurality.one)} disappeared before the tap${screenDump()}');
  // A snackbar (4 s) can sit over bottom buttons; wait for it to leave instead of tapping the snackbar.
  await pumpUntil(t, () => f.hitTestable().evaluate().isNotEmpty,
      timeout: const Duration(seconds: 8), what: '${f.describeMatch(Plurality.one)} to be tappable (not covered)');
  await t.tap(f.first, warnIfMissed: true);
  await t.pump(const Duration(milliseconds: 150));
}

Future<void> tapKey(WidgetTester t, String key, {bool low = false}) => tap(t, k(key), low: low);

Future<void> typeIn(WidgetTester t, String key, String text) async {
  await reveal(t, k(key));
  await t.enterText(k(key), text);
  await t.pump(const Duration(milliseconds: 100));
}

/// Any widget whose key starts with [prefix] (e.g. `feed.card.`).
Finder keyed(String prefix) => find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey && key.value is String && (key.value as String).startsWith(prefix);
    });

// ---------------------------------------------------------------- app lifecycle

/// The most recent tap/type/wait, for the layout-error report above.
String lastAction = '(none)';
bool _hooked = false;

/// Layout errors (e.g. a RenderFlex overflow) fail the test at the end; this also prints
/// which screen was showing when it happened, so the failure can be located.
void _logLayoutErrors() {
  if (_hooked) return;
  _hooked = true;
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exception.toString().contains('overflowed')) {
      // Describe the render object now, while it is alive (the default report runs after it was disposed).
      final info = d.informationCollector?.call().map((n) => n.toStringDeep()).join('\n') ?? '';
      // ignore: avoid_print
      print('LAYOUT ERROR (${d.exception.toString().split('\n').first}); last action: $lastAction; showing:${screenDump()}\n$info');
    }
    prev?.call(d);
  };
}

/// Cold start of the real app (same widget tree as `main()`), with a clean
/// SharedPreferences so no session or server address survives from a past run.
Future<void> launchApp(WidgetTester t) async {
  _logLayoutErrors();
  await t.pumpWidget(const SizedBox.shrink()); // unmount a previous app
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await t.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const KeystheticApp()));
  await t.pump(const Duration(milliseconds: 300));
}

/// Cold start already signed in as [a] (session written to SharedPreferences, the same keys the app
/// persists). Used by the perf run, which measures frames, not typing; `flutter drive --profile`
/// does not route `enterText` to the test text field the way `flutter test` does.
Future<void> launchSignedIn(WidgetTester t, Account a) async {
  await t.pumpWidget(const SizedBox.shrink());
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setString('session.base_url', serverBase);
  await prefs.setString('session.token', a.token);
  await prefs.setString('session.user', jsonEncode(a.user));
  await t.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const KeystheticApp()));
  await pumpUntilFound(t, k('nav.profile'));
  await settle(t);
}

/// Connect screen: type the address, Test connection, Continue.
Future<void> connect(WidgetTester t, {String address = serverAddress}) async {
  await pumpUntilFound(t, k('connect.url'));
  await t.enterText(k('connect.url'), address);
  await tapKey(t, 'connect.test');
  await pumpUntilFound(t, find.text('Connected. The server is up.'));
  await tapKey(t, 'connect.continue');
  await pumpUntilFound(t, k('auth.email'));
}

/// Login screen -> signed-in shell.
Future<void> login(WidgetTester t, String email, String password) async {
  await pumpUntilFound(t, k('auth.email'));
  await t.enterText(k('auth.email'), email);
  await t.enterText(k('auth.password'), password);
  await tapKey(t, 'auth.submit');
  await pumpUntilFound(t, k('nav.profile'));
  await settle(t);
}

/// Fresh launch, connect, sign in.
Future<void> startAs(WidgetTester t, String email, String password) async {
  await launchApp(t);
  await connect(t);
  await login(t, email, password);
}

/// Profile -> Sign out, back to the Login screen.
Future<void> logout(WidgetTester t) async {
  await backToShell(t);
  await tapKey(t, 'nav.profile');
  await tapKey(t, 'profile.signout');
  await pumpUntilFound(t, k('auth.email'));
  await settle(t);
}

/// Sign out and sign in as someone else through the UI.
Future<void> switchTo(WidgetTester t, String email, String password) async {
  await logout(t);
  await login(t, email, password);
}

/// Types [text] in the Search tab and waits until the filtered results have loaded.
Future<void> searchFor(WidgetTester t, String text) async {
  await tapKey(t, 'nav.search');
  await t.enterText(k('search.field'), text);
  await settle(t, 600); // the field debounces 350 ms, then the list reloads
  await pumpUntilGone(t, keyed('feed.skeleton.'));
}

// ---------------------------------------------------------------- HTTP (preconditions + cross-checks)

class Account {
  Account(this.token, this.user, this.password);
  final String token;
  final Map<String, dynamic> user;
  final String password;
  int get id => user['id'] as int;
  String get email => user['email'] as String;
  String get name => user['name'] as String;
}

http.Request _copy(http.Request r) => http.Request(r.method, r.url)
  ..headers.addAll(r.headers)
  ..body = r.body;

class Srv {
  static Future<dynamic> call(String method, String path,
      {String? token, Object? body, Map<String, String>? query, int? expect}) async {
    final uri = Uri.parse('$serverBase$path').replace(queryParameters: query);
    final req = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'});
    if (body != null) req.body = jsonEncode(body);
    // The emulator<->host link occasionally aborts a connection ("Software caused connection abort");
    // retry transport errors only, never HTTP error statuses.
    late http.Response res;
    for (var attempt = 1;; attempt++) {
      try {
        res = await http.Response.fromStream(await _copy(req).send().timeout(const Duration(seconds: 15)));
        break;
      } on http.ClientException {
        if (attempt == 3) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    final ok = expect != null ? res.statusCode == expect : res.statusCode < 300;
    if (!ok) throw TestFailure('$method $path -> ${res.statusCode} ${res.body}');
    return res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<Account> register(String role, {String? name}) async {
    final id = uniq(role);
    final email = '$id@e2e.test';
    final j = await call('POST', '/auth/register', expect: 201, body: {
      'email': email,
      'password': testPassword,
      'name': name ?? 'E2E ${role[0].toUpperCase()}${role.substring(1)} $id',
      'role': role,
      'area': 'Calamba Crossing',
    }) as Map<String, dynamic>;
    return Account(j['token'] as String, j['user'] as Map<String, dynamic>, testPassword);
  }

  static Future<Account> loginAs(String email, String password) async {
    final j = await call('POST', '/auth/login', body: {'email': email, 'password': password}) as Map<String, dynamic>;
    return Account(j['token'] as String, j['user'] as Map<String, dynamic>, password);
  }

  static Future<String> upload(Account a, {String kind = 'photo', String filename = 'e2e.png'}) async {
    final j = await call('POST', '/uploads',
        token: a.token, expect: 201, body: {'kind': kind, 'filename': filename, 'data_base64': base64Encode(makePng())});
    return j['url'] as String;
  }

  /// A listing with a real uploaded photo. Tags are passed through as given.
  static Future<Map<String, dynamic>> listing(Account seller,
      {required String title,
      int price = 4500,
      String category = 'keyboard',
      Map<String, dynamic> tags = const {}}) async {
    final photo = await upload(seller);
    return await call('POST', '/listings', token: seller.token, expect: 201, body: {
      'title': title,
      'description': 'Fake E2E listing created by the integration tests.',
      'category': category,
      'price': price,
      'condition': 'used',
      'meetup_area': 'SM Calamba',
      'photos': [photo],
      ...tags,
    }) as Map<String, dynamic>;
  }

  /// Gives the seller a payment QR so QR checkout is allowed.
  static Future<void> setQr(Account seller) async {
    final qr = await upload(seller, kind: 'qr', filename: 'qr.png');
    await call('PUT', '/me', token: seller.token, body: {'payment_qr_url': qr});
  }

  static Future<Map<String, dynamic>> order(String id, Account who) async =>
      await call('GET', '/orders/$id', token: who.token) as Map<String, dynamic>;

  static Future<List<dynamic>> listingsMatching(String q, {String? token, Map<String, String> extra = const {}}) async =>
      await call('GET', '/listings', token: token, query: {'q': q, ...extra}) as List<dynamic>;
}

/// Server states every demo (HTTP) check relies on.
Future<bool> serverIsUp() async {
  try {
    final r = await http.get(Uri.parse('$serverBase/health')).timeout(const Duration(seconds: 4));
    return r.statusCode == 200;
  } on Exception {
    return false;
  }
}

// ---------------------------------------------------------------- fake photo picker

/// A small valid PNG (gradient), encoded by hand so the tests need no asset or package.
Uint8List makePng({int w = 96, int h = 64}) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < w; x++) {
      raw.add([(x * 255 ~/ w), (y * 255 ~/ h), 160]);
    }
  }
  final crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var i = 0; i < 8; i++) {
      c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });
  int crc(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c = crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  Uint8List u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);
  List<int> chunk(String type, List<int> data) {
    final td = [...ascii.encode(type), ...data];
    return [...u32(data.length), ...td, ...u32(crc(td))];
  }

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...chunk('IHDR', [...u32(w), ...u32(h), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', zlib.encode(raw.toBytes())),
    ...chunk('IEND', const []),
  ]);
}

/// Stands in for the system gallery/camera: always "picks" the same PNG file.
class FakeImagePicker extends ImagePickerPlatform {
  FakeImagePicker(this.file);
  final File file;
  int picks = 0;

  /// Writes the PNG to a temp dir and installs the fake as `ImagePickerPlatform.instance`.
  static Future<FakeImagePicker> install() async {
    final dir = await Directory.systemTemp.createTemp('ks_e2e_');
    final f = File('${dir.path}/e2e_photo.png')..writeAsBytesSync(makePng());
    final fake = FakeImagePicker(f);
    ImagePickerPlatform.instance = fake;
    return fake;
  }

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    picks++;
    return XFile(file.path, name: 'e2e_photo.png', mimeType: 'image/png');
  }
}

/// Opens a PhotoItem tile's picker sheet and takes the gallery option.
Future<void> pickFromGallery(WidgetTester t, Finder addTile) async {
  await tap(t, addTile);
  await tapKey(t, 'photo.gallery');
  await settle(t, 600);
}

/// Pops every pushed screen (AppBar back button) until the tab shell is in front.
Future<void> backToShell(WidgetTester t) async {
  for (var i = 0; i < 8 && find.byType(BackButton).evaluate().isNotEmpty; i++) {
    await t.pageBack();
    await settle(t, 500);
  }
}

/// The server-side order for [listingId] as seen by [who].
Future<Map<String, dynamic>> orderForListing(Account who, Object listingId) async {
  final list = await Srv.call('GET', '/orders', token: who.token) as List;
  return list.cast<Map<String, dynamic>>().singleWhere((o) => o['listing']['id'] == listingId);
}
