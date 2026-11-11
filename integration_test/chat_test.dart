// Flow 5: buyer sends a message; the seller receives it (seller session in the UI);
// and the 3 s poll delivers a seller reply to the buyer's already-open thread.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat: send, receive, live poll', (t) async {
    final seller = await Srv.register('seller');
    final buyer = await Srv.register('buyer');
    final title = 'E2E Chat ${uniq('ch')} board';
    final listing = await Srv.listing(seller, title: title);
    final hello = 'Hello from the buyer ${uniq('m')}';
    final live = 'Live reply ${uniq('r')}';
    final uiReply = 'Reply typed by the seller ${uniq('u')}';

    // Buyer: open the listing, tap Message, send a text.
    await startAs(t, buyer.email, buyer.password);
    await searchFor(t, title);
    await tapKey(t, 'feed.card.${listing['id']}');
    await tapKey(t, 'detail.message');
    await pumpUntilFound(t, k('chat.input'));
    await t.enterText(k('chat.input'), hello);
    await tapKey(t, 'chat.send');
    await pumpUntilFound(t, find.text(hello));
    final thread = ((await Srv.call('GET', '/threads', token: seller.token)) as List).single as Map<String, dynamic>;
    final msgs = await Srv.call('GET', '/threads/${thread['id']}/messages', token: seller.token) as List;
    expect(msgs.map((m) => m['body']), contains(hello), reason: 'server delivered it to the seller');

    // Poll proof: with the buyer's thread still open, the seller replies over HTTP;
    // the open screen must show it within the 3 s poll (plus a margin).
    await Srv.call('POST', '/threads/${thread['id']}/messages', token: seller.token, expect: 201, body: {'body': live});
    final sw = Stopwatch()..start();
    await pumpUntilFound(t, find.text(live), timeout: const Duration(seconds: 8));
    // ignore: avoid_print
    print('poll latency: reply appeared ${sw.elapsedMilliseconds} ms after it was sent');
    expect(sw.elapsed, lessThan(const Duration(seconds: 7)));

    // Seller session in the UI: the chat row previews the buyer's message; the thread shows both.
    await switchTo(t, seller.email, seller.password);
    await tapKey(t, 'nav.chats');
    await pumpUntilFound(t, k('chat.row.${thread['id']}'));
    await tapKey(t, 'chat.row.${thread['id']}');
    await pumpUntilFound(t, find.text(hello));
    await t.enterText(k('chat.input'), uiReply);
    await tapKey(t, 'chat.send');
    await pumpUntilFound(t, find.text(uiReply));

    // Buyer signs back in and finds the seller's UI reply in the thread.
    await switchTo(t, buyer.email, buyer.password);
    await tapKey(t, 'nav.chats');
    await tapKey(t, 'chat.row.${thread['id']}');
    await pumpUntilFound(t, find.text(uiReply));
    expect(find.text(live), findsOneWidget);
  });
}
