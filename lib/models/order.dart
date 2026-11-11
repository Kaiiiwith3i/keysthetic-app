import 'listing.dart';
import 'user.dart';

class OrderEvent {
  const OrderEvent(this.status, this.at);
  final String status, at;
}

class Order {
  const Order({
    required this.id,
    required this.listing,
    required this.buyer,
    required this.seller,
    required this.price,
    this.paymentMethod,
    required this.status,
    this.meetupNote,
    this.sellerQrUrl,
    this.threadId,
    this.history = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id, price;
  final ListingSummary listing;
  final UserSummary buyer, seller;
  final String? paymentMethod, meetupNote, sellerQrUrl, createdAt, updatedAt;
  final String status;
  final int? threadId;
  final List<OrderEvent> history;

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as int,
        listing: ListingSummary.fromJson(j['listing'] as Map<String, dynamic>),
        buyer: UserSummary.fromJson(j['buyer'] as Map<String, dynamic>),
        seller: UserSummary.fromJson(j['seller'] as Map<String, dynamic>),
        price: j['price'] as int,
        paymentMethod: j['payment_method'] as String?,
        status: j['status'] as String,
        meetupNote: j['meetup_note'] as String?,
        sellerQrUrl: j['seller_qr_url'] as String?,
        threadId: j['thread_id'] as int?,
        history: ((j['history'] ?? const []) as List)
            .map((e) => OrderEvent(e['status'] as String, e['at'] as String))
            .toList(),
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
      );
}
