// Dev tool: SCREENSHOTS=1 flutter test test/tool/commerce_screenshots_test.dart -> .dev-screens/c_*.png (fake data).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keysthetic/screens/chat_list_screen.dart';
import 'package:keysthetic/screens/chat_thread_screen.dart';
import 'package:keysthetic/screens/checkout_screen.dart';
import 'package:keysthetic/screens/order_detail_screen.dart';
import 'package:keysthetic/screens/orders_screen.dart';

import '../fake_commerce.dart';
import '../helpers.dart';

void main() {
  final on = Platform.environment['SCREENSHOTS'] == '1';
  final shot = GlobalKey();

  Future<void> loadFonts() async {
    for (final f in {'Bricolage': 'BricolageGrotesque', 'InstrumentSans': 'InstrumentSans', 'JetBrainsMono': 'JetBrainsMono'}.entries) {
      final l = FontLoader(f.key)..addFont(rootBundle.load('assets/fonts/${f.value}.ttf'));
      await l.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();
  }

  Future<void> snap(WidgetTester t, String name) async {
    await t.runAsync(() async {
      final b = shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      Directory('.dev-screens').createSync();
      File('.dev-screens/c_$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
    });
  }

  final scenes = <String, (FakeCommerce Function(), Widget, String)>{
    'chat_list': (() => FakeCommerce(), const ChatListScreen(), 'buyer'),
    'thread_counter': (() => FakeCommerce(), const ChatThreadScreen(threadId: 1), 'buyer'),
    'thread_order': (() => FakeCommerce(orderStatus: 'accepted'), const ChatThreadScreen(threadId: 1), 'buyer'),
    'checkout_form': (() => FakeCommerce(orderStatus: 'accepted'), const CheckoutScreen(orderId: 1), 'buyer'),
    'checkout_noqr': (() => FakeCommerce(orderStatus: 'accepted', hasQr: false), const CheckoutScreen(orderId: 1), 'buyer'),
    'checkout_pay': (() => FakeCommerce(orderStatus: 'awaiting_payment', method: 'qr'), const CheckoutScreen(orderId: 1), 'buyer'),
    'orders_seller': (() => FakeCommerce(me: kSellerId, orderStatus: 'payment_sent', method: 'qr'), const OrdersScreen(), 'seller'),
    'order_buyer_qr': (() => FakeCommerce(orderStatus: 'awaiting_payment', method: 'qr'), const OrderDetailScreen(orderId: 1), 'buyer'),
    'order_seller_confirm': (() => FakeCommerce(me: kSellerId, orderStatus: 'payment_sent', method: 'qr'), const OrderDetailScreen(orderId: 1), 'seller'),
    'order_cancelled': (() => FakeCommerce(orderStatus: 'cancelled'), const OrderDetailScreen(orderId: 1), 'buyer'),
  };
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final e in scenes.entries) {
      testWidgets('${e.key} ${mode.name}', (t) async {
        await t.runAsync(loadFonts);
        useSize(t, const Size(412, 915));
        await t.pumpWidget(RepaintBoundary(key: shot, child: const SizedBox()));
        await pumpWithFake(t, e.value.$1(), RepaintBoundary(key: shot, child: e.value.$2), mode: mode, role: e.value.$3);
        await settleIo(t, 2200);
        await snap(t, '${e.key}_${mode.name}');
        await disposeTree(t);
      }, skip: !on);
    }
  }
}
