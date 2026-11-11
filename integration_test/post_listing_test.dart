// Flow 2: a seller posts a listing WITH a photo (fake picker), sees it in My listings,
// and the server serves it from GET /listings with a photo URL that returns 200.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seller posts a listing with a photo', (t) async {
    final picker = await FakeImagePicker.install();
    final seller = await Srv.register('seller');
    final title = 'E2E Post ${uniq('post')} 65% board';

    await startAs(t, seller.email, seller.password);
    await tapKey(t, 'nav.my_listings');
    await tapKey(t, 'my_listings.post');

    // Photo through the (fake) gallery.
    await pickFromGallery(t, k('post.photo.add'));
    expect(picker.picks, 1);
    await pumpUntilFound(t, k('post.photo.0'));

    await typeIn(t, 'post.title', title);
    await typeIn(t, 'post.price', '3200');
    await tapKey(t, 'post.condition.like_new');
    await tapKey(t, 'post.tag.layout.65');
    await tapKey(t, 'post.tag.stem.mx');
    await tapKey(t, 'post.tag.connector.usb_c');
    await typeIn(t, 'post.description', 'Fake E2E listing: hot-swap 65% board, tested.');
    await tapKey(t, 'post.submit');
    await pumpUntilFound(t, k('post.success'));

    // Back on My listings, the new card shows.
    await pumpUntilGone(t, k('post.success'));
    await pumpUntilFound(t, find.text(title));
    expect(find.text('₱3,200'), findsWidgets);

    // Server: listed, owned by this seller, photo present and served as an image.
    final found = await Srv.listingsMatching(title);
    expect(found, hasLength(1), reason: 'GET /listings?q=<title>');
    final l = found.single as Map<String, dynamic>;
    expect(l['seller']['id'], seller.id);
    expect(l['price'], 3200);
    expect(l['condition'], 'like_new');
    expect([l['layout'], l['stem'], l['connector']], ['65', 'mx', 'usb_c']);
    final photos = (l['photos'] as List).cast<String>();
    expect(photos, hasLength(1));
    final img = await http.get(Uri.parse('$serverBase${photos.single}'));
    expect(img.statusCode, 200);
    expect(img.headers['content-type'], contains('image/png'));
    expect(img.bodyBytes, makePng(), reason: 'the served photo is the uploaded one');
  });
}
