import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/keycap_card.dart';
import '../widgets/pressable.dart';
import '../widgets/routes.dart';
import '../widgets/snack.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false, _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      showMessage(context, 'Enter your email and password.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(apiProvider).login(_email.text.trim(), _password.text);
      await ref.read(sessionProvider.notifier).signIn(r.token, r.user);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Welcome back',
        subtitle: 'Sign in to buy, sell and plan builds.',
        footer: [
          const SizedBox(height: Sp.lg),
          Center(
            child: Pressable(
              key: const ValueKey('auth.register'),
              onTap: () => context.push(const RegisterScreen()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                child: Text.rich(TextSpan(text: 'New here? ', style: context.tt.bodyMedium, children: [
                  TextSpan(text: 'Create an account', style: context.tt.labelLarge!.copyWith(color: context.cs.primary)),
                ])),
              ),
            ),
          ),
          Center(
            child: Pressable(
              key: const ValueKey('auth.change_server'),
              onTap: () => ref.read(sessionProvider.notifier).clearBaseUrl(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                child: Text('Change server', style: context.tt.labelLarge!.copyWith(color: context.cs.onSurfaceVariant)),
              ),
            ),
          ),
        ],
        children: [
          TextField(
            key: const ValueKey('auth.email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: Sp.md),
          TextField(
            key: const ValueKey('auth.password'),
            controller: _password,
            obscureText: _hide,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          const SizedBox(height: Sp.lg),
          KeyButton(key: const ValueKey('auth.submit'), label: 'Sign in', busy: _busy, onPressed: _submit),
        ],
      );
}
