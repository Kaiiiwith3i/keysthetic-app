import 'package:flutter/material.dart';

import '../widgets/stub_screen.dart';

// TODO(feature agent): build the Order detail screen.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final int orderId;

  @override
  Widget build(BuildContext context) => StubScreen('Order detail', detail: 'orderId: $orderId');
}
