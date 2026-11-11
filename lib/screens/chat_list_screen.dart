import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thread.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/commerce_ui.dart';
import '../widgets/keycap_card.dart';
import '../widgets/price_chip.dart';
import '../widgets/routes.dart';
import '../widgets/stagger.dart';
import 'chat_thread_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(threadsProvider);
    // Order statuses for the chips; the list still renders while these load or fail.
    final statuses = {for (final o in ref.watch(ordersProvider(null)).value ?? const []) o.id: o.status};
    return Scaffold(
      appBar: Navigator.of(context).canPop() ? AppBar(title: const Text('Chats')) : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!Navigator.of(context).canPop())
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.sm),
                child: Text('Chats', style: context.tt.headlineMedium),
              ),
            Expanded(
              child: threads.when(
                skipLoadingOnReload: true,
                loading: () => const ListSkeleton(),
                error: (e, _) => MessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load chats',
                  body: errorText(e),
                  actionKey: const ValueKey('chats.retry'),
                  onAction: () => ref.invalidate(threadsProvider),
                ),
                data: (list) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ordersProvider);
                    ref.invalidate(threadsProvider);
                    await ref.read(threadsProvider.future);
                  },
                  child: list.isEmpty
                      ? const MessageState(
                          icon: Icons.forum_outlined,
                          title: 'No conversations yet',
                          body: 'Open a listing and tap Chat to ask a question or make an offer.',
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xl),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: Sp.md),
                          itemBuilder: (_, i) =>
                              Stagger(index: i, child: _ThreadRow(list[i], statuses[list[i].orderId])),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _preview(Message m) => switch (m.kind) {
  'offer' => 'Offer ${formatPeso(m.amount ?? 0)}',
  'counter' => 'Counter ${formatPeso(m.amount ?? 0)}',
  'accept' => 'Offer accepted',
  'decline' => 'Offer declined',
  _ => m.body ?? '',
};

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow(this.t, this.orderStatus);
  final Thread t;
  final String? orderStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final buying = isBuyerSide(ref, t.buyer.id, t.seller.id);
    final other = buying ? t.seller : t.buyer;
    final last = t.lastMessage;
    final pending = t.pendingOffer;
    final muted = context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant);
    return KeycapCard(
      key: ValueKey('chat.row.${t.id}'),
      padding: const EdgeInsets.all(Sp.md),
      semanticLabel: 'Chat with ${other.name} about ${t.listing.title}',
      onTap: () async {
        await context.push(ChatThreadScreen(threadId: t.id));
        if (context.mounted) ref.invalidate(threadsProvider);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingThumb(t.listing.photo, size: 56),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        other.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleSmall,
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    Text(whenShort(last?.createdAt ?? t.updatedAt), style: muted),
                  ],
                ),
                Text(t.listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                if (last != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${last.senderId != null && last.senderId == s.user?.id ? 'You: ' : ''}${_preview(last)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodyMedium,
                  ),
                ],
                if (pending != null || orderStatus != null) ...[
                  const SizedBox(height: Sp.sm),
                  Wrap(
                    spacing: Sp.sm,
                    runSpacing: Sp.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (pending != null) _PendingChip(pending),
                      if (orderStatus != null) StatusChip(orderStatus!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip(this.m);
  final Message m;
  @override
  Widget build(BuildContext context) {
    final c = m.kind == 'counter' ? context.keys.counter : context.keys.offer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: c.withValues(alpha: .55)),
      ),
      child: Text('Pending offer ${formatPeso(m.amount ?? 0)}', style: context.tt.labelSmall!.copyWith(color: c)),
    );
  }
}
