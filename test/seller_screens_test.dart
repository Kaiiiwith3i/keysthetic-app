import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/screens/legit_check_screen.dart';
import 'package:keysthetic/screens/my_listings_screen.dart';
import 'package:keysthetic/screens/post_listing_screen.dart';
import 'package:keysthetic/models/legit.dart';
import 'package:keysthetic/services/api.dart';
import 'package:keysthetic/widgets/legit_result_view.dart';

import 'helpers.dart';
import 'seller_fixtures.dart';

Future<void> reveal(WidgetTester t, String key) =>
    t.scrollUntilVisible(find.byKey(ValueKey(key)), 250, scrollable: find.byType(Scrollable).first);

void main() {
  for (final size in phoneSizes) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final tag = '@${size.width.toInt()} x1.3 ${mode.name}';
      Future<void> scrollAll(WidgetTester t) async {
        for (var i = 0; i < 8; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -450));
          await settle(t, 200);
        }
      }

      testWidgets('post listing (new) $tag', (t) async {
        useSize(t, size, textScale: 1.3);
        await pumpWith(t, const PostListingScreen(), api: FakeApi(), mode: mode);
        await scrollAll(t);
        expect(t.takeException(), isNull);
      });
      testWidgets('post listing (edit) $tag', (t) async {
        useSize(t, size, textScale: 1.3);
        await pumpWith(t, PostListingScreen(listing: fakeListing(1)), api: FakeApi(), mode: mode);
        await scrollAll(t);
        expect(t.takeException(), isNull);
      });
      testWidgets('my listings $tag', (t) async {
        useSize(t, size, textScale: 1.3);
        await pumpWith(t, const MyListingsScreen(), api: FakeApi(items: [fakeListing(1, legit: fakeResult), fakeListing(2, status: 'reserved'), fakeListing(3, status: 'sold', category: 'cable')]), mode: mode);
        expect(find.byKey(const ValueKey('my_listings.card.1')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
      testWidgets('legit check picker + form + result $tag', (t) async {
        useSize(t, size, textScale: 1.3);
        await pumpWith(t, const LegitCheckScreen(), api: FakeApi(), mode: mode);
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const ValueKey('legit.ref.fake-q1')));
        await settle(t, 400);
        await reveal(t, 'legit.opened');
        await t.tap(find.byKey(const ValueKey('legit.opened')));
        await settle(t, 300);
        await scrollAll(t);
        expect(t.takeException(), isNull);
      });
      testWidgets('legit result view $tag', (t) async {
        useSize(t, size, textScale: 1.3);
        await pumpWith(t, const Scaffold(body: SingleChildScrollView(child: LegitResultView(result: fakeResult, reference: fakeRef))), mode: mode);
        await settle(t);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('legit result: exact wording, unknown text, source domain, disclaimer', (t) async {
    useSize(t, phoneSizes.first);
    await pumpWith(t, const Scaffold(body: SingleChildScrollView(child: LegitResultView(result: fakeResult, reference: fakeRef))));
    expect(find.text('Declared mods'), findsOneWidget);
    expect(find.text(legitDisclaimer), findsOneWidget);
    expect(find.text('Source: fakebrand.example'), findsNWidgets(2)); // layout + switch; www. stripped
    expect(find.textContaining('No published reference', findRichText: true), findsOneWidget);
    for (final v in {'match': 'Matches stock specs', 'mismatch': 'Mismatch: ask the seller'}.entries) {
      await pumpWith(t, Scaffold(body: LegitResultView(result: LegitResult(referenceId: 'x', verdict: v.key, verdictLabel: 'ignored', fields: const [], disclaimer: ''))));
      expect(find.text(v.value), findsOneWidget);
    }
  });

  testWidgets('legit form: pick model, PCB field only when opened, validation message', (t) async {
    useSize(t, phoneSizes.first);
    await pumpWith(t, const LegitCheckScreen(), api: FakeApi());
    expect(find.text('Published: Layout, Switches'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('legit.ref.fake-q1')));
    await settle(t, 400);
    await reveal(t, 'legit.photo.label');
    expect(find.byKey(const ValueKey('legit.photo.pcb')), findsNothing);
    await reveal(t, 'legit.opened');
    await t.tap(find.byKey(const ValueKey('legit.opened')));
    await settle(t, 300);
    await reveal(t, 'legit.photo.pcb');
    expect(find.byKey(const ValueKey('legit.photo.pcb')), findsOneWidget);
    await reveal(t, 'legit.submit');
    await t.tap(find.byKey(const ValueKey('legit.submit')));
    await settle(t, 300);
    expect(find.text('Choose the layout and connection.'), findsOneWidget);
  });

  testWidgets('post listing: client validation blocks submit and compatibility tags follow category', (t) async {
    useSize(t, phoneSizes.first);
    await pumpWith(t, const PostListingScreen(), api: FakeApi());
    await reveal(t, 'post.tag.layout.tkl'); // keyboard shows layout
    await reveal(t, 'post.category.cable');
    await t.tap(find.byKey(const ValueKey('post.category.cable')));
    await settle(t, 300);
    await reveal(t, 'post.tag.connector.usb_c');
    expect(find.byKey(const ValueKey('post.tag.layout.tkl')), findsNothing);
    await reveal(t, 'post.submit');
    await t.drag(find.byType(ListView).first, const Offset(0, -150));
    await settle(t, 200);
    await t.tap(find.byKey(const ValueKey('post.submit')));
    await settle(t, 300);
    expect(find.text('Add at least one photo.'), findsOneWidget);
    await settle(t, 800);
  });

  testWidgets('my listings: empty state, and 409 on remove explains cancelling the order', (t) async {
    useSize(t, phoneSizes.first);
    await pumpWith(t, const MyListingsScreen(), api: FakeApi());
    expect(find.text('Nothing for sale yet'), findsOneWidget);
    await pumpWith(t, const MyListingsScreen(), api: FakeApi(items: [fakeListing(1, status: 'reserved')], deleteError: const ApiException(409, 'x')));
    await t.tap(find.byKey(const ValueKey('my_listings.remove.1')));
    await settle(t, 400);
    await t.tap(find.byKey(const ValueKey('my_listings.remove.confirm')));
    await settle(t, 400);
    expect(find.textContaining('Cancel the order first'), findsOneWidget);
  });
}
