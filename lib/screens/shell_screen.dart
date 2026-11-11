import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../widgets/app_nav_bar.dart';
import 'admin_legit_screen.dart';
import 'admin_listings_screen.dart';
import 'admin_users_screen.dart';
import 'build_planner_screen.dart';
import 'chat_list_screen.dart';
import 'feed_screen.dart';
import 'my_listings_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'search_filter_screen.dart';

typedef _Tab = (NavItem, Widget);

List<_Tab> _tabsFor(String role) {
  const profile = (NavItem('profile', 'Profile', Icons.person_outline, Icons.person), ProfileScreen());
  switch (role) {
    case 'seller':
      return const [
        (NavItem('home', 'Home', Icons.home_outlined, Icons.home), FeedScreen()),
        (NavItem('my_listings', 'My Listings', Icons.sell_outlined, Icons.sell), MyListingsScreen()),
        (NavItem('chats', 'Chats', Icons.chat_bubble_outline, Icons.chat_bubble), ChatListScreen()),
        (NavItem('orders', 'Orders', Icons.receipt_long_outlined, Icons.receipt_long), OrdersScreen()),
        profile,
      ];
    case 'admin':
      return const [
        (NavItem('listings', 'Listings', Icons.view_list_outlined, Icons.view_list), AdminListingsScreen()),
        (NavItem('users', 'Users', Icons.group_outlined, Icons.group), AdminUsersScreen()),
        (NavItem('legit', 'Legit DB', Icons.verified_outlined, Icons.verified), AdminLegitScreen()),
        profile,
      ];
    default:
      return const [
        (NavItem('home', 'Home', Icons.home_outlined, Icons.home), FeedScreen()),
        (NavItem('search', 'Search', Icons.search, Icons.search), SearchFilterScreen()),
        (NavItem('build', 'Build', Icons.keyboard_outlined, Icons.keyboard), BuildPlannerScreen()),
        (NavItem('chats', 'Chats', Icons.chat_bubble_outline, Icons.chat_bubble), ChatListScreen()),
        profile,
      ];
  }
}

/// Role-based tab shell with the custom animated nav bar.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});
  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;
  String? _role;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionProvider.select((s) => s.role));
    if (_role != role) {
      _role = role;
      _index = 0;
    }
    final tabs = _tabsFor(role);
    return Scaffold(
      // IndexedStack only hides tabs; without TickerMode their tickers (shimmer, stagger) keep running and
      // ListingCard's "one Hero per tag" check (heroOn = TickerMode enabled) sees Home and Search at once.
      body: IndexedStack(index: _index, children: [for (final (i, t) in tabs.indexed) TickerMode(enabled: i == _index, child: t.$2)]),
      bottomNavigationBar: AppNavBar(items: [for (final t in tabs) t.$1], index: _index, onSelect: (i) => setState(() => _index = i)),
    );
  }
}
