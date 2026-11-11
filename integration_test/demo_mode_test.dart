// Flow 10: WITH THE SERVER STOPPED. Connect -> Test connection fails -> Use Demo mode ->
// bundled listings and the "Demo data" banner; a listing opens; a write says "Connect to a server".
// run_all.sh stops the server before this file. If it is up, the test fails loudly.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo mode with the server down', (t) async {
    expect(await serverIsUp(), isFalse, reason: 'this flow needs the server STOPPED (run_all.sh stops it first)');

    await launchApp(t);
    await pumpUntilFound(t, k('connect.url'));
    expect(k('connect.demo'), findsNothing, reason: 'the demo button only shows after a failed test');
    await t.enterText(k('connect.url'), serverAddress);
    await tapKey(t, 'connect.test');
    await pumpUntilFound(t, k('connect.demo'));
    expect(find.text('Connected. The server is up.'), findsNothing);
    expect(find.textContaining('Cannot reach the server'), findsOneWidget);
    await tapKey(t, 'connect.demo');

    // Shell with the banner and bundled listings.
    await pumpUntilFound(t, k('demo.banner'));
    expect(find.text('Demo data'), findsOneWidget);
    await pumpUntilFound(t, keyed('feed.card.'));
    final cards = keyed('feed.card.').evaluate().length;
    expect(cards, greaterThan(3), reason: 'bundled demo listings are shown');

    // Open one: the detail page renders from the bundle, banner still pinned.
    await t.tap(keyed('feed.card.').first);
    await pumpUntilFound(t, find.text('Specs'));
    expect(k('demo.banner'), findsOneWidget);
    await reveal(t, find.text('Seller')); // further down the page
    expect(find.text('Seller'), findsOneWidget);

    // A write action is refused with the standard message.
    await tapKey(t, 'detail.buy');
    await pumpUntilFound(t, find.text('Connect to a server to do this'));
    await tapKey(t, 'detail.message');
    await pumpUntilFound(t, find.text('Connect to a server to do this'));
    expect(k('checkout.confirm'), findsNothing, reason: 'no order was created');
  });
}
