import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keysthetic/models/user.dart';
import 'package:keysthetic/services/api.dart';
import 'package:keysthetic/services/providers.dart';
import 'package:keysthetic/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// All data here is FAKE, made up for tests and screenshots.

const kBuyerId = 14, kSellerId = 2;
const _listing = {
  'id': 5,
  'title': 'Tri-mode 75% hot-swap keyboard, thocky build',
  'price': 4500,
  'photo': '/storage/seed/photos/1_1.jpg',
  'status': 'active',
  'category': 'keyboard',
};
const _buyer = {'id': kBuyerId, 'name': 'Miguel Santos (fake)', 'area': 'SM City Calamba'};
const _seller = {'id': kSellerId, 'name': 'Renz Macaraeg (fake)', 'area': 'Paseo de Santa Rosa'};

/// In-memory stand-in for the server: one thread, one optional order.
class FakeCommerce {
  FakeCommerce({this.me = kBuyerId, this.orderStatus, this.method, this.hasQr = true, this.pendingFromSeller = true}) {
    var id = 0;
    Map<String, dynamic> msg(int sender, String kind, {String? body, int? amount}) => {
      'id': ++id,
      'thread_id': 1,
      'sender_id': sender,
      'kind': kind,
      'body': body,
      'amount': amount,
      'created_at': '2026-11-03T0$id:10:00.000Z',
    };
    msgs = [
      msg(kBuyerId, 'text', body: 'Hi! Is this still available?'),
      msg(kSellerId, 'text', body: 'Yes, still available.'),
      msg(kBuyerId, 'offer', amount: 3800, body: 'Can you do 3,800?'),
      if (pendingFromSeller) msg(kSellerId, 'counter', amount: 4300, body: 'Lowest I can go is 4,300.'),
    ];
    if (orderStatus != null) {
      msgs.add(msg(kBuyerId, 'accept', amount: 4300));
      history = [
        {'status': 'accepted', 'at': '2026-11-03T08:00:00.000Z'},
      ];
      if (orderStatus != 'accepted') {
        final path = {
          'meetup_set': ['meetup_set'],
          'awaiting_payment': ['awaiting_payment'],
          'payment_sent': ['awaiting_payment', 'payment_sent'],
          'paid': ['awaiting_payment', 'payment_sent', 'paid'],
          'handed_over': ['awaiting_payment', 'payment_sent', 'paid', 'handed_over'],
          'completed': ['awaiting_payment', 'payment_sent', 'paid', 'handed_over', 'completed'],
          'cancelled': ['cancelled'],
        }[orderStatus]!;
        var h = 9;
        for (final s in path) {
          history.add({'status': s, 'at': '2026-11-03T${(h++).toString().padLeft(2, '0')}:00:00.000Z'});
        }
      }
    }
    _nextId = id;
  }

  int me;
  String? orderStatus, method;
  bool hasQr, pendingFromSeller;
  late List<Map<String, dynamic>> msgs;
  List<Map<String, dynamic>> history = [];
  late int _nextId;
  final calls = <String>[];
  String? failNext; // e.g. 'POST /threads/1/accept' -> 409

  Map<String, dynamic>? get _pending {
    if (orderStatus != null) return null;
    for (final m in msgs.reversed) {
      if (m['kind'] == 'offer' || m['kind'] == 'counter') return m;
      if (m['kind'] == 'accept' || m['kind'] == 'decline') return null;
    }
    return null;
  }

  Map<String, dynamic> get thread => {
    'id': 1,
    'listing': _listing,
    'buyer': _buyer,
    'seller': _seller,
    'last_message': msgs.last,
    'pending_offer': _pending,
    'order_id': orderStatus == null ? null : 1,
    'updated_at': msgs.last['created_at'],
  };

  Map<String, dynamic> get order => {
    'id': 1,
    'listing': _listing,
    'buyer': _buyer,
    'seller': _seller,
    'price': 4300,
    'payment_method': method,
    'status': orderStatus,
    'meetup_note': note,
    'seller_qr_url': hasQr ? '/storage/seed/qr/3.png' : null,
    'thread_id': 1,
    'history': history,
    'created_at': '2026-11-03T08:00:00.000Z',
    'updated_at': '2026-11-03T08:00:00.000Z',
  };
  String? note;

  Map<String, dynamic> _add(int sender, String kind, {String? body, int? amount}) {
    final m = {
      'id': ++_nextId,
      'thread_id': 1,
      'sender_id': sender,
      'kind': kind,
      'body': body,
      'amount': amount,
      'created_at': '2026-11-03T12:00:00.000Z',
    };
    msgs.add(m);
    return m;
  }

  void _to(String s) {
    orderStatus = s;
    history.add({'status': s, 'at': '2026-11-03T12:30:00.000Z'});
  }

  http.Response _json(Object? b, [int code = 200]) =>
      http.Response(jsonEncode(b), code, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    final key = '${r.method} ${r.url.path}';
    calls.add(key);
    if (failNext == key) {
      failNext = null;
      return _json({'error': 'No pending offer to accept'}, 409);
    }
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    switch (key) {
      case 'GET /threads':
        return _json([thread]);
      case 'GET /threads/1':
        return _json(thread);
      case 'GET /threads/1/messages':
        final after = int.tryParse(r.url.queryParameters['after'] ?? '') ?? 0;
        return _json(msgs.where((m) => (m['id'] as int) > after).toList());
      case 'POST /threads/1/messages':
        return _json(_add(me, 'text', body: body['body'] as String), 201);
      case 'POST /threads/1/offer':
        return _json(_add(me, me == kBuyerId ? 'offer' : 'counter', amount: body['amount'] as int), 201);
      case 'POST /threads/1/decline':
        return _json(_add(me, 'decline'), 201);
      case 'POST /threads/1/accept':
        final m = _add(me, 'accept', amount: _pending?['amount'] as int?);
        orderStatus = 'accepted';
        history = [
          {'status': 'accepted', 'at': '2026-11-03T12:00:00.000Z'},
        ];
        return _json({'message': m, 'order': order});
      case 'GET /orders':
        return _json(orderStatus == null ? [] : [order]);
      case 'GET /orders/1':
        return _json(order);
      case 'POST /orders/1/checkout':
        method = body['payment_method'] as String;
        note = body['meetup_note'] as String;
        _to(method == 'qr' ? 'awaiting_payment' : 'meetup_set');
        return _json(order);
      case 'POST /orders/1/paid':
        _to('payment_sent');
      case 'POST /orders/1/confirm-payment':
        _to('paid');
      case 'POST /orders/1/handover':
        _to('handed_over');
      case 'POST /orders/1/complete':
        _to('completed');
      case 'POST /orders/1/cancel':
        _to('cancelled');
      default:
        return _json({'error': 'not found: $key'}, 404);
    }
    return _json(order);
  }
}

class _FakeApi extends Api {
  _FakeApi(FakeCommerce f) : super(baseUrl: 'http://fake.test', token: 't', client: MockClient(f.handle));
  // Real photos live in the demo bundle; reuse them so screenshots show images.
  @override
  ImageProvider mediaImage(String url) => AssetImage('assets/demo$url');
}

/// Pumps [screen] against [fake] signed in as `fake.me`.
Future<void> pumpWithFake(
  WidgetTester t,
  FakeCommerce fake,
  Widget screen, {
  ThemeMode mode = ThemeMode.light,
  String role = 'buyer',
}) async {
  final user = User(id: fake.me, email: 'x@keysthetic.demo', name: 'Fake', role: role);
  SharedPreferences.setMockInitialValues({
    'session.token': 't',
    'session.user': jsonEncode(user.toJson()),
    'session.base_url': 'http://fake.test',
  });
  final p = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(p), apiProvider.overrideWith((ref) => _FakeApi(fake))],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        home: screen,
      ),
    ),
  );
}

/// Pump with real-time gaps so mock-client futures complete (they use the event loop).
Future<void> settleIo(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 5)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> disposeTree(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  // let any in-flight request finish so its timeout timer is cancelled
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
  await t.pump();
}
