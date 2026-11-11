import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/screens/chat_list_screen.dart';
import 'package:keysthetic/screens/chat_thread_screen.dart';
import 'package:keysthetic/screens/checkout_screen.dart';
import 'package:keysthetic/screens/order_detail_screen.dart';
import 'package:keysthetic/screens/orders_screen.dart';

import 'fake_commerce.dart';
import 'helpers.dart';

Finder k(String key) => find.byKey(ValueKey(key));

/// Fake data only (see fake_commerce.dart).
void main() {
  group('no overflow @360/412 x1.3 light+dark', () {
    final cases = <String, (FakeCommerce Function(), Widget)>{
      'chat list': (() => FakeCommerce(), const ChatListScreen()),
      'thread (pending counter)': (() => FakeCommerce(), const ChatThreadScreen(threadId: 1)),
      'thread (order exists)': (() => FakeCommerce(orderStatus: 'accepted'), const ChatThreadScreen(threadId: 1)),
      'orders': (() => FakeCommerce(orderStatus: 'awaiting_payment', method: 'qr'), const OrdersScreen()),
      'checkout form': (() => FakeCommerce(orderStatus: 'accepted'), const CheckoutScreen(orderId: 1)),
      'checkout no QR': (() => FakeCommerce(orderStatus: 'accepted', hasQr: false), const CheckoutScreen(orderId: 1)),
      'checkout pay step': (
        () => FakeCommerce(orderStatus: 'awaiting_payment', method: 'qr'),
        const CheckoutScreen(orderId: 1),
      ),
      'order detail (buyer, qr)': (
        () => FakeCommerce(orderStatus: 'awaiting_payment', method: 'qr'),
        const OrderDetailScreen(orderId: 1),
      ),
      'order detail (cancelled)': (() => FakeCommerce(orderStatus: 'cancelled'), const OrderDetailScreen(orderId: 1)),
      'order detail (completed)': (
        () => FakeCommerce(orderStatus: 'completed', method: 'qr'),
        const OrderDetailScreen(orderId: 1),
      ),
    };
    for (final size in phoneSizes) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        for (final e in cases.entries) {
          testWidgets('${e.key} @${size.width.toInt()} ${mode.name}', (t) async {
            useSize(t, size, textScale: 1.3);
            await pumpWithFake(t, e.value.$1(), e.value.$2, mode: mode);
            await settleIo(t);
            expect(t.takeException(), isNull);
            // scroll to the bottom of anything scrollable: actions must fit too
            final list = find.byType(Scrollable).first;
            await t.drag(list, const Offset(0, -2000));
            await settleIo(t, 300);
            expect(t.takeException(), isNull);
            await disposeTree(t);
          });
        }
      }
    }
  });

  testWidgets('seller offer sheet + keypad @360 x1.3 has no overflow', (t) async {
    useSize(t, phoneSizes.first, textScale: 1.3);
    await pumpWithFake(
      t,
      FakeCommerce(me: kSellerId, pendingFromSeller: false),
      const ChatThreadScreen(threadId: 1),
      role: 'seller',
    );
    await settleIo(t);
    await t.tap(k('chat.offer'));
    await settleIo(t, 600);
    for (final d in ['4', '2', '0', '0']) {
      await t.tap(k('offer.key.$d'));
      await t.pump();
    }
    expect(find.descendant(of: k('offer.display'), matching: find.text('₱4,200')), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeTree(t);
  });

  testWidgets('haggle -> accept -> checkout (QR) -> paid, via the UI', (t) async {
    useSize(t, phoneSizes.first);
    final fake = FakeCommerce();
    await pumpWithFake(t, fake, const ChatThreadScreen(threadId: 1));
    await settleIo(t);
    // history visible, counter pending with Accept/Decline
    expect(find.text('Lowest I can go is 4,300.'), findsOneWidget);
    expect(k('chat.accept'), findsOneWidget);
    expect(k('chat.decline'), findsOneWidget);
    // own pending offer? buyer sends a new offer via keypad
    await t.tap(k('chat.offer'));
    await settleIo(t, 600);
    for (final d in ['4', '1', '0', '0']) {
      await t.tap(k('offer.key.$d'));
      await t.pump();
    }
    await t.tap(k('offer.submit'));
    await settleIo(t, 800);
    expect(fake.calls, contains('POST /threads/1/offer'));
    expect(find.textContaining('Waiting for a reply'), findsOneWidget);
    expect(k('chat.accept'), findsNothing); // my own offer: no accept on it
    // counter replaced -> its card says so
    expect(find.textContaining('Replaced by a newer offer'), findsWidgets);

    // text message
    await t.enterText(k('chat.input'), 'Thanks!');
    await t.tap(k('chat.send'));
    await settleIo(t, 600);
    expect(find.text('Thanks!'), findsOneWidget);

    // seller counters on the server; polling (3s) delivers it, then buyer accepts
    fake.me = kSellerId;
    fake.msgs.add({
      'id': 99,
      'thread_id': 1,
      'sender_id': kSellerId,
      'kind': 'counter',
      'body': 'Meet at 4,200?',
      'amount': 4200,
      'created_at': '2026-11-03T13:00:00.000Z',
    });
    await t.pump(const Duration(seconds: 3));
    await settleIo(t, 800);
    expect(find.text('Meet at 4,200?'), findsOneWidget);
    expect(k('chat.accept'), findsOneWidget);
    fake.me = kBuyerId;
    await t.tap(k('chat.accept'));
    await settleIo(t, 1000);
    expect(fake.orderStatus, 'accepted');
    expect(k('chat.checkout'), findsOneWidget);
    expect(k('chat.offer'), findsNothing);

    await t.tap(k('chat.checkout'));
    await settleIo(t, 1000);
    // pick QR (seller has one), type a note, confirm
    await t.tap(k('checkout.method.qr'));
    await settleIo(t, 300);
    expect(k('order.qr'), findsOneWidget);
    await t.scrollUntilVisible(k('checkout.note'), 200);
    await t.enterText(k('checkout.note'), 'Sat 3 PM, Paseo');
    await t.ensureVisible(k('checkout.confirm'));
    await t.tap(k('checkout.confirm'));
    await settleIo(t, 1000);
    expect(fake.orderStatus, 'awaiting_payment');
    expect(fake.method, 'qr');
    expect(fake.note, 'Sat 3 PM, Paseo');
    expect(find.textContaining('Keysthetic never processes money'), findsOneWidget);
    await t.ensureVisible(k('checkout.paid'));
    await t.tap(k('checkout.paid'));
    await settleIo(t, 1000);
    expect(fake.orderStatus, 'payment_sent');
    expect(k('checkout.view_order'), findsOneWidget);
    await t.ensureVisible(k('checkout.view_order'));
    await t.tap(k('checkout.view_order'));
    await settleIo(t, 1000);
    expect(find.text('Payment sent'), findsWidgets); // timeline + chip
    await settleIo(t, 4000); // drain in-flight requests before teardown
    expect(t.takeException(), isNull);
    await disposeTree(t);
  });

  testWidgets('accept 409 explains and refreshes', (t) async {
    useSize(t, phoneSizes.first);
    final fake = FakeCommerce()..failNext = 'POST /threads/1/accept';
    await pumpWithFake(t, fake, const ChatThreadScreen(threadId: 1));
    await settleIo(t);
    await t.tap(k('chat.accept'));
    await settleIo(t, 600);
    expect(find.textContaining('no longer pending'), findsOneWidget);
    await disposeTree(t);
  });

  testWidgets('QR disabled with explanation when seller has none', (t) async {
    useSize(t, phoneSizes.first);
    final fake = FakeCommerce(orderStatus: 'accepted', hasQr: false);
    await pumpWithFake(t, fake, const CheckoutScreen(orderId: 1));
    await settleIo(t);
    expect(find.textContaining('has not added a payment QR'), findsOneWidget);
    await t.tap(k('checkout.method.qr'));
    await settleIo(t, 300);
    expect(k('order.qr'), findsNothing);
    ScaffoldMessenger.of(t.element(find.byType(Scaffold).first)).hideCurrentSnackBar(); // explanatory snackbar
    await settleIo(t, 500);
    await t.ensureVisible(k('checkout.confirm'));
    await t.tap(k('checkout.confirm'));
    await settleIo(t, 800);
    expect(fake.method, 'cod');
    await disposeTree(t);
  });

  testWidgets('order detail: seller walks payment_sent -> paid -> handed over; buyer completes; cancel needs confirm', (
    t,
  ) async {
    useSize(t, phoneSizes.first);
    final fake = FakeCommerce(me: kSellerId, orderStatus: 'payment_sent', method: 'qr');
    await pumpWithFake(t, fake, const OrderDetailScreen(orderId: 1), role: 'seller');
    await settleIo(t);
    expect(k('order.confirm_payment'), findsOneWidget);
    expect(k('order.checkout'), findsNothing);
    expect(k('order.qr'), findsNothing);
    await t.tap(k('order.confirm_payment'));
    await settleIo(t, 800);
    expect(fake.orderStatus, 'paid');
    await t.tap(k('order.handover'));
    await settleIo(t, 800);
    expect(fake.orderStatus, 'handed_over');
    expect(k('order.cancel'), findsNothing); // too late to cancel
    await disposeTree(t);

    fake.me = kBuyerId;
    await pumpWithFake(t, fake, const OrderDetailScreen(orderId: 1));
    await settleIo(t);
    await t.tap(k('order.complete'));
    await settleIo(t, 800);
    expect(fake.orderStatus, 'completed');
    await disposeTree(t);

    final f2 = FakeCommerce(orderStatus: 'meetup_set', method: 'cod');
    await pumpWithFake(t, f2, const OrderDetailScreen(orderId: 1));
    await settleIo(t);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await settleIo(t, 300);
    await t.tap(k('order.cancel'));
    await settleIo(t, 500);
    await t.tap(k('order.cancel.dismiss'));
    await settleIo(t, 500);
    expect(f2.orderStatus, 'meetup_set');
    await t.tap(k('order.cancel'));
    await settleIo(t, 500);
    await t.tap(k('order.cancel.confirm'));
    await settleIo(t, 800);
    expect(f2.orderStatus, 'cancelled');
    await disposeTree(t);
  });

  testWidgets('orders: seller sees Buying/Selling; chat list shows pending + status chips', (t) async {
    useSize(t, phoneSizes.first);
    final fake = FakeCommerce(me: kSellerId, orderStatus: 'meetup_set', method: 'cod');
    await pumpWithFake(t, fake, const OrdersScreen(), role: 'seller');
    await settleIo(t);
    expect(k('orders.row.1'), findsOneWidget);
    expect(k('orders.seg.buying'), findsOneWidget);
    await disposeTree(t);

    final f2 = FakeCommerce(orderStatus: 'accepted');
    await pumpWithFake(t, f2, const ChatListScreen());
    await settleIo(t);
    expect(k('chat.row.1'), findsOneWidget);
    expect(find.text('ACCEPTED'), findsOneWidget);
    await disposeTree(t);

    final f3 = FakeCommerce();
    await pumpWithFake(t, f3, const ChatListScreen());
    await settleIo(t);
    expect(find.text('Pending offer ₱4,300'), findsOneWidget);
    await disposeTree(t);
  });
}
