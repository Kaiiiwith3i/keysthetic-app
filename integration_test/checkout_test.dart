// Flow 6: two orders. Cash on meetup (checkout -> meetup_set) and QR
// (checkout QR -> "I've paid" -> seller "Confirm payment" -> paid).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cash on meetup and QR checkout', (t) async {
    final seller = await Srv.register('seller');
    await Srv.setQr(seller); // QR checkout needs the seller's payment QR
    final buyer = await Srv.register('buyer');
    final tag = uniq('co');
    final cash = await Srv.listing(seller, title: 'E2E Checkout $tag cash board', price: 2500);
    final qr = await Srv.listing(seller, title: 'E2E Checkout $tag qr board', price: 3100);
    const note = 'Sat 3 PM, SM Calamba food court';

    await startAs(t, buyer.email, buyer.password);

    // ---- Order 1: cash on meetup.
    await searchFor(t, '$tag cash');
    await tapKey(t, 'feed.card.${cash['id']}');
    await tapKey(t, 'detail.buy'); // Buy now -> order accepted -> checkout
    await pumpUntilFound(t, k('checkout.confirm'));
    expect(find.text('Confirm cash on meetup'), findsOneWidget);
    await typeIn(t, 'checkout.note', note);
    await tapKey(t, 'checkout.confirm');
    await pumpUntilFound(t, find.text("You're all set"));
    expect(find.text('MEETUP SET'), findsWidgets);
    var cashOrder = await orderForListing(buyer, cash['id']);
    expect(cashOrder['status'], 'meetup_set');
    expect(cashOrder['payment_method'], 'cod');
    expect(cashOrder['meetup_note'], note);
    expect(cashOrder['price'], 2500);

    // ---- Order 2: QR.
    await backToShell(t);
    await searchFor(t, '$tag qr');
    await tapKey(t, 'feed.card.${qr['id']}');
    await tapKey(t, 'detail.buy');
    await pumpUntilFound(t, k('checkout.method.qr'));
    await tapKey(t, 'checkout.method.qr');
    await reveal(t, find.text('Confirm and pay via QR'));
    await tapKey(t, 'checkout.confirm');
    await pumpUntilFound(t, k('checkout.paid')); // "Pay the seller" step with the QR
    expect(find.text('Pay the seller'), findsOneWidget);
    var qrOrder = await orderForListing(buyer, qr['id']);
    expect(qrOrder['status'], 'awaiting_payment');
    expect(qrOrder['payment_method'], 'qr');
    await tapKey(t, 'checkout.paid');
    await pumpUntilFound(t, find.text('Payment marked as sent'));
    qrOrder = await orderForListing(buyer, qr['id']);
    expect(qrOrder['status'], 'payment_sent');

    // ---- Seller confirms the QR payment in the UI.
    await switchTo(t, seller.email, seller.password);
    await tapKey(t, 'nav.orders');
    await pumpUntilFound(t, k('orders.row.${cashOrder['id']}'));
    expect(find.descendant(of: k('orders.row.${cashOrder['id']}'), matching: find.text('MEETUP SET')), findsOneWidget);
    await tapKey(t, 'orders.row.${qrOrder['id']}');
    await pumpUntilFound(t, find.text('The buyer says they paid. Check your account, then confirm.'));
    await tapKey(t, 'order.confirm_payment');
    await pumpUntilFound(t, find.text('Payment confirmed. Hand over the item at the meetup.'));
    expect(find.text('PAID'), findsWidgets);
    qrOrder = await orderForListing(seller, qr['id']);
    expect(qrOrder['status'], 'paid');
    cashOrder = await orderForListing(seller, cash['id']);
    expect(cashOrder['status'], 'meetup_set', reason: 'the cash order is untouched');
    expect((qrOrder['history'] as List).map((h) => h['status']), ['accepted', 'awaiting_payment', 'payment_sent', 'paid']);
  });
}
