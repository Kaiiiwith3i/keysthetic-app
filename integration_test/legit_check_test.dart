// Flow 8: seller runs Legit Check on a seeded model (reference picked by search,
// fields filled, label photo attached). The verdict banner is one of the exact
// labels, per-field rows and the disclaimer show, and it matches the server's own verdict.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

const _labels = ['Matches stock specs', 'Declared mods', 'Mismatch: ask the seller'];
const _disclaimer = "This compares the seller's answers to published stock specs. It is not proof of authenticity.";
const _refId = 'corsair-k70-pro-tkl'; // seeded: TKL, wired, switches ["CORSAIR MGX V2"]

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('legit check verdict, fields and disclaimer', (t) async {
    final picker = await FakeImagePicker.install();
    final seller = await Srv.register('seller');
    final listing = await Srv.listing(seller,
        title: 'E2E Legit ${uniq('lg')} K70', price: 6000, tags: {'kind': 'mechanical', 'layout': 'tkl', 'connection': 'wired'});
    final lid = listing['id'];

    // The server's own verdict for an input, used as the oracle (no listing_id, so nothing is saved).
    Future<Map<String, dynamic>> oracle(String layout) async {
      final label = await Srv.upload(seller, kind: 'legit');
      return await Srv.call('POST', '/legit/check', token: seller.token, body: {
        'reference_id': _refId,
        'serial': 'E2E-SN-0001',
        'layout': layout,
        'switch': 'CORSAIR MGX V2',
        'connection': 'wired',
        'opened': false,
        'mods': '',
        'label_photo_url': label,
      }) as Map<String, dynamic>;
    }

    Future<void> expectResult(Map<String, dynamic> expected) async {
      await pumpUntilFound(t, k('legit.result'));
      final label = expected['verdict_label'] as String;
      expect(_labels, contains(label));
      expect(find.descendant(of: k('legit.result'), matching: find.text(label)), findsOneWidget, reason: 'verdict banner text');
      expect(find.text(_disclaimer), findsWidgets);
      expect(k('legit.disclaimer'), findsOneWidget);
      for (final f in (expected['fields'] as List).cast<Map<String, dynamic>>()) {
        final row = k('legit.result.${f['field']}');
        await reveal(t, row);
        expect(row, findsOneWidget, reason: 'row for ${f['field']}');
        final word = {'match': 'MATCH', 'mod': 'DECLARED MOD', 'mismatch': 'MISMATCH', 'unknown': 'UNKNOWN'}[f['result']]!;
        expect(find.descendant(of: row, matching: find.text(word)), findsOneWidget, reason: '${f['field']} should read $word');
      }
    }

    Future<void> attachLabelPhoto() async {
      await pickFromGallery(t, find.descendant(of: k('legit.photo.label'), matching: find.text('Add photo')));
    }

    await startAs(t, seller.email, seller.password);
    await tapKey(t, 'nav.my_listings');
    await tapKey(t, 'my_listings.legit_check.$lid');

    // Run 1: everything matches the published stock specs.
    await typeIn(t, 'legit.search', 'K70 PRO TKL');
    // The search debounces, then narrows the 8 default tiles to exactly the matching model.
    await pumpUntil(t, () => keyed('legit.ref.').evaluate().length == 1, what: 'the search to narrow to one model');
    await tapKey(t, 'legit.ref.$_refId');
    await pumpUntilFound(t, k('legit.selected'));
    await typeIn(t, 'legit.serial', 'E2E-SN-0001');
    await tapKey(t, 'legit.layout.tkl');
    await tapKey(t, 'legit.connection.wired');
    await tapKey(t, 'legit.switch.$_refId');
    await tap(t, find.text('CORSAIR MGX V2').last);
    await attachLabelPhoto();
    expect(picker.picks, 1);
    await tapKey(t, 'legit.submit');
    final match = await oracle('tkl');
    expect(match['verdict_label'], 'Matches stock specs');
    await expectResult(match);

    // Saved on the listing by the server, and shown as a badge on My listings.
    final saved = await Srv.call('GET', '/listings/$lid') as Map<String, dynamic>;
    expect(saved['legit']['verdict_label'], 'Matches stock specs');

    // Run 2: wrong layout, no declared mods -> mismatch.
    await tapKey(t, 'legit.again');
    await tapKey(t, 'legit.layout.60');
    await attachLabelPhoto();
    await tapKey(t, 'legit.submit');
    final mismatch = await oracle('60');
    expect(mismatch['verdict_label'], 'Mismatch: ask the seller');
    await expectResult(mismatch);
    expect(find.descendant(of: k('legit.result.layout'), matching: find.text('MISMATCH')), findsOneWidget);

    await backToShell(t);
    await pumpUntilFound(t, k('my_listings.legit.$lid'));
  });
}
