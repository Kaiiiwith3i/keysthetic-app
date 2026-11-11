// Flow 7: seller marks handed over -> buyer confirms received -> completed;
// the order is in BOTH the buyer's and the seller's order history (UI).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('handover then confirm received completes the order', (t) async {
    final seller = await Srv.register('seller');
    final buyer = await Srv.register('buyer');
    final listing = await Srv.listing(seller, title: 'E2E Complete ${uniq('oc')} board', price: 2800);
    // Precondition over HTTP: an order already at "meetup set" (checkout is flow 6's job).
    final created = await Srv.call('POST', '/orders', token: buyer.token, expect: 201, body: {'listing_id': listing['id']}) as Map<String, dynamic>;
    final oid = created['id'];
    await Srv.call('POST', '/orders/$oid/checkout', token: buyer.token, body: {'payment_method': 'cod', 'meetup_note': 'E2E meetup'});
    final row = k('orders.row.$oid');

    // Seller marks it handed over.
    await startAs(t, seller.email, seller.password);
    await tapKey(t, 'nav.orders');
    await tapKey(t, 'orders.row.$oid');
    await pumpUntilFound(t, k('order.handover'));
    await tapKey(t, 'order.handover');
    await pumpUntilFound(t, find.text('Waiting for the buyer to confirm receipt.'));
    expect((await Srv.order('$oid', seller))['status'], 'handed_over');

    // Buyer confirms received.
    await switchTo(t, buyer.email, buyer.password);
    await tapKey(t, 'nav.profile');
    await tapKey(t, 'profile.orders');
    await tapKey(t, 'orders.row.$oid');
    await pumpUntilFound(t, find.text('Got the item? Confirm to complete the order.'));
    await tapKey(t, 'order.complete');
    await pumpUntilFound(t, find.text('This order is complete.'));

    // Buyer's history shows it completed.
    await t.pageBack();
    await pumpUntilFound(t, row);
    await pumpUntil(t, () => find.descendant(of: row, matching: find.text('COMPLETED')).evaluate().isNotEmpty, what: 'COMPLETED in the buyer history');

    // Seller's history shows it completed too.
    await switchTo(t, seller.email, seller.password);
    await tapKey(t, 'nav.orders');
    await pumpUntilFound(t, row);
    await pumpUntil(t, () => find.descendant(of: row, matching: find.text('COMPLETED')).evaluate().isNotEmpty, what: 'COMPLETED in the seller history');

    final o = await Srv.order('$oid', buyer);
    expect(o['status'], 'completed');
    expect((o['history'] as List).map((h) => h['status']), ['accepted', 'meetup_set', 'handed_over', 'completed']);
    expect((await Srv.call('GET', '/listings/${listing['id']}') as Map)['status'], 'sold');
  });
}
