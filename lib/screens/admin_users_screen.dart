import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/admin_bits.dart';
import '../widgets/keycap_card.dart';
import '../widgets/snack.dart';
import '../widgets/stagger.dart';

const _roles = ['all', 'buyer', 'seller', 'admin'];

/// Admin tab: all users, filter by role (with counts), ban / unban.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<User>? _items;
  String? _error;
  String _role = 'all', _q = '';
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).adminUsers();
      if (mounted) setState(() { _items = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not load users.');
    }
  }

  Future<void> _toggleBan(User u) async {
    final ban = !u.banned;
    final ok = await confirmAction(context,
        title: ban ? 'Ban ${u.name}?' : 'Unban ${u.name}?',
        body: ban ? 'They are signed out right away and cannot log in until unbanned.' : 'They can log in and use Keysthetic again.',
        confirmLabel: ban ? 'Ban' : 'Unban',
        keyPrefix: 'admin_users.confirm',
        destructive: ban);
    if (!ok || !mounted) return;
    setState(() => _busy.add(u.id));
    try {
      final r = await ref.read(apiProvider).banUser(u.id, ban);
      if (!mounted) return;
      setState(() => _items = [for (final x in _items!) x.id == u.id ? r : x]);
      showMessage(context, ban ? '${u.name} is banned.' : '${u.name} is unbanned.');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _items ?? const <User>[];
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final u in all)
        if ((_role == 'all' || u.role == _role) && (q.isEmpty || '${u.name} ${u.email}'.toLowerCase().contains(q))) u
    ];
    int count(String r) => r == 'all' ? all.length : all.where((u) => u.role == r).length;
    return Scaffold(
      body: SafeArea(
        child: AdminListBody(
          keyPrefix: 'admin_users',
          loading: _items == null && _error == null,
          error: _items == null ? _error : null,
          onRefresh: _load,
          emptyIcon: Icons.group_off_outlined,
          emptyText: 'No users match.',
          header: AdminHeader(
            title: 'Users',
            searchKey: const ValueKey('admin_users.search'),
            hint: 'Search name or email',
            onChanged: (v) => setState(() => _q = v),
            below: [
              ChipFilterRow(
                keyPrefix: 'admin_users.filter',
                selected: _role,
                onSelected: (v) => setState(() => _role = v),
                options: [for (final r in _roles) (r, r[0].toUpperCase() + r.substring(1), count(r))],
              ),
            ],
          ),
          children: [
            for (var i = 0; i < shown.length; i++)
              Padding(
                key: ValueKey('admin_users.row.${shown[i].id}'),
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: Stagger(index: i, child: _Row(user: shown[i], busy: _busy.contains(shown[i].id), onToggle: () => _toggleBan(shown[i]))),
              ),
          ],
        ),
      ),
    );
  }
}

Color roleColor(BuildContext context, String role) =>
    switch (role) { 'admin' => context.cs.primary, 'seller' => context.keys.counter, _ => context.cs.onSurfaceVariant };

class _Row extends StatelessWidget {
  const _Row({required this.user, required this.busy, required this.onToggle});
  final User user;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return KeycapCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(radius: 22, backgroundColor: context.cs.primary.withValues(alpha: .16), child: Text(u.name.characters.first.toUpperCase(), style: context.tt.titleMedium)),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
              Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
              if (u.area != null) Text(u.area!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: Sp.sm),
        Row(children: [
          Flexible(child: Wrap(spacing: Sp.sm, runSpacing: Sp.xs, children: [
            StatusPill(label: u.role, color: roleColor(context, u.role)),
            if (u.banned) StatusPill(label: 'banned', color: context.keys.declined),
          ])),
          const SizedBox(width: Sp.sm),
          if (u.role != 'admin')
            KeyButton(
              key: ValueKey('admin_users.ban.${u.id}'),
              label: u.banned ? 'Unban' : 'Ban',
              icon: u.banned ? Icons.lock_open : Icons.block,
              secondary: true,
              busy: busy,
              onPressed: onToggle,
            ),
        ]),
      ]),
    );
  }
}
