// Flow 1: Connect screen -> register a buyer and a seller; each lands in its role's shell.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register a buyer and a seller through the UI', (t) async {
    final buyerEmail = '${uniq('buyer')}@e2e.test';
    final sellerEmail = '${uniq('seller')}@e2e.test';

    await launchApp(t);
    await connect(t);

    Future<void> register({required String role, required String name, required String email}) async {
      await tapKey(t, 'auth.register');
      await tapKey(t, 'auth.role.$role');
      await t.enterText(k('auth.name'), name);
      await t.enterText(k('auth.email'), email);
      await t.enterText(k('auth.password'), testPassword);
      await t.enterText(k('auth.area'), 'Calamba Crossing');
      await tapKey(t, 'auth.submit');
      await pumpUntilFound(t, k('nav.profile'));
      await settle(t);
    }

    // Buyer shell: Home, Search, Build, Chats, Profile (no seller tabs).
    await register(role: 'buyer', name: 'E2E Buyer Reg', email: buyerEmail);
    for (final n in ['home', 'search', 'build', 'chats', 'profile']) {
      expect(k('nav.$n'), findsOneWidget, reason: 'buyer tab $n');
    }
    expect(k('nav.my_listings'), findsNothing);
    expect(k('nav.orders'), findsNothing);
    await tapKey(t, 'nav.profile');
    expect(find.text(buyerEmail), findsOneWidget);
    expect(find.text('E2E Buyer Reg'), findsOneWidget);

    // Seller shell: Home, My Listings, Chats, Orders, Profile.
    await logout(t);
    await register(role: 'seller', name: 'E2E Seller Reg', email: sellerEmail);
    for (final n in ['home', 'my_listings', 'chats', 'orders', 'profile']) {
      expect(k('nav.$n'), findsOneWidget, reason: 'seller tab $n');
    }
    expect(k('nav.build'), findsNothing);
    await tapKey(t, 'nav.profile');
    expect(find.text(sellerEmail), findsOneWidget);

    // The server agrees: both accounts exist with the right role.
    final buyer = await Srv.loginAs(buyerEmail, testPassword);
    final seller = await Srv.loginAs(sellerEmail, testPassword);
    expect(buyer.user['role'], 'buyer');
    expect(seller.user['role'], 'seller');
    expect(buyer.user['name'], 'E2E Buyer Reg');
  });
}
