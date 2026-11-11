import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/admin_bits.dart';
import '../widgets/keycap_card.dart';
import '../widgets/routes.dart';
import '../widgets/snack.dart';
import '../widgets/theme_toggle.dart';
import 'checkout_screen.dart';
import 'build_planner_screen.dart';
import 'chat_thread_screen.dart';
import 'legit_check_screen.dart';
import 'listing_detail_screen.dart';
import 'motion_lab_screen.dart';
import 'order_detail_screen.dart';
import 'orders_screen.dart';
import 'post_listing_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _endSession(BuildContext context, WidgetRef ref, {bool forgetServer = false}) async {
    final s = ref.read(sessionProvider);
    final n = ref.read(sessionProvider.notifier);
    final api = ref.read(apiProvider);
    context.popToRoot();
    if (s.demo) {
      await n.exitDemo();
    } else {
      try {
        await api.logout();
      } catch (_) {} // token may already be invalid; sign out locally regardless
      await n.signOut();
    }
    if (forgetServer) await n.clearBaseUrl();
  }

  Future<void> _changeServer(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(context,
        title: 'Change server?', body: 'You will be signed out and asked for a new server address.', confirmLabel: 'Change', keyPrefix: 'profile.change_server_confirm');
    if (ok && context.mounted) await _endSession(context, ref, forgetServer: true);
  }

  Future<void> _edit(BuildContext context, User user) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _EditSheet(user: user),
      );

  Widget _heading(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(top: Sp.xl, bottom: Sp.md),
        child: Text(t, style: context.tt.titleMedium),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final user = s.user;
    final small = context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sp.lg),
          children: [
            Text('Profile', style: context.tt.headlineMedium),
            const SizedBox(height: Sp.lg),
            KeycapCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  CircleAvatar(radius: 26, backgroundColor: context.cs.primary, child: Text((user?.name ?? '?').characters.first.toUpperCase(), style: context.tt.titleLarge!.copyWith(color: context.cs.onPrimary))),
                  const SizedBox(width: Sp.lg),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user?.name ?? 'Guest', key: const ValueKey('profile.name'), style: context.tt.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: Sp.xs),
                      StatusPill(key: const ValueKey('profile.role'), label: s.role, color: s.role == 'admin' ? context.cs.primary : s.role == 'seller' ? context.keys.counter : context.cs.onSurfaceVariant),
                    ]),
                  ),
                ]),
                const SizedBox(height: Sp.md),
                if (user?.area != null) Text(user!.area!, key: const ValueKey('profile.area'), style: context.tt.bodyMedium),
                if (user != null && user.email.isNotEmpty) Text(user.email, key: const ValueKey('profile.email'), style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
                if (user != null) ...[
                  const SizedBox(height: Sp.md),
                  KeyButton(key: const ValueKey('profile.edit'), label: 'Edit name and area', icon: Icons.edit_outlined, secondary: true, onPressed: () => _edit(context, user)),
                ],
              ]),
            ),
            if (s.role == 'buyer') ...[
              _heading(context, 'Shopping'),
              _Row(label: 'My orders', icon: Icons.receipt_long_outlined, k: 'profile.orders', onTap: () => context.push(const OrdersScreen())),
              _Row(label: 'My builds', icon: Icons.keyboard_outlined, k: 'profile.builds', onTap: () => context.push(const BuildPlannerScreen())),
            ],
            if (s.role == 'seller') ...[
              _heading(context, 'Selling'),
              _Row(
                label: 'Payment QR',
                subtitle: user?.paymentQrUrl == null ? 'Not set. Add one when you post a listing.' : 'Set. Buyers see it at checkout.',
                icon: Icons.qr_code_2,
                k: 'profile.payment_qr',
                onTap: () => context.push(const PostListingScreen()),
              ),
            ],
            _heading(context, 'Server'),
            KeycapCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(s.demo ? 'Demo mode (offline)' : (s.baseUrl ?? 'Not connected'), key: const ValueKey('profile.server'), style: context.tt.titleSmall),
                const SizedBox(height: Sp.md),
                KeyButton(key: const ValueKey('profile.change_server'), label: 'Change server', icon: Icons.dns_outlined, secondary: true, onPressed: () => _changeServer(context, ref)),
              ]),
            ),
            _heading(context, 'Appearance'),
            const ThemeToggle(),
            _heading(context, 'About & demo data'),
            KeycapCard(
              key: const ValueKey('profile.about'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Everything you see in Keysthetic is demo data.', style: context.tt.titleSmall),
                const SizedBox(height: Sp.sm),
                Text('Users, listings, chats, orders and Legit DB entries are fake seed content made for a class project. Photos, sounds and payment QR codes are generated renders, not real products or accounts.', style: small),
                const SizedBox(height: Sp.sm),
                Text('Reference data compares listings to published stock specs. It does not prove authenticity.', style: small),
              ]),
            ),
            _heading(context, 'Developer'),
            _Row(label: 'Motion lab', icon: Icons.animation, k: 'profile.motion_lab', onTap: () => context.push(const MotionLabScreen())),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('profile.dev_shortcuts'),
                tilePadding: EdgeInsets.zero,
                title: Text('Screen shortcuts', style: context.tt.titleSmall),
                children: [
                  _Row(label: 'Listing detail', icon: Icons.article_outlined, k: 'profile.stub.listing_detail', onTap: () => context.push(const ListingDetailScreen(listingId: 1))),
                  _Row(label: 'Post listing', icon: Icons.add_box_outlined, k: 'profile.stub.post_listing', onTap: () => context.push(const PostListingScreen())),
                  _Row(label: 'Chat thread', icon: Icons.forum_outlined, k: 'profile.stub.chat_thread', onTap: () => context.push(const ChatThreadScreen(threadId: 1))),
                  _Row(label: 'Checkout', icon: Icons.payments_outlined, k: 'profile.stub.checkout', onTap: () => context.push(const CheckoutScreen(orderId: 1))),
                  _Row(label: 'Order detail', icon: Icons.receipt_outlined, k: 'profile.stub.order_detail', onTap: () => context.push(const OrderDetailScreen(orderId: 1))),
                  _Row(label: 'Legit check', icon: Icons.verified_outlined, k: 'profile.stub.legit_check', onTap: () => context.push(const LegitCheckScreen())),
                ],
              ),
            ),
            const SizedBox(height: Sp.xl),
            KeyButton(
              key: const ValueKey('profile.signout'),
              label: s.demo ? 'Exit demo mode' : 'Sign out',
              icon: Icons.logout,
              secondary: true,
              onPressed: () => _endSession(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.user});
  final User user;
  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _area = TextEditingController(text: widget.user.area ?? '');
  bool _busy = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    setState(() => _busy = true);
    try {
      final u = await ref.read(apiProvider).updateMe(name: _name.text.trim(), area: _area.text.trim());
      final s = ref.read(sessionProvider);
      if (s.token != null) await ref.read(sessionProvider.notifier).signIn(s.token!, u);
      if (!mounted) return;
      showMessage(context, 'Profile updated.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showApiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Edit profile', style: context.tt.titleLarge),
            const SizedBox(height: Sp.lg),
            TextField(key: const ValueKey('profile.edit.name'), controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Name', errorText: _nameError)),
            const SizedBox(height: Sp.md),
            TextField(key: const ValueKey('profile.edit.area'), controller: _area, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Area (for meetups)')),
            const SizedBox(height: Sp.lg),
            KeyButton(key: const ValueKey('profile.edit.save'), label: 'Save', icon: Icons.check, busy: _busy, onPressed: _save),
          ]),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.icon, required this.k, required this.onTap, this.subtitle});
  final String label, k;
  final String? subtitle;
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
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: context.tt.titleSmall),
                if (subtitle != null) Text(subtitle!, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
              ]),
            ),
            Icon(Icons.chevron_right, color: context.cs.onSurfaceVariant),
          ]),
        ),
      );
}
