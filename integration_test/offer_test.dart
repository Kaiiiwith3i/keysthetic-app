// Flow 4: buyer offers -> seller counters -> buyer accepts; an order is created
// (checked in the UI and over the API).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Taps the peso keypad digit by digit, then the submit button.
Future<void> keypad(WidgetTester t, String amount) async {
  for (final d in amount.split('')) {
    await tapKey(t, 'offer.key.$d');
  }
  await tapKey(t, 'offer.submit');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offer, counter, accept creates an order', (t) async {
    final seller = await Srv.register('seller');
    final buyer = await Srv.register('buyer');
    final title = 'E2E Offer ${uniq('of')} board';
    final listing = await Srv.listing(seller, title: title, price: 5000);
    final lid = listing['id'];

    // Buyer: open the listing from search and make an offer of 3,000.
    await startAs(t, buyer.email, buyer.password);
    await searchFor(t, title);
    await tapKey(t, 'feed.card.$lid');
    await tapKey(t, 'detail.offer');
    await typeIn(t, 'detail.offer.amount', '3000');
    await tapKey(t, 'detail.offer.send');
    await pumpUntilFound(t, k('chat.input')); // landed in the chat
    await pumpUntilFound(t, find.textContaining('3,000'));
    final thread = ((await Srv.call('GET', '/threads', token: buyer.token)) as List).single as Map<String, dynamic>;
    expect(thread['pending_offer']['kind'], 'offer');
    expect(thread['pending_offer']['amount'], 3000);

    // Seller: sees the offer in Chats and counters 4,000 through the keypad.
    await switchTo(t, seller.email, seller.password);
    await tapKey(t, 'nav.chats');
    await tapKey(t, 'chat.row.${thread['id']}');
    await pumpUntilFound(t, find.textContaining('3,000'));
    await tapKey(t, 'chat.offer'); // "Counter" for the seller
    await keypad(t, '4000');
    await pumpUntilFound(t, find.textContaining('4,000'));
    final afterCounter = await Srv.call('GET', '/threads/${thread['id']}', token: seller.token) as Map<String, dynamic>;
    expect(afterCounter['pending_offer']['kind'], 'counter');
    expect(afterCounter['pending_offer']['amount'], 4000);

    // Buyer: accepts the counter in the thread.
    await switchTo(t, buyer.email, buyer.password);
    await tapKey(t, 'nav.chats');
    await tapKey(t, 'chat.row.${thread['id']}');
    await pumpUntilFound(t, k('chat.accept'));
    await tapKey(t, 'chat.accept');
    await pumpUntilFound(t, k('chat.checkout')); // order banner: "Go to checkout"
    expect(k('chat.accept'), findsNothing, reason: 'the offer is settled');
    expect(find.textContaining('Accepted'), findsWidgets);
    expect(find.textContaining('Order #'), findsOneWidget);
    expect(find.textContaining('4,000'), findsWidgets);
    expect(find.text('ACCEPTED'), findsWidgets); // offer bubble and the order banner

    // API: exactly one order at 4,000, accepted, listing reserved.
    final orders = (await Srv.call('GET', '/orders', token: buyer.token)) as List;
    expect(orders, hasLength(1));
    final o = orders.single as Map<String, dynamic>;
    expect(o['price'], 4000);
    expect(o['status'], 'accepted');
    expect(o['listing']['id'], lid);
    expect(o['thread_id'], thread['id']);
    expect(o['seller']['id'], seller.id);
    final l = await Srv.call('GET', '/listings/$lid') as Map<String, dynamic>;
    expect(l['status'], 'reserved');
  });
}
