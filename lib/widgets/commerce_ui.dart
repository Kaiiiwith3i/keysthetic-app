import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import '../models/thread.dart';
import '../services/api.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import 'shimmer.dart';

// ---- shared data (chat, checkout, orders all read these) ----

final ordersProvider = FutureProvider.autoDispose.family<List<Order>, String?>(
  (ref, role) => ref.watch(apiProvider).orders(role: role),
);
final orderProvider = FutureProvider.autoDispose.family<Order, int>((ref, id) => ref.watch(apiProvider).order(id));
final threadsProvider = FutureProvider.autoDispose<List<Thread>>((ref) => ref.watch(apiProvider).threads());

/// Drops every cached order/thread read so lists and details refetch.
void refreshCommerce(WidgetRef ref, [int? orderId]) {
  ref.invalidate(ordersProvider);
  ref.invalidate(threadsProvider);
  if (orderId != null) ref.invalidate(orderProvider(orderId));
}

/// Which side the signed-in user is on. Demo mode can switch role while keeping
/// the buyer's id, so the session role breaks the tie.
bool isBuyerSide(WidgetRef ref, int buyerId, int sellerId) {
  final s = ref.watch(sessionProvider);
  final uid = s.user?.id;
  if (uid == buyerId) return s.role != 'seller' || uid != sellerId;
  if (uid == sellerId) return false;
  return s.role != 'seller';
}

/// Human text for an error shown inside a screen body.
String errorText(Object e) => switch (e) {
  ApiException(:final message) => message,
  _ => 'Something went wrong. Please try again.',
};

// ---- status ----

const _labels = {
  'accepted': 'Accepted',
  'meetup_set': 'Meetup set',
  'awaiting_payment': 'Awaiting payment',
  'payment_sent': 'Payment sent',
  'paid': 'Paid',
  'handed_over': 'Handed over',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
};

String statusLabel(String s) => _labels[s] ?? s;

Color statusColor(KeysColors k, String s) => switch (s) {
  'completed' => k.accepted,
  'cancelled' => k.declined,
  'paid' || 'handed_over' => k.counter,
  _ => k.offer,
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(context.keys, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: c.withValues(alpha: .55)),
      ),
      child: Text(
        statusLabel(status).toUpperCase(),
        style: context.tt.labelSmall!.copyWith(color: c, letterSpacing: .8),
      ),
    );
  }
}

// ---- time ----

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "3:40 PM" today, "Nov 3" otherwise. Empty when unparseable.
String whenShort(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day ? _clock(d) : '${_months[d.month - 1]} ${d.day}';
}

/// "Nov 3, 3:40 PM".
String whenLong(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  return d == null ? '' : '${_months[d.month - 1]} ${d.day}, ${_clock(d)}';
}

// ---- thumbnail ----

class ListingThumb extends ConsumerWidget {
  const ListingThumb(this.url, {super.key, this.size = 56});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ph = Container(
      width: size,
      height: size,
      color: context.keys.skeleton,
      child: Icon(Icons.keyboard_outlined, size: size * .45, color: context.cs.onSurfaceVariant),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rad.sm),
      child: url == null
          ? ph
          : Image(
              image: mediaImage(ref, url!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ph,
            ),
    );
  }
}

// ---- states ----

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(Sp.lg),
    children: [for (var i = 0; i < 5; i++) const ListRowSkeleton()],
  );
}

/// Centred message with an optional action. Scrollable so pull-to-refresh works on it.
class MessageState extends StatelessWidget {
  const MessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionKey,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title, body;
  final Key? actionKey;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Sp.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: context.cs.primary),
                const SizedBox(height: Sp.md),
                Text(title, textAlign: TextAlign.center, style: context.tt.titleLarge),
                const SizedBox(height: Sp.sm),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: Sp.lg),
                  OutlinedButton(
                    key: actionKey,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: onAction,
                    child: Text(actionLabel ?? 'Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
