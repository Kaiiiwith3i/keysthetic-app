// Flow 9: admin hides a listing -> it disappears from the buyer's search and feed;
// unhide brings it back. The listing is left active (clean).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('admin hides and unhides a listing', (t) async {
    final seller = await Srv.register('seller');
    final buyer = await Srv.register('buyer');
    final tag = uniq('ah');
    final listing = await Srv.listing(seller, title: 'E2E AdminHide $tag board');
    final lid = listing['id'];
    final card = k('feed.card.$lid');
    final admin = await Srv.loginAs(adminEmail, demoPassword);

    Future<void> buyerSees(bool visible) async {
      // Feed (newest first) ...
      await tapKey(t, 'nav.home');
      if (visible) {
        await pumpUntilFound(t, card);
      } else {
        await settle(t, 1500); // let the feed load, then it must still be absent
        expect(card, findsNothing, reason: 'hidden listing in the feed');
      }
      // ... and search.
      await searchFor(t, tag);
      if (visible) {
        await pumpUntilFound(t, card);
      } else {
        await pumpUntilFound(t, find.text('No matches'));
        expect(card, findsNothing, reason: 'hidden listing in search');
      }
    }

    Future<void> adminToggle(String label, String done) async {
      await tapKey(t, 'nav.listings');
      await typeIn(t, 'admin_listings.search', tag);
      await pumpUntilFound(t, k('admin_listings.row.$lid'));
      expect(find.descendant(of: k('admin_listings.hide.$lid'), matching: find.text(label)), findsOneWidget);
      await tapKey(t, 'admin_listings.hide.$lid');
      await tapKey(t, 'admin_listings.confirm.confirm');
      await pumpUntilFound(t, find.text(done));
    }

    try {
      await startAs(t, buyer.email, buyer.password);
      await buyerSees(true);

      await switchTo(t, adminEmail, demoPassword);
      await adminToggle('Hide', 'Listing hidden.');
      expect(await Srv.listingsMatching(tag), isEmpty, reason: 'GET /listings no longer returns it');
      expect(((await Srv.call('GET', '/admin/listings', token: admin.token)) as List).any((l) => l['id'] == lid && l['status'] == 'hidden'), isTrue);

      await switchTo(t, buyer.email, buyer.password);
      await buyerSees(false);

      await switchTo(t, adminEmail, demoPassword);
      await adminToggle('Unhide', 'Listing is active again.');
      expect(await Srv.listingsMatching(tag), hasLength(1));

      await switchTo(t, buyer.email, buyer.password);
      await buyerSees(true);
    } finally {
      // Leave data clean even if an assertion failed halfway.
      await Srv.call('POST', '/admin/listings/$lid/hide', token: admin.token, body: {'hidden': false});
    }
    expect((await Srv.call('GET', '/listings/$lid') as Map)['status'], 'active');
  });
}
