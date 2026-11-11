import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Placeholder body for screens a feature agent will build.
class StubScreen extends StatelessWidget {
  const StubScreen(this.title, {super.key, this.detail});
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: Navigator.of(context).canPop() ? AppBar(title: Text(title)) : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Sp.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, textAlign: TextAlign.center, style: context.tt.headlineMedium),
              const SizedBox(height: Sp.sm),
              Text(detail ?? 'Coming soon', textAlign: TextAlign.center, style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
            ]),
          ),
        ),
      );
}
