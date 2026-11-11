import 'package:flutter/material.dart';

import '../widgets/stub_screen.dart';

// TODO(feature agent): build the Checkout screen.
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.orderId});
  final int orderId;

  @override
  Widget build(BuildContext context) => StubScreen('Checkout', detail: 'orderId: $orderId');
}
