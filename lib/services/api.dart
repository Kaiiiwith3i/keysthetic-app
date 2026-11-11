import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../models/build.dart';
import '../models/legit.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/thread.dart';
import '../models/user.dart';

class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'ApiException($status): $message';
}

/// Thrown by every write method while in Demo mode.
class DemoModeException implements Exception {
  const DemoModeException();
  static const message = 'Connect to a server to do this';
  @override
  String toString() => message;
}

/// "192.168.1.5:8080" -> "http://192.168.1.5:8080" (no trailing slash).
String normalizeBaseUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
  return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}

/// The one gateway to the server (and to the offline demo bundle).
/// Built by `apiProvider` whenever the session changes.
class Api {
  Api({this.baseUrl, this.token, this.demo = false, http.Client? client})
      : _client = client ?? http.Client();

  final String? baseUrl, token;
  final bool demo;
  final http.Client _client;

  static Map<String, dynamic>? _demoCache;

  // ---- media ----

  /// `NetworkImage(base+url)` live, `AssetImage('assets/demo'+url)` in demo.
  ImageProvider mediaImage(String url) =>
      demo ? AssetImage('assets/demo$url') : NetworkImage('${baseUrl ?? ''}$url');

  // ---- plumbing ----

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, String?> query = const {}}) async {
    final q = {for (final e in query.entries) if (e.value != null && e.value!.isNotEmpty) e.key: e.value!};
    final uri = Uri.parse('${baseUrl ?? ''}$path').replace(queryParameters: q.isEmpty ? null : q);
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response r;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      r = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 12)));
    } on Exception catch (e) {
      throw ApiException(0, 'Cannot reach the server (${e.runtimeType}). Check the address and Wi-Fi.');
    }
    dynamic data;
    try {
      data = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      data = null;
    }
    if (r.statusCode >= 400) {
      final msg = data is Map && data['error'] is String ? data['error'] as String : 'Request failed (${r.statusCode})';
      throw ApiException(r.statusCode, msg);
    }
    return data;
  }

  /// Reads in demo mode are served from the bundle via [demoRead]; paths with no demo equivalent return an empty list.
  Future<dynamic> _get(String path, {Map<String, String?> query = const {}, dynamic Function(Map<String, dynamic> demo)? demoRead}) async {
    if (demo) return demoRead != null ? demoRead(await _demoData()) : <dynamic>[];
    return _send('GET', path, query: query);
  }

  Future<dynamic> _write(String method, String path, [Object? body]) {
    if (demo) throw const DemoModeException();
    return _send(method, path, body: body);
  }

  Future<Map<String, dynamic>> _demoData() async {
    if (_demoCache != null) return _demoCache!;
    try {
      return _demoCache = jsonDecode(await rootBundle.loadString('assets/demo/demo.json')) as Map<String, dynamic>;
    } catch (_) {
      return _demoCache = {};
    }
  }

  @visibleForTesting
  static void resetDemoCache() => _demoCache = null;

  static List _list(Map<String, dynamic> d, String k) => (d[k] as List?) ?? const [];
  static Map<String, dynamic> _buyer(Map<String, dynamic> d) => (d['as_buyer'] as Map<String, dynamic>?) ?? const {};

  // ---- health & auth ----

  Future<bool> health() async => (await _send('GET', '/health') as Map)['ok'] == true;

  Future<({String token, User user})> register(
      {required String email, required String password, required String name, required String role, required String area}) async {
    final j = await _write('POST', '/auth/register',
        {'email': email, 'password': password, 'name': name, 'role': role, 'area': area}) as Map<String, dynamic>;
    return (token: j['token'] as String, user: User.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<({String token, User user})> login(String email, String password) async {
    final j = await _write('POST', '/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    return (token: j['token'] as String, user: User.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<void> logout() => _write('POST', '/auth/logout');

  Future<User> me() async => User.fromJson(await _get('/me', demoRead: (d) => _buyer(d)['user'] as Map<String, dynamic>) as Map<String, dynamic>);

  Future<User> updateMe({String? name, String? area, String? paymentQrUrl}) async => User.fromJson(await _write('PUT', '/me', {
        'name': ?name,
        'area': ?area,
        'payment_qr_url': ?paymentQrUrl,
      }) as Map<String, dynamic>);

  /// kind: photo | qr | sound | legit. Returns the stored `/storage/...` path.
  Future<String> upload({required String kind, required String filename, required List<int> bytes}) async {
    final j = await _write('POST', '/uploads', {'kind': kind, 'filename': filename, 'data_base64': base64Encode(bytes)});
    return (j as Map<String, dynamic>)['url'] as String;
  }

  // ---- listings ----

  Future<List<Listing>> listings({
    String? q, String? category, int? minPrice, int? maxPrice, String? condition,
    String? layout, String? connection, int? sellerId, int? buildId, String? sort,
  }) async {
    final r = await _get('/listings', query: {
      'q': q, 'category': category, 'min_price': minPrice?.toString(), 'max_price': maxPrice?.toString(),
      'condition': condition, 'layout': layout, 'connection': connection, 'seller_id': sellerId?.toString(),
      'build_id': buildId?.toString(), 'sort': sort,
    }, demoRead: (d) => _filterDemo(_list(d, 'listings'), q, category, minPrice, maxPrice, condition, layout, connection, sellerId, sort));
    return (r as List).map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ponytail: demo filtering covers the common filters only; build_id fit is server-side.
  List _filterDemo(List all, String? q, String? category, int? minP, int? maxP, String? cond, String? layout, String? conn, int? seller, String? sort) {
    final out = all.where((e) {
      final l = e as Map<String, dynamic>;
      if (l['status'] == 'hidden' && l['seller']?['id'] != seller) return false;
      if (q != null && q.isNotEmpty && !('${l['title']} ${l['description']}'.toLowerCase().contains(q.toLowerCase()))) return false;
      if (category != null && l['category'] != category) return false;
      if (minP != null && (l['price'] as int) < minP) return false;
      if (maxP != null && (l['price'] as int) > maxP) return false;
      if (cond != null && l['condition'] != cond) return false;
      if (layout != null && l['layout'] != layout) return false;
      if (conn != null && l['connection'] != conn) return false;
      if (seller != null && l['seller']?['id'] != seller) return false;
      return true;
    }).toList();
    if (sort == 'price_asc') out.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));
    if (sort == 'price_desc') out.sort((a, b) => (b['price'] as int).compareTo(a['price'] as int));
    return out;
  }

  Future<Listing> listing(int id) async => Listing.fromJson(await _get('/listings/$id', demoRead: (d) {
        return _list(d, 'listings').cast<Map<String, dynamic>>().firstWhere((l) => l['id'] == id,
            orElse: () => throw const ApiException(404, 'Listing not found'));
      }) as Map<String, dynamic>);

  Future<Listing> createListing(Map<String, dynamic> body) async =>
      Listing.fromJson(await _write('POST', '/listings', body) as Map<String, dynamic>);
  Future<Listing> updateListing(int id, Map<String, dynamic> body) async =>
      Listing.fromJson(await _write('PUT', '/listings/$id', body) as Map<String, dynamic>);
  Future<void> deleteListing(int id) => _write('DELETE', '/listings/$id');

  // ---- builds ----

  Future<List<Build>> builds() async => ((await _get('/builds', demoRead: (d) => _list(_buyer(d), 'builds'))) as List)
      .map((e) => Build.fromJson(e as Map<String, dynamic>)).toList();
  Future<Build> createBuild({required String name, String? layout, String? stem, String? connector}) async =>
      Build.fromJson(await _write('POST', '/builds', {'name': name, 'layout': layout, 'stem': stem, 'connector': connector}) as Map<String, dynamic>);
  /// [slots] maps slot name -> listing id (null clears). Omit to leave slots alone.
  Future<Build> updateBuild(int id, {String? name, String? layout, String? stem, String? connector, Map<String, int?>? slots}) async =>
      Build.fromJson(await _write('PUT', '/builds/$id', {
        'name': ?name,
        'layout': ?layout,
        'stem': ?stem,
        'connector': ?connector,
        'slots': ?slots,
      }) as Map<String, dynamic>);
  Future<void> deleteBuild(int id) => _write('DELETE', '/builds/$id');

  // ---- chat & offers ----

  Future<Thread> createThread(int listingId) async =>
      Thread.fromJson(await _write('POST', '/threads', {'listing_id': listingId}) as Map<String, dynamic>);
  Future<List<Thread>> threads() async => ((await _get('/threads', demoRead: (d) => _list(_buyer(d), 'threads'))) as List)
      .map((e) => Thread.fromJson(e as Map<String, dynamic>)).toList();
  Future<Thread> thread(int id) async => Thread.fromJson(await _get('/threads/$id', demoRead: (d) {
        return _list(_buyer(d), 'threads').cast<Map<String, dynamic>>().firstWhere((t) => t['id'] == id,
            orElse: () => throw const ApiException(404, 'Thread not found'));
      }) as Map<String, dynamic>);
  /// Poll with [after] (last seen message id) every ~3 s.
  Future<List<Message>> messages(int threadId, {int? after}) async =>
      ((await _get('/threads/$threadId/messages', query: {'after': after?.toString()}, demoRead: (d) {
        // The bundle keys messages by thread id ({"7": [...]}); a flat list is accepted too.
        final raw = _buyer(d)['messages'];
        final all = raw is Map ? (raw['$threadId'] as List? ?? const []) : (raw as List? ?? const []);
        return all.cast<Map<String, dynamic>>()
            .where((m) => m['thread_id'] == threadId && (after == null || (m['id'] as int) > after)).toList();
      })) as List).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  Future<Message> sendMessage(int threadId, String body) async =>
      Message.fromJson(await _write('POST', '/threads/$threadId/messages', {'body': body}) as Map<String, dynamic>);
  Future<Message> sendOffer(int threadId, int amount, {String? body}) async =>
      Message.fromJson(await _write('POST', '/threads/$threadId/offer', {'amount': amount, 'body': ?body}) as Map<String, dynamic>);
  Future<({Message message, Order order})> acceptOffer(int threadId) async {
    final j = await _write('POST', '/threads/$threadId/accept') as Map<String, dynamic>;
    return (message: Message.fromJson(j['message'] as Map<String, dynamic>), order: Order.fromJson(j['order'] as Map<String, dynamic>));
  }
  Future<Message> declineOffer(int threadId) async =>
      Message.fromJson(await _write('POST', '/threads/$threadId/decline') as Map<String, dynamic>);

  // ---- orders ----

  Future<Order> createOrder(int listingId) async =>
      Order.fromJson(await _write('POST', '/orders', {'listing_id': listingId}) as Map<String, dynamic>);
  /// [role]: buyer | seller | null for both.
  Future<List<Order>> orders({String? role}) async => ((await _get('/orders', query: {'role': role}, demoRead: (d) => _list(_buyer(d), 'orders'))) as List)
      .map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  Future<Order> order(int id) async => Order.fromJson(await _get('/orders/$id', demoRead: (d) {
        return _list(_buyer(d), 'orders').cast<Map<String, dynamic>>().firstWhere((o) => o['id'] == id,
            orElse: () => throw const ApiException(404, 'Order not found'));
      }) as Map<String, dynamic>);
  Future<Order> _orderAction(int id, String action, [Object? body]) async =>
      Order.fromJson(await _write('POST', '/orders/$id/$action', body) as Map<String, dynamic>);
  /// [paymentMethod]: cod | qr.
  Future<Order> checkout(int id, {required String paymentMethod, required String meetupNote}) =>
      _orderAction(id, 'checkout', {'payment_method': paymentMethod, 'meetup_note': meetupNote});
  Future<Order> markPaid(int id) => _orderAction(id, 'paid');
  Future<Order> confirmPayment(int id) => _orderAction(id, 'confirm-payment');
  Future<Order> handover(int id) => _orderAction(id, 'handover');
  Future<Order> completeOrder(int id) => _orderAction(id, 'complete');
  Future<Order> cancelOrder(int id) => _orderAction(id, 'cancel');

  // ---- legit check ----

  Future<List<LegitReference>> legitReferences({String? q}) async =>
      ((await _get('/legit/references', query: {'q': q}, demoRead: (d) {
        return _list(d, 'legit_references').cast<Map<String, dynamic>>().where((r) =>
            q == null || q.isEmpty || '${r['brand']} ${r['model']}'.toLowerCase().contains(q.toLowerCase())).toList();
      })) as List).map((e) => LegitReference.fromJson(e as Map<String, dynamic>)).toList();
  Future<LegitReference> legitReference(String id) async =>
      LegitReference.fromJson(await _get('/legit/references/$id', demoRead: (d) {
        return _list(d, 'legit_references').cast<Map<String, dynamic>>().firstWhere((r) => r['id'] == id,
            orElse: () => throw const ApiException(404, 'Reference not found'));
      }) as Map<String, dynamic>);
  /// Body keys per API.md: reference_id, listing_id?, serial, weight_g?, layout, switch, connection, opened, mods, label_photo_url, pcb_photo_url?
  Future<LegitResult> legitCheck(Map<String, dynamic> body) async =>
      LegitResult.fromJson(await _write('POST', '/legit/check', body) as Map<String, dynamic>);

  // ---- admin ----

  Future<List<User>> adminUsers() async => ((await _get('/admin/users')) as List)
      .map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  Future<User> banUser(int id, bool banned) async =>
      User.fromJson(await _write('POST', '/admin/users/$id/ban', {'banned': banned}) as Map<String, dynamic>);
  Future<List<Listing>> adminListings({String? status}) async =>
      ((await _get('/admin/listings', query: {'status': status}, demoRead: (d) => _list(d, 'listings'))) as List)
          .map((e) => Listing.fromJson(e as Map<String, dynamic>)).toList();
  Future<Listing> hideListing(int id, bool hidden) async =>
      Listing.fromJson(await _write('POST', '/admin/listings/$id/hide', {'hidden': hidden}) as Map<String, dynamic>);
  Future<void> adminCreateReference(Map<String, dynamic> ref) => _write('POST', '/admin/legit/references', ref);
  Future<void> adminUpdateReference(String id, Map<String, dynamic> ref) => _write('PUT', '/admin/legit/references/$id', ref);
  Future<void> adminDeleteReference(String id) => _write('DELETE', '/admin/legit/references/$id');
}
