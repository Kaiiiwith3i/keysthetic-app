// Flow 3: a buyer finds listings by text search, then narrows with Fits-My-Build
// (search filter and the feed chip) using a saved build. A compatible listing
// shows; an incompatible one does not.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search by text, then Fits my build', (t) async {
    final seller = await Srv.register('seller');
    final buyer = await Srv.register('buyer');
    final token = uniq('zx'); // shared by both titles, so text search finds both
    final fit = await Srv.listing(seller,
        title: 'E2E $token 65% hot-swap board', tags: {'kind': 'mechanical', 'layout': '65', 'stem': 'mx', 'connector': 'usb_c'});
    final nofit = await Srv.listing(seller,
        title: 'E2E $token TKL board', tags: {'kind': 'mechanical', 'layout': 'tkl', 'stem': 'mx', 'connector': 'usb_c'});
    // Precondition: the buyer has a saved 65% / MX / USB-C build.
    final build = await Srv.call('POST', '/builds',
        token: buyer.token, expect: 201, body: {'name': 'E2E 65 build', 'layout': '65', 'stem': 'mx', 'connector': 'usb_c'});
    final fitCard = k('feed.card.${fit['id']}'), nofitCard = k('feed.card.${nofit['id']}');

    await startAs(t, buyer.email, buyer.password);

    // 1) Text search: both match the shared token.
    await searchFor(t, token);
    await pumpUntilFound(t, fitCard);
    await pumpUntilFound(t, nofitCard);
    // ...and a nonsense query finds neither (the search is real, not a static list).
    await t.enterText(k('search.field'), 'zzz-no-such-listing-${uniq()}');
    await pumpUntilGone(t, fitCard);
    expect(nofitCard, findsNothing);
    await pumpUntilFound(t, find.text('No matches'));
    await t.enterText(k('search.field'), token);
    await pumpUntilFound(t, fitCard);
    await pumpUntilFound(t, nofitCard);

    // 2) Search filter "Fits my build": only the compatible board stays.
    await tapKey(t, 'search.filter');
    await tapKey(t, 'filter.build.${build['id']}');
    await tapKey(t, 'filter.apply');
    await pumpUntilGone(t, nofitCard);
    await pumpUntilFound(t, fitCard);
    expect(k('search.chip.build'), findsOneWidget);
    expect(find.text('Fits E2E 65 build'), findsOneWidget);

    // Server oracle: the same rule gives the same answer.
    final ids = ((await Srv.call('GET', '/listings', token: buyer.token, query: {'q': token, 'build_id': '${build['id']}'})) as List)
        .map((l) => l['id'])
        .toList();
    expect(ids, [fit['id']]);

    // 3) Feed chip "Fits my build": the compatible listing is there, the TKL one is not.
    await tapKey(t, 'nav.home');
    await tapKey(t, 'feed.fits');
    await pumpUntilFound(t, find.text('Fits E2E 65 build'));
    await pumpUntilFound(t, fitCard);
    expect(nofitCard, findsNothing);
    await tapKey(t, 'feed.fits'); // off again: the unfiltered feed has no chip filter
    await pumpUntilFound(t, find.text('Fits my build'));
  });
}
