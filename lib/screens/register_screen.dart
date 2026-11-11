import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/keycap_card.dart';
import '../widgets/pressable.dart';
import '../widgets/routes.dart';
import '../widgets/snack.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _password = TextEditingController(), _area = TextEditingController();
  String _role = 'buyer';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _area.text.trim().isEmpty) {
      showMessage(context, 'Fill in your name, email and area.');
      return;
    }
    if (_password.text.length < 8) {
      showMessage(context, 'Password must be at least 8 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).register(
          email: _email.text.trim(), password: _password.text, name: _name.text.trim(), role: _role, area: _area.text.trim());
      await ref.read(sessionProvider.notifier).signIn(r.token, r.user);
      if (mounted) context.popToRoot();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showBack: true,
        title: 'Create account',
        subtitle: 'Pick how you will use Keysthetic. You can only have one role.',
        children: [
          Row(children: [
            Expanded(child: _RoleKey(id: 'buyer', label: 'Buyer', icon: Icons.shopping_bag_outlined, selected: _role == 'buyer', onTap: () => setState(() => _role = 'buyer'))),
            const SizedBox(width: Sp.md),
            Expanded(child: _RoleKey(id: 'seller', label: 'Seller', icon: Icons.storefront_outlined, selected: _role == 'seller', onTap: () => setState(() => _role = 'seller'))),
          ]),
          const SizedBox(height: Sp.lg),
          TextField(key: const ValueKey('auth.name'), controller: _name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: Sp.md),
          TextField(key: const ValueKey('auth.email'), controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline))),
          const SizedBox(height: Sp.md),
          TextField(key: const ValueKey('auth.password'), controller: _password, obscureText: true, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Password (8+ characters)', prefixIcon: Icon(Icons.lock_outline))),
          const SizedBox(height: Sp.md),
          TextField(key: const ValueKey('auth.area'), controller: _area, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Your area (for meetups)', prefixIcon: Icon(Icons.place_outlined))),
          const SizedBox(height: Sp.lg),
          KeyButton(key: const ValueKey('auth.submit'), label: 'Create account', busy: _busy, onPressed: _submit),
        ],
      );
}

class _RoleKey extends StatelessWidget {
  const _RoleKey({required this.id, required this.label, required this.icon, required this.selected, required this.onTap});
  final String id, label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.cs.onPrimary : context.cs.onSurface;
    return Pressable(
      key: ValueKey('auth.role.$id'),
      semanticLabel: '$label role',
      onTap: onTap,
      minSize: 56,
      child: AnimatedContainer(
        duration: context.reduceMotion ? Duration.zero : Dur.base,
        height: 56,
        decoration: BoxDecoration(
          color: selected ? context.cs.primary : context.keys.capTop,
          borderRadius: BorderRadius.circular(Rad.md),
          border: Border(bottom: BorderSide(color: selected ? Color.alphaBlend(Colors.black26, context.cs.primary) : context.keys.capLip, width: 4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: Sp.sm),
          Text(label, style: context.tt.labelLarge!.copyWith(color: fg)),
        ]),
      ),
    );
  }
}
