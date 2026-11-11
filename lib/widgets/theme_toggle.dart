import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// System / Light / Dark switch; persisted through [themeModeProvider].
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    const opts = [(ThemeMode.system, 'System', Icons.brightness_auto), (ThemeMode.light, 'Light', Icons.light_mode_outlined), (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined)];
    return Row(children: [
      for (final (m, label, icon) in opts)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Pressable(
              key: ValueKey('theme.${m.name}'),
              semanticLabel: '$label theme',
              onTap: () => ref.read(themeModeProvider.notifier).set(m),
              child: AnimatedContainer(
                duration: context.reduceMotion ? Duration.zero : Dur.base,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mode == m ? context.cs.primary : context.keys.capTop,
                  borderRadius: BorderRadius.circular(Rad.md),
                  border: Border(bottom: BorderSide(color: mode == m ? Color.alphaBlend(Colors.black26, context.cs.primary) : context.keys.capLip, width: 3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: mode == m ? context.cs.onPrimary : context.cs.onSurface),
                  const SizedBox(width: 6),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.labelMedium!.copyWith(color: mode == m ? context.cs.onPrimary : context.cs.onSurface))),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}
