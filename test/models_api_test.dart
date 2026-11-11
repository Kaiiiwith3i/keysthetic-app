import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keysthetic/models/legit.dart';
import 'package:keysthetic/models/listing.dart';
import 'package:keysthetic/models/order.dart';
import 'package:keysthetic/models/thread.dart';
import 'package:keysthetic/services/api.dart';

// Fake sample shapes copied from API.md.
const _seller = {'id': 1, 'name': 'Ana Dizon', 'area': 'Calamba Crossing'};
const _summary = {'id': 10, 'title': 'Fake 75% board', 'price': 4500, 'photo': '/storage/photos/10_1.png', 'status': 'active', 'category': 'keyboard'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Listing.fromJson with nullable tags and legit', () {
    final l = Listing.fromJson({
      'id': 10, 'seller': _seller, 'title': 'Fake 75% board', 'description': 'd', 'category': 'keyboard', 'price': 4500,
      'condition': 'like_new', 'kind': 'mechanical', 'connection': 'wireless', 'layout': '75', 'switch_type': null,
      'stem': 'mx', 'connector': 'usb_c', 'meetup_area': 'SM Calamba', 'photos': ['/storage/photos/10_1.png'],
      'sound_url': null, 'status': 'active', 'created_at': 'x',
      'legit': {
        'reference_id': 'r', 'verdict': 'mods', 'verdict_label': 'Declared mods', 'label_photo_url': '/storage/a.png',
        'pcb_photo_url': null, 'disclaimer': 'd', 'checked_at': 'x',
        'fields': [{'field': 'layout', 'label': 'Layout', 'expected': '75', 'given': '75', 'result': 'match', 'note': ''}],
      },
    });
    expect(l.switchType, isNull);
    expect(l.photos.single, '/storage/photos/10_1.png');
    expect(l.legit!.fields.single.result, 'match');
  });

  test('Thread, Message, Order parse', () {
    final msg = {'id': 40, 'thread_id': 5, 'sender_id': 2, 'kind': 'offer', 'body': 'Can you do 4,000?', 'amount': 4000, 'created_at': 'x'};
    final t = Thread.fromJson({'id': 5, 'listing': _summary, 'buyer': _seller, 'seller': _seller, 'last_message': msg, 'pending_offer': msg, 'order_id': null, 'updated_at': 'x'});
    expect(t.pendingOffer!.amount, 4000);
    final o = Order.fromJson({
      'id': 7, 'listing': _summary, 'buyer': _seller, 'seller': _seller, 'price': 4000, 'payment_method': null, 'status': 'accepted',
      'meetup_note': null, 'seller_qr_url': null, 'thread_id': 5, 'history': [{'status': 'accepted', 'at': 'x'}], 'created_at': 'x', 'updated_at': 'x',
    });
    expect(o.history.single.status, 'accepted');
  });

  test('LegitReference allows null fields and list values', () {
    final r = LegitReference.fromJson({'id': 'a', 'brand': 'B', 'model': 'M', 'fields': {
      'layout': {'value': '75', 'source': 's', 'accessed': 'd'},
      'switches': {'value': ['x', 'y'], 'source': 's', 'accessed': 'd'},
      'weight_g': null,
    }});
    expect(r.fields['weight_g'], isNull);
    expect(r.fields['switches']!.value, ['x', 'y']);
  });

  test('normalizeBaseUrl', () {
    expect(normalizeBaseUrl(' 192.168.1.5:8080/ '), 'http://192.168.1.5:8080');
    expect(normalizeBaseUrl('https://a.b'), 'https://a.b');
  });

  test('server errors become ApiException; bearer token is sent', () async {
    String? auth;
    final api = Api(baseUrl: 'http://x', token: 'tok', client: MockClient((req) async {
      auth = req.headers['Authorization'];
      return http.Response(jsonEncode({'error': 'Wrong state'}), 409);
    }));
    await expectLater(api.completeOrder(3), throwsA(isA<ApiException>().having((e) => e.status, 'status', 409).having((e) => e.message, 'message', 'Wrong state')));
    expect(auth, 'Bearer tok');
  });

  test('demo mode: writes throw DemoModeException, reads come from the bundle, media uses assets', () async {
    Api.resetDemoCache();
    final api = Api(demo: true);
    await expectLater(api.createOrder(1), throwsA(isA<DemoModeException>()));
    expect(await api.listings(), isA<List<Listing>>());
    expect((await api.me()).name, isNotEmpty);
    expect(api.mediaImage('/storage/seed/photos/1.png').toString(), contains('assets/demo/storage/seed/photos/1.png'));
    expect(Api(baseUrl: 'http://h:8080').mediaImage('/storage/a.png').toString(), contains('http://h:8080/storage/a.png'));
  });

  test('the bundled demo.json parses through every model', () async {
    Api.resetDemoCache();
    final api = Api(demo: true);
    final listings = await api.listings();
    expect((await api.me()).role, 'buyer');
    await api.builds();
    final threads = await api.threads();
    if (threads.isNotEmpty) await api.messages(threads.first.id);
    await api.orders();
    await api.legitReferences();
    await api.adminListings();
    // ignore: avoid_print
    print('demo bundle: ${listings.length} listings, ${threads.length} threads');
  });
}
