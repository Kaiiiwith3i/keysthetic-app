import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/keycap_card.dart';
import '../widgets/routes.dart';
import '../widgets/theme_toggle.dart';
import 'checkout_screen.dart';
import 'chat_thread_screen.dart';
import 'legit_check_screen.dart';
import 'listing_detail_screen.dart';
import 'motion_lab_screen.dart';
import 'order_detail_screen.dart';
import 'post_listing_screen.dart';

// TODO(feature agent): flesh out profile (edit name/area, seller payment QR). Theme, Motion lab and sign-out are done.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final user = s.user;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sp.lg),
          children: [
            Text('Profile', style: context.tt.headlineMedium),
            const SizedBox(height: Sp.lg),
            KeycapCard(
              child: Row(children: [
                CircleAvatar(radius: 26, backgroundColor: context.cs.primary, child: Text((user?.name ?? '?').characters.first.toUpperCase(), style: context.tt.titleLarge!.copyWith(color: context.cs.onPrimary))),
                const SizedBox(width: Sp.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.name ?? 'Guest', style: context.tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${s.role}${user?.area == null ? '' : ' - ${user!.area}'}', style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
                    Text(s.demo ? 'Demo mode (offline)' : (s.baseUrl ?? ''), style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: Sp.xl),
            Text('Appearance', style: context.tt.titleMedium),
            const SizedBox(height: Sp.md),
            const ThemeToggle(),
            const SizedBox(height: Sp.xl),
            Text('Developer', style: context.tt.titleMedium),
            const SizedBox(height: Sp.md),
            _Row(label: 'Motion lab', icon: Icons.animation, k: 'profile.motion_lab', onTap: () => context.push(const MotionLabScreen())),
            _Row(label: 'Listing detail (stub)', icon: Icons.article_outlined, k: 'profile.stub.listing_detail', onTap: () => context.push(const ListingDetailScreen(listingId: 1))),
            _Row(label: 'Post listing (stub)', icon: Icons.add_box_outlined, k: 'profile.stub.post_listing', onTap: () => context.push(const PostListingScreen())),
            _Row(label: 'Chat thread (stub)', icon: Icons.forum_outlined, k: 'profile.stub.chat_thread', onTap: () => context.push(const ChatThreadScreen(threadId: 1))),
            _Row(label: 'Checkout (stub)', icon: Icons.payments_outlined, k: 'profile.stub.checkout', onTap: () => context.push(const CheckoutScreen(orderId: 1))),
            _Row(label: 'Order detail (stub)', icon: Icons.receipt_outlined, k: 'profile.stub.order_detail', onTap: () => context.push(const OrderDetailScreen(orderId: 1))),
            _Row(label: 'Legit check (stub)', icon: Icons.verified_outlined, k: 'profile.stub.legit_check', onTap: () => context.push(const LegitCheckScreen())),
            const SizedBox(height: Sp.xl),
            KeyButton(
              key: const ValueKey('profile.signout'),
              label: s.demo ? 'Exit demo mode' : 'Sign out',
              icon: Icons.logout,
              secondary: true,
              onPressed: () async {
                final n = ref.read(sessionProvider.notifier);
                context.popToRoot();
                if (s.demo) {
                  await n.exitDemo();
                } else {
                  try {
                    await ref.read(apiProvider).logout();
                  } catch (_) {} // token may already be invalid; sign out locally regardless
                  await n.signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.icon, required this.k, required this.onTap});
  final String label, k;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.md),
        child: KeycapCard(
          key: ValueKey(k),
          onTap: onTap,
          semanticLabel: label,
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
          child: Row(children: [
            Icon(icon, color: context.cs.primary),
            const SizedBox(width: Sp.md),
            Expanded(child: Text(label, style: context.tt.titleSmall)),
            Icon(Icons.chevron_right, color: context.cs.onSurfaceVariant),
          ]),
        ),
      );
}
