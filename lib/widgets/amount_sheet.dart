import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'keycap_card.dart';
import 'pressable.dart';
import 'price_chip.dart';

/// Bottom sheet with a peso keypad. Pops the entered amount (or null).
Future<int?> showAmountSheet(BuildContext context, {required String title, required String cta, int? hint}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AmountSheet(title: title, cta: cta, hint: hint),
    );

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.title, required this.cta, this.hint});
  final String title, cta;
  final int? hint;
  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  String _digits = '';
  int get _value => int.tryParse(_digits) ?? 0;

  void _press(String d) {
    if (_digits.length >= 7) return;
    setState(() => _digits = _digits + d);
    if (_digits.startsWith('0')) setState(() => _digits = '');
  }

  Widget _key(String id, Widget label, VoidCallback onTap, String semantic) => Padding(
    padding: const EdgeInsets.all(Sp.xs),
    child: Pressable(
      key: ValueKey('offer.key.$id'),
      semanticLabel: semantic,
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.keys.capTop,
          borderRadius: BorderRadius.circular(Rad.sm),
          border: Border(bottom: BorderSide(color: context.keys.capLip, width: 3)),
        ),
        child: label,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    Widget digit(String d) =>
        Expanded(child: _key(d, Text(d, style: monoStyle(22, cs.onSurface, w: 700)), () => _press(d), d));
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: context.tt.titleLarge),
            if (widget.hint != null)
              Text(
                'Currently ${formatPeso(widget.hint!)}',
                style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: Sp.md),
            Container(
              key: const ValueKey('offer.display'),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: Sp.lg),
              decoration: BoxDecoration(color: context.keys.skeleton, borderRadius: BorderRadius.circular(Rad.md)),
              child: FittedBox(
                child: Text(
                  formatPeso(_value),
                  style: monoStyle(36, _value == 0 ? cs.onSurfaceVariant : cs.onSurface, w: 700),
                ),
              ),
            ),
            const SizedBox(height: Sp.md),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(children: [for (final d in row) digit(d)]),
            Row(
              children: [
                Expanded(
                  child: _key(
                    'clear',
                    Text('C', style: monoStyle(20, cs.onSurfaceVariant, w: 700)),
                    () => setState(() => _digits = ''),
                    'Clear',
                  ),
                ),
                digit('0'),
                Expanded(
                  child: _key(
                    'backspace',
                    Icon(Icons.backspace_outlined, color: cs.onSurface),
                    () => setState(() => _digits = _digits.isEmpty ? '' : _digits.substring(0, _digits.length - 1)),
                    'Delete digit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.md),
            KeyButton(
              key: const ValueKey('offer.submit'),
              label: _value == 0 ? widget.cta : '${widget.cta} ${formatPeso(_value)}',
              onPressed: _value == 0 ? null : () => Navigator.of(context).pop(_value),
            ),
          ],
        ),
      ),
    );
  }
}
