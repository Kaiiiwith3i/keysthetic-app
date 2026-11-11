import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/widgets/keyboard_layers.dart';

import 'helpers.dart';

void main() {
  testWidgets('first launch: failed test connection offers Demo mode, which opens the shell with banner', (t) async {
    useSize(t, phoneSizes.first);
    await pumpFullApp(t);
    expect(find.byKey(const ValueKey('connect.url')), findsOneWidget);
    expect(find.byKey(const ValueKey('connect.demo')), findsNothing);

    await t.enterText(find.byKey(const ValueKey('connect.url')), '127.0.0.1:9'); // nothing listens here
    await t.tap(find.byKey(const ValueKey('connect.test')));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
    await settle(t, 500);
    expect(find.byKey(const ValueKey('connect.demo')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('connect.demo')));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect(find.byKey(const ValueKey('demo.banner')), findsOneWidget);
    for (final k in ['home', 'search', 'build', 'chats', 'profile']) {
      expect(find.byKey(ValueKey('nav.$k')), findsOneWidget, reason: k);
    }
    await t.tap(find.byKey(const ValueKey('nav.build')));
    await settle(t);
    expect(find.text('Build planner'), findsOneWidget);
  });

  testWidgets('connected but signed out shows login; register screen reachable', (t) async {
    useSize(t, phoneSizes.first);
    await pumpFullApp(t, prefs: {'session.base_url': 'http://127.0.0.1:9'});
    expect(find.byKey(const ValueKey('auth.email')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('auth.register')));
    await settle(t);
    expect(find.byKey(const ValueKey('auth.role.seller')), findsOneWidget);
  });

  testWidgets('tap targets in nav are >= 48dp', (t) async {
    useSize(t, phoneSizes.first);
    await pumpFullApp(t, prefs: {'session.demo': true});
    for (final k in ['home', 'search', 'build', 'chats', 'profile']) {
      final s = t.getSize(find.byKey(ValueKey('nav.$k')));
      expect(s.width >= 48 && s.height >= 48, isTrue, reason: '$k is $s');
    }
  });

  testWidgets('KeyboardLayers fills, clears, changes layout and reduces motion without errors', (t) async {
    useSize(t, phoneSizes.first);
    final filled = ValueNotifier<Set<BuildSlot>>({});
    final layout = ValueNotifier(KbLayout.k65);
    final reduce = ValueNotifier(false);
    await pumpScreen(
      t,
      ListenableBuilder(
        listenable: Listenable.merge([filled, layout, reduce]),
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce.value),
          child: Scaffold(body: Center(child: KeyboardLayers(filled: filled.value, layout: layout.value))),
        ),
      ),
    );
    for (final l in KbLayout.values) {
      layout.value = l;
      filled.value = {...BuildSlot.values};
      await settle(t, 1200);
      filled.value = {};
      await settle(t, 1200);
    }
    reduce.value = true;
    filled.value = {BuildSlot.board, BuildSlot.keycaps};
    await settle(t);
    await t.drag(find.byType(KeyboardLayers), const Offset(60, 20));
    await settle(t);
    expect(t.takeException(), isNull);
  });
}
