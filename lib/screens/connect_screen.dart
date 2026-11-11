import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/keycap_card.dart';

enum _Test { idle, testing, ok, failed }

/// First launch: point the app at the server, or fall back to Demo mode.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});
  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  late final _url = TextEditingController(text: ref.read(sessionProvider).baseUrl?.replaceFirst('http://', '') ?? '');
  _Test _state = _Test.idle;
  String _error = '';

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    FocusScope.of(context).unfocus();
    final base = normalizeBaseUrl(_url.text);
    if (base.isEmpty) {
      setState(() {
        _state = _Test.failed;
        _error = 'Enter the server address first, for example 192.168.1.20:8080.';
      });
      return;
    }
    setState(() => _state = _Test.testing);
    try {
      final ok = await Api(baseUrl: base).health();
      if (!mounted) return;
      setState(() {
        _state = ok ? _Test.ok : _Test.failed;
        _error = 'That server did not answer like Keysthetic.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _Test.failed;
        _error = e.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _state = _Test.failed;
        _error = 'That address is not valid.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Connect to your server',
      subtitle: 'Enter the address shown by the Keysthetic server on your Wi-Fi network.',
      children: [
        TextField(
          key: const ValueKey('connect.url'),
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.go,
          onChanged: (_) => setState(() => _state = _Test.idle),
          onSubmitted: (_) => _test(),
          decoration: const InputDecoration(labelText: 'Server address', hintText: '192.168.x.x:8080', prefixIcon: Icon(Icons.dns_outlined)),
        ),
        const SizedBox(height: Sp.lg),
        KeyButton(
          key: const ValueKey('connect.test'),
          label: _state == _Test.testing ? 'Testing...' : 'Test connection',
          icon: Icons.wifi_tethering,
          secondary: true,
          busy: _state == _Test.testing,
          onPressed: _test,
        ),
        AnimatedSize(
          duration: context.reduceMotion ? Duration.zero : Dur.base,
          alignment: Alignment.topCenter,
          child: switch (_state) {
            _Test.ok => const Padding(padding: EdgeInsets.only(top: Sp.lg), child: StatusLine(ok: true, text: 'Connected. The server is up.')),
            _Test.failed => Padding(padding: const EdgeInsets.only(top: Sp.lg), child: StatusLine(ok: false, text: _error)),
            _ => const SizedBox(width: double.infinity),
          },
        ),
        const SizedBox(height: Sp.lg),
        KeyButton(
          key: const ValueKey('connect.continue'),
          label: 'Continue',
          icon: Icons.arrow_forward,
          onPressed: _state == _Test.ok ? () => ref.read(sessionProvider.notifier).setBaseUrl(normalizeBaseUrl(_url.text)) : null,
        ),
        if (_state == _Test.failed) ...[
          const SizedBox(height: Sp.md),
          KeyButton(
            key: const ValueKey('connect.demo'),
            label: 'Use Demo mode',
            icon: Icons.science_outlined,
            secondary: true,
            onPressed: () => ref.read(sessionProvider.notifier).enterDemo(),
          ),
          const SizedBox(height: Sp.sm),
          Text('Browse sample data offline. Nothing is saved.', textAlign: TextAlign.center, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
        ],
      ],
    );
  }
}
