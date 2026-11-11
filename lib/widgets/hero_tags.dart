import 'package:flutter/material.dart';

/// Hero tag convention: the card photo and the detail gallery's first photo
/// share `listing-photo-<id>`.
String listingPhotoTag(int listingId) => 'listing-photo-$listingId';

/// Wrap the photo on BOTH the card and the detail gallery with this.
class ListingHero extends StatelessWidget {
  const ListingHero({super.key, required this.listingId, required this.child});
  final int listingId;
  final Widget child;
  @override
  Widget build(BuildContext context) => Hero(
        tag: listingPhotoTag(listingId),
        // Keep rounded corners through the flight.
        flightShuttleBuilder: (_, anim, _, _, toCtx) => Material(type: MaterialType.transparency, child: child),
        child: child,
      );
}
