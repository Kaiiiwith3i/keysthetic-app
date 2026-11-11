import 'legit.dart';
import 'user.dart';

class Listing {
  const Listing({
    required this.id,
    required this.seller,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.condition,
    this.kind,
    this.connection,
    this.layout,
    this.switchType,
    this.stem,
    this.connector,
    this.meetupArea,
    this.photos = const [],
    this.soundUrl,
    required this.status,
    this.legit,
    this.createdAt,
  });

  final int id;
  final UserSummary seller;
  final String title, description, category, condition, status;
  final int price;
  final String? kind, connection, layout, switchType, stem, connector;
  final String? meetupArea, soundUrl, createdAt;
  final List<String> photos;
  final LegitResult? legit;

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as int,
        seller: UserSummary.fromJson(j['seller'] as Map<String, dynamic>),
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        category: j['category'] as String,
        price: j['price'] as int,
        condition: j['condition'] as String,
        kind: j['kind'] as String?,
        connection: j['connection'] as String?,
        layout: j['layout'] as String?,
        switchType: j['switch_type'] as String?,
        stem: j['stem'] as String?,
        connector: j['connector'] as String?,
        meetupArea: j['meetup_area'] as String?,
        photos: ((j['photos'] ?? const []) as List).cast<String>(),
        soundUrl: j['sound_url'] as String?,
        status: j['status'] as String,
        legit: j['legit'] == null
            ? null
            : LegitResult.fromJson(j['legit'] as Map<String, dynamic>),
        createdAt: j['created_at'] as String?,
      );
}

/// Compact listing used inside threads, orders and builds.
class ListingSummary {
  const ListingSummary({
    required this.id,
    required this.title,
    required this.price,
    this.photo,
    required this.status,
    required this.category,
  });

  final int id, price;
  final String title, status, category;
  final String? photo;

  factory ListingSummary.fromJson(Map<String, dynamic> j) => ListingSummary(
        id: j['id'] as int,
        title: j['title'] as String,
        price: j['price'] as int,
        photo: j['photo'] as String?,
        status: j['status'] as String,
        category: j['category'] as String,
      );
}
