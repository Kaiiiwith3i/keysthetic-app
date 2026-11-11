import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/legit.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/admin_bits.dart';
import '../widgets/keycap_card.dart';
import '../widgets/snack.dart';

/// key, label, kind: text | list (comma separated) | number
const legitFieldDefs = [
  ('layout', 'Layout', 'text'),
  ('switches', 'Switches', 'list'),
  ('keycap_material', 'Keycap material', 'text'),
  ('keycap_profile', 'Keycap profile', 'text'),
  ('connection', 'Connection', 'text'),
  ('weight_g', 'Weight (g)', 'number'),
  ('serial_format', 'Serial format', 'text'),
  ('counterfeit_tells', 'Counterfeit tells', 'list'),
];

final _slug = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
String _today() => DateTime.now().toIso8601String().substring(0, 10);

class _FieldCtrl {
  _FieldCtrl(LegitField? f)
      : value = TextEditingController(text: switch (f?.value) { null => '', List l => l.join(', '), final v => '$v' }),
        source = TextEditingController(text: f?.source ?? ''),
        accessed = TextEditingController(text: f?.accessed ?? ''),
        regex = TextEditingController(text: f?.regex ?? '') {
    value.addListener(() {
      if (value.text.trim().isNotEmpty && accessed.text.isEmpty) accessed.text = _today();
    });
  }
  final TextEditingController value, source, accessed, regex;
  bool get empty => value.text.trim().isEmpty;
  void dispose() {
    for (final c in [value, source, accessed, regex]) {
      c.dispose();
    }
  }
}

/// Create (reference == null) or edit one Legit DB reference. Pops `true` when something changed.
class AdminLegitEditScreen extends ConsumerStatefulWidget {
  const AdminLegitEditScreen({super.key, this.reference});
  final LegitReference? reference;
  @override
  ConsumerState<AdminLegitEditScreen> createState() => _AdminLegitEditScreenState();
}

class _AdminLegitEditScreenState extends ConsumerState<AdminLegitEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _id = TextEditingController(text: widget.reference?.id ?? '');
  late final _brand = TextEditingController(text: widget.reference?.brand ?? '');
  late final _model = TextEditingController(text: widget.reference?.model ?? '');
  late final _f = {for (final (k, _, _) in legitFieldDefs) k: _FieldCtrl(widget.reference?.fields[k])};
  bool _busy = false;

  bool get _isNew => widget.reference == null;

  @override
  void dispose() {
    for (final c in [_id, _brand, _model]) {
      c.dispose();
    }
    for (final f in _f.values) {
      f.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _payload() => {
        'id': _id.text.trim(),
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'fields': {
          for (final (k, _, kind) in legitFieldDefs)
            k: _f[k]!.empty
                ? null
                : {
                    'value': switch (kind) {
                      'list' => _f[k]!.value.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      'number' => num.parse(_f[k]!.value.text.trim()),
                      _ => _f[k]!.value.text.trim(),
                    },
                    if (k == 'serial_format') 'regex': _f[k]!.regex.text.trim().isEmpty ? null : _f[k]!.regex.text.trim(),
                    'source': _f[k]!.source.text.trim(),
                    'accessed': _f[k]!.accessed.text.trim(),
                  },
        },
      };

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (!mounted) return;
      showMessage(context, done);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showApiError(context, e);
      }
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final api = ref.read(apiProvider);
    final p = _payload();
    _run(() => _isNew ? api.adminCreateReference(p) : api.adminUpdateReference(widget.reference!.id, p), _isNew ? 'Reference created.' : 'Reference saved.');
  }

  Future<void> _delete() async {
    final r = widget.reference!;
    final ok = await confirmAction(context,
        title: 'Delete ${r.brand} ${r.model}?', body: 'Legit Check can no longer compare listings to this reference. This cannot be undone.', confirmLabel: 'Delete', keyPrefix: 'legit_edit.delete_confirm', destructive: true);
    if (ok && mounted) _run(() => ref.read(apiProvider).adminDeleteReference(r.id), 'Reference deleted.');
  }

  Future<void> _pickDate(TextEditingController c) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(c.text) ?? now, firstDate: DateTime(2015), lastDate: now);
    if (d != null) c.text = d.toIso8601String().substring(0, 10);
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New reference' : 'Edit reference')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.xxl),
            children: [
              TextFormField(
                key: const ValueKey('legit_edit.id'),
                controller: _id,
                enabled: _isNew,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'ID (lowercase slug)', hintText: 'keychron-q1-pro'),
                validator: (v) => _slug.hasMatch((v ?? '').trim()) ? null : 'Lowercase letters, digits and dashes, starting with a letter or digit (max 64)',
              ),
              const SizedBox(height: Sp.md),
              TextFormField(key: const ValueKey('legit_edit.brand'), controller: _brand, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Brand'), validator: _required),
              const SizedBox(height: Sp.md),
              TextFormField(key: const ValueKey('legit_edit.model'), controller: _model, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Model'), validator: _required),
              const SizedBox(height: Sp.lg),
              Text('Specs', style: context.tt.titleMedium),
              const SizedBox(height: Sp.xs),
              Text('Leave a value empty when there is no published source. It is saved as missing, never guessed.', style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
              const SizedBox(height: Sp.md),
              for (final (k, label, kind) in legitFieldDefs) ...[_fieldCard(k, label, kind), const SizedBox(height: Sp.md)],
              const SizedBox(height: Sp.sm),
              KeyButton(key: const ValueKey('legit_edit.save'), label: _isNew ? 'Create reference' : 'Save changes', icon: Icons.check, busy: _busy, onPressed: _save),
              if (!_isNew) ...[
                const SizedBox(height: Sp.md),
                KeyButton(key: const ValueKey('legit_edit.delete'), label: 'Delete reference', icon: Icons.delete_outline, secondary: true, onPressed: _busy ? null : _delete),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldCard(String k, String label, String kind) {
    final f = _f[k]!;
    return KeycapCard(
      padding: const EdgeInsets.all(Sp.md),
      child: ListenableBuilder(
        listenable: f.value,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(label, style: context.tt.titleSmall)),
            if (f.empty) Flexible(child: Text('No published source', key: ValueKey('legit_edit.$k.null'), textAlign: TextAlign.end, style: context.tt.labelMedium!.copyWith(color: context.keys.offer))),
          ]),
          const SizedBox(height: Sp.sm),
          TextFormField(
            key: ValueKey('legit_edit.$k.value'),
            controller: f.value,
            keyboardType: kind == 'number' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(labelText: kind == 'list' ? 'Values, comma separated' : 'Value'),
            validator: (v) => kind == 'number' && (v ?? '').trim().isNotEmpty && num.tryParse(v!.trim()) == null ? 'Enter a number' : null,
          ),
          AnimatedSize(
            duration: context.reduceMotion ? Duration.zero : Dur.base,
            alignment: Alignment.topCenter,
            child: f.empty
                ? const SizedBox(width: double.infinity)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: Sp.sm),
                    TextFormField(
                      key: ValueKey('legit_edit.$k.source'),
                      controller: f.source,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Source URL'),
                      validator: (v) => RegExp(r'^https?://\S+$').hasMatch((v ?? '').trim()) ? null : 'Enter the http(s) link where this was published',
                    ),
                    const SizedBox(height: Sp.sm),
                    TextFormField(
                      key: ValueKey('legit_edit.$k.accessed'),
                      controller: f.accessed,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: 'Accessed (YYYY-MM-DD)',
                        suffixIcon: IconButton(key: ValueKey('legit_edit.$k.pick_date'), tooltip: 'Pick date', icon: const Icon(Icons.calendar_today_outlined), onPressed: () => _pickDate(f.accessed)),
                      ),
                      validator: (v) => _date.hasMatch((v ?? '').trim()) ? null : 'Use YYYY-MM-DD',
                    ),
                    if (k == 'serial_format') ...[
                      const SizedBox(height: Sp.sm),
                      TextFormField(
                        key: const ValueKey('legit_edit.serial_format.regex'),
                        controller: f.regex,
                        autocorrect: false,
                        style: monoStyle(14, context.cs.onSurface),
                        decoration: const InputDecoration(labelText: 'Serial regex (optional)'),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) return null;
                          try {
                            RegExp(v!.trim());
                            return null;
                          } on FormatException {
                            return 'Not a valid regular expression';
                          }
                        },
                      ),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }
}
