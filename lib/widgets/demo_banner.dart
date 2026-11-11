import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// Wraps every route (via MaterialApp.builder): in Demo mode a slim banner is
/// pinned above the content. Also lets reviewers view the demo as another role.
class DemoBanner extends ConsumerWidget {
  const DemoBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    if (!s.demo) return child;
    final mq = MediaQuery.of(context);
    return Column(children: [
      Material(
        color: context.cs.secondary,
        child: Padding(
          padding: EdgeInsets.only(top: mq.padding.top),
          child: Row(children: [
            const SizedBox(width: Sp.lg),
            Icon(Icons.science_outlined, size: 16, color: context.cs.onSecondary),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text('Demo data', key: const ValueKey('demo.banner'),
                  style: context.tt.labelMedium!.copyWith(color: context.cs.onSecondary)),
            ),
            // Tap to cycle buyer -> seller -> admin so reviewers can see every shell.
            Pressable(
              key: const ValueKey('demo.role'),
              semanticLabel: 'View demo as another role',
              onTap: () {
                const roles = ['buyer', 'seller', 'admin'];
                ref.read(sessionProvider.notifier).demoRole(roles[(roles.indexOf(s.role) + 1) % roles.length]);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                child: Text('View as ${s.role}', style: context.tt.labelMedium!.copyWith(color: context.cs.onSecondary)),
              ),
            ),
          ]),
        ),
      ),
      Expanded(
        child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
      ),
    ]);
  }
}
