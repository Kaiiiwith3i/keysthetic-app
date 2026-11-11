import 'listing.dart';
import 'user.dart';

class Message {
  const Message({
    required this.id,
    required this.threadId,
    this.senderId,
    required this.kind,
    this.body,
    this.amount,
    required this.createdAt,
  });

  final int id, threadId;
  final int? senderId, amount;
  final String kind; // text | offer | counter | accept | decline | system
  final String? body;
  final String createdAt;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as int,
        threadId: j['thread_id'] as int,
        senderId: j['sender_id'] as int?,
        kind: j['kind'] as String,
        body: j['body'] as String?,
        amount: j['amount'] as int?,
        createdAt: (j['created_at'] ?? '') as String,
      );
}

class Thread {
  const Thread({
    required this.id,
    required this.listing,
    required this.buyer,
    required this.seller,
    this.lastMessage,
    this.pendingOffer,
    this.orderId,
    this.updatedAt,
  });

  final int id;
  final ListingSummary listing;
  final UserSummary buyer, seller;
  final Message? lastMessage, pendingOffer;
  final int? orderId;
  final String? updatedAt;

  factory Thread.fromJson(Map<String, dynamic> j) => Thread(
        id: j['id'] as int,
        listing: ListingSummary.fromJson(j['listing'] as Map<String, dynamic>),
        buyer: UserSummary.fromJson(j['buyer'] as Map<String, dynamic>),
        seller: UserSummary.fromJson(j['seller'] as Map<String, dynamic>),
        lastMessage: j['last_message'] == null
            ? null
            : Message.fromJson(j['last_message'] as Map<String, dynamic>),
        pendingOffer: j['pending_offer'] == null
            ? null
            : Message.fromJson(j['pending_offer'] as Map<String, dynamic>),
        orderId: j['order_id'] as int?,
        updatedAt: j['updated_at'] as String?,
      );
}
