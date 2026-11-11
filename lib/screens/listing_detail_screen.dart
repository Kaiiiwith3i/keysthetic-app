import 'package:flutter/material.dart';

import '../widgets/stub_screen.dart';

// TODO(feature agent): build the Listing detail screen.
class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.listingId});
  final int listingId;

  @override
  Widget build(BuildContext context) => StubScreen('Listing detail', detail: 'listingId: $listingId');
}
