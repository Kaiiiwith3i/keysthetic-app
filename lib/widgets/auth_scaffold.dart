import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'keycap_card.dart';
import 'stagger.dart';

/// Wordmark: a keycap "K" and the app name.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 44,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.cs.primary,
              borderRadius: BorderRadius.circular(12),
              border: Border(bottom: BorderSide(color: Color.alphaBlend(Colors.black38, context.cs.primary), width: 4)),
            ),
            child: Center(child: Text('K', style: context.tt.titleLarge!.copyWith(color: context.cs.onPrimary, fontSize: 22))),
          ),
        ),
        const SizedBox(width: Sp.md),
        // Logo text: fixed size, not text-scaled.
        Flexible(child: Text('Keysthetic', maxLines: 1, textScaler: TextScaler.noScaling, style: context.tt.titleLarge!.copyWith(fontSize: 24))),
      ]);
}

/// Shared page for Connect / Login / Register: brand, headline, a keycap
/// card holding [children], and an optional [footer] below it.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.footer = const [], this.showBack = false});
  final String title, subtitle;
  final List<Widget> children, footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: showBack ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!showBack) const Stagger(index: 0, child: Align(alignment: Alignment.centerLeft, child: BrandMark())),
                  const SizedBox(height: Sp.xl),
                  Stagger(index: 1, child: Text(title, style: context.tt.displaySmall)),
                  const SizedBox(height: Sp.sm),
                  Stagger(index: 2, child: Text(subtitle, style: context.tt.bodyLarge!.copyWith(color: context.cs.onSurfaceVariant))),
                  const SizedBox(height: Sp.xl),
                  Stagger(index: 3, child: KeycapCard(padding: const EdgeInsets.all(Sp.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))),
                  ...footer,
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Inline status line (success / error) used under forms.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.ok, required this.text});
  final bool ok;
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = ok ? context.keys.accepted : context.cs.error;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ok ? Icons.check_circle : Icons.error_outline, size: 20, color: c),
      const SizedBox(width: Sp.sm),
      Expanded(child: Text(text, style: context.tt.bodyMedium!.copyWith(color: c))),
    ]);
  }
}
