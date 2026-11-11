import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/connect_screen.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'services/providers.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/demo_banner.dart';

class KeystheticApp extends ConsumerWidget {
  const KeystheticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'Keysthetic',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        builder: (context, child) => DemoBanner(child: child!),
        home: const RootGate(),
      );
}

/// First launch -> Connect; connected but signed out -> Login; else the shell.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final (key, page) = s.signedIn
        ? ('shell', const ShellScreen())
        : (s.baseUrl == null || s.baseUrl!.isEmpty)
            ? ('connect', const ConnectScreen())
            : ('login', const LoginScreen());
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : Dur.slow,
      child: KeyedSubtree(key: ValueKey(key), child: page),
    );
  }
}
