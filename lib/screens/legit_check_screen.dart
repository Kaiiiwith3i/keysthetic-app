import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/legit.dart';
import '../models/listing.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/choice_row.dart';
import '../widgets/keycap_card.dart';
import '../widgets/legit_result_view.dart';
import '../widgets/photo_picker_grid.dart';
import '../widgets/shimmer.dart';
import '../widgets/snack.dart';
import '../widgets/stagger.dart';

final legitRefsProvider = FutureProvider.autoDispose.family<List<LegitReference>, String>((ref, q) => ref.watch(apiProvider).legitReferences(q: q));

const _layouts = {'full': 'Full', 'tkl': 'TKL', '75': '75%', '65': '65%', '60': '60%', '40': '40%'};
const _published = {'layout': 'Layout', 'switches': 'Switches', 'connection': 'Connection', 'weight_g': 'Weight', 'serial_format': 'Serial'};
const _other = '__other__';

/// Seller tool: compare a unit's details with published stock specs.
/// Launched from a listing (`listing`) the result is saved on it.
class LegitCheckScreen extends ConsumerStatefulWidget {
  const LegitCheckScreen({super.key, this.listing});
  final Listing? listing;
  @override
  ConsumerState<LegitCheckScreen> createState() => _LegitCheckScreenState();
}

class _LegitCheckScreenState extends ConsumerState<LegitCheckScreen> {
  final _search = TextEditingController(), _serial = TextEditingController(), _weight = TextEditingController(), _mods = TextEditingController(), _otherSwitch = TextEditingController();
  Timer? _debounce;
  String _q = '';
  LegitReference? _ref;
  String? _layout, _switch, _connection;
  bool _opened = false, _busy = false, _submitted = false;
  PhotoItem? _label, _pcb;
  LegitResult? _result;

  @override
  void initState() {
    super.initState();
    _layout = widget.listing?.layout;
    _connection = widget.listing?.connection;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_search, _serial, _weight, _mods, _otherSwitch]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _switches => [for (final s in (_ref?.fields['switches']?.value as List?) ?? const []) '$s'];

  void _choose(LegitReference r) => setState(() {
        _ref = r;
        _switch = null;
        _submitted = false;
      });

  String? get _switchValue => _switch == _other ? _otherSwitch.text.trim() : _switch;

  String? _problem() {
    if (_ref == null) return 'Pick the keyboard model first.';
    if (_layout == null || _connection == null) return 'Choose the layout and connection.';
    if ((_switchValue ?? '').isEmpty) return 'Choose or type the switches.';
    if (_label == null) return 'Add a photo of the underside label.';
    if (_opened && _pcb == null) return 'Add a photo of the PCB, since the board has been opened.';
    final w = _weight.text.trim();
    if (w.isNotEmpty && (int.tryParse(w) ?? 0) <= 0) return 'Weight must be a whole number of grams.';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final p = _problem();
    if (p != null) return showMessage(context, p);
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final label = await _label!.upload(api, 'legit');
      final pcb = _opened ? await _pcb!.upload(api, 'legit') : null;
      final r = await api.legitCheck({
        'reference_id': _ref!.id,
        'listing_id': ?widget.listing?.id,
        'serial': _serial.text.trim(),
        if (_weight.text.trim().isNotEmpty) 'weight_g': int.parse(_weight.text.trim()),
        'layout': _layout,
        'switch': _switchValue,
        'connection': _connection,
        'opened': _opened,
        'mods': _mods.text.trim(),
        'label_photo_url': label,
        'pcb_photo_url': ?pcb,
      });
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = _ref;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(r == null ? 'Legit Check' : 'Legit Check result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
          children: r != null
              ? [
                  if (widget.listing != null) Padding(padding: const EdgeInsets.only(bottom: Sp.md), child: Text(widget.listing!.title, style: context.tt.titleMedium)),
                  LegitResultView(key: ValueKey(r.checkedAt ?? r.verdict), result: r, reference: sel),
                  const SizedBox(height: Sp.xl),
                  if (widget.listing != null) Text('Saved on your listing.', style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
                  const SizedBox(height: Sp.md),
                  KeyButton(key: const ValueKey('legit.again'), label: 'Check another unit', secondary: true, onPressed: () => setState(() { _result = null; _label = _pcb = null; })),
                ]
              : [
                  Stagger(index: 0, child: Text(widget.listing == null ? 'Compare a keyboard to its published specs.' : 'Compare your listing to published specs.', style: context.tt.bodyLarge!.copyWith(color: context.cs.onSurfaceVariant))),
                  const SizedBox(height: Sp.lg),
                  if (sel == null) ..._picker() else _selected(sel),
                  if (sel != null) ..._form(sel),
                ],
        ),
      ),
    );
  }

  List<Widget> _picker() {
    final refs = ref.watch(legitRefsProvider(_q));
    return [
      TextField(
        key: const ValueKey('legit.search'),
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(labelText: 'Search brand or model', prefixIcon: Icon(Icons.search)),
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _q = v.trim()));
        },
      ),
      const SizedBox(height: Sp.md),
      refs.when(
        loading: () => const _RefSkeleton(),
        error: (e, _) => KeycapCard(
          child: Column(children: [
            Text(e is Exception ? 'Could not load models. Check your connection.' : 'Something went wrong.', style: context.tt.bodyMedium),
            const SizedBox(height: Sp.sm),
            TextButton(key: const ValueKey('legit.retry'), onPressed: () => ref.invalidate(legitRefsProvider(_q)), child: const Text('Try again')),
          ]),
        ),
        data: (list) => list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.xl),
                child: Column(children: [
                  Icon(Icons.keyboard_alt_outlined, size: 40, color: context.cs.onSurfaceVariant),
                  const SizedBox(height: Sp.sm),
                  Text('No model matches "$_q".', style: context.tt.titleMedium, textAlign: TextAlign.center),
                  Text('Try just the brand, like "Keychron".', style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant), textAlign: TextAlign.center),
                ]),
              )
            : Column(children: [
                for (var i = 0; i < list.length && i < 8; i++)
                  Padding(padding: const EdgeInsets.only(bottom: Sp.sm), child: Stagger(index: i, child: _refTile(list[i]))),
                if (list.length > 8) Text('${list.length - 8} more. Keep typing to narrow it down.', style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
              ]),
      ),
    ];
  }

  String _have(LegitReference r) {
    final have = [for (final e in _published.entries) if (r.fields[e.key] != null) e.value];
    return have.isEmpty ? 'No published data yet' : 'Published: ${have.join(', ')}';
  }

  Widget _refTile(LegitReference r) => KeycapCard(
        key: ValueKey('legit.ref.${r.id}'),
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
        onTap: () => _choose(r),
        semanticLabel: '${r.brand} ${r.model}. ${_have(r)}',
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.brand} ${r.model}', style: context.tt.titleMedium),
              Text(_have(r), style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      );

  Widget _selected(LegitReference r) => KeycapCard(
        key: const ValueKey('legit.selected'),
        child: Row(children: [
          Icon(Icons.keyboard, color: context.cs.primary),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.brand} ${r.model}', style: context.tt.titleMedium),
              Text(_have(r), style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
            ]),
          ),
          TextButton(key: const ValueKey('legit.change'), style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => setState(() => _ref = null), child: const Text('Change')),
        ]),
      );

  List<Widget> _form(LegitReference r) {
    final sw = _switches;
    const gap = SizedBox(height: Sp.lg);
    return [
      gap,
      TextField(key: const ValueKey('legit.serial'), controller: _serial, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Serial number (from the label)')),
      const SizedBox(height: Sp.md),
      TextField(
        key: const ValueKey('legit.weight'),
        controller: _weight,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Weight in grams (optional)', suffixText: 'g'),
      ),
      gap,
      ChoiceRow(label: 'Layout', keyPrefix: 'legit.layout', options: _layouts, value: _layout, clearable: false, onChanged: (v) => setState(() => _layout = v)),
      gap,
      ChoiceRow(label: 'Connection', keyPrefix: 'legit.connection', options: const {'wired': 'Wired', 'wireless': 'Wireless'}, value: _connection, clearable: false, onChanged: (v) => setState(() => _connection = v)),
      gap,
      DropdownButtonFormField<String>(
        key: ValueKey('legit.switch.${r.id}'),
        initialValue: _switch,
        isExpanded: true,
        decoration: InputDecoration(labelText: 'Switches installed', errorText: _submitted && _switch == null ? 'Choose one' : null),
        items: [
          for (final s in sw) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
          const DropdownMenuItem(value: _other, child: Text('Other')),
        ],
        onChanged: (v) => setState(() => _switch = v),
      ),
      if (sw.isEmpty) Padding(padding: const EdgeInsets.only(top: Sp.xs), child: Text('No published switch list for this model.', style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant))),
      if (_switch == _other) ...[
        const SizedBox(height: Sp.md),
        TextField(key: const ValueKey('legit.switch_other'), controller: _otherSwitch, decoration: const InputDecoration(labelText: 'Switch name')),
      ],
      gap,
      KeycapCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.xs),
        child: SwitchListTile(
          key: const ValueKey('legit.opened'),
          contentPadding: EdgeInsets.zero,
          title: Text('Board has been opened', style: context.tt.titleSmall),
          subtitle: const Text('Needs a photo of the PCB.'),
          value: _opened,
          onChanged: (v) => setState(() => _opened = v),
        ),
      ),
      gap,
      TextField(key: const ValueKey('legit.mods'), controller: _mods, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Declared mods (optional)', hintText: 'e.g. lubed switches, foam, new keycaps')),
      gap,
      Text('Photos', style: context.tt.titleMedium),
      const SizedBox(height: Sp.sm),
      SinglePhotoField(key: const ValueKey('legit.photo.label'), label: 'Underside label', hint: 'Required. Show the serial sticker.', item: _label, onChanged: (v) => setState(() => _label = v)),
      if (_opened) ...[
        const SizedBox(height: Sp.md),
        SinglePhotoField(key: const ValueKey('legit.photo.pcb'), label: 'PCB', hint: 'Required because the board was opened.', item: _pcb, onChanged: (v) => setState(() => _pcb = v)),
      ],
      const SizedBox(height: Sp.xl),
      KeyButton(key: const ValueKey('legit.submit'), label: 'Run Legit Check', icon: Icons.fact_check_outlined, busy: _busy, onPressed: _submit),
      const SizedBox(height: Sp.md),
      Text(legitDisclaimer, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
    ];
  }
}

class _RefSkeleton extends StatelessWidget {
  const _RefSkeleton();
  @override
  Widget build(BuildContext context) => Shimmer(
        child: Column(children: [
          for (var i = 0; i < 4; i++)
            Container(
              height: 64,
              margin: const EdgeInsets.only(bottom: Sp.sm),
              decoration: BoxDecoration(color: context.keys.skeleton, borderRadius: BorderRadius.circular(Rad.lg)),
            ),
        ]),
      );
}
