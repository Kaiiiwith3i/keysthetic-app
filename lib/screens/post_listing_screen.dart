import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listing.dart';
import '../models/user.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import '../widgets/choice_row.dart';
import '../widgets/keycap_card.dart';
import '../widgets/photo_picker_grid.dart';
import '../widgets/snack.dart';
import '../widgets/sound_recorder.dart';
import '../widgets/stagger.dart';

const _categories = {'keyboard': 'Keyboard', 'switches': 'Switches', 'keycaps': 'Keycaps', 'stabilizers': 'Stabilizers', 'cable': 'Cable'};
const _conditions = {'new': 'New', 'like_new': 'Like new', 'used': 'Used', 'for_parts': 'For parts'};
const _tagOptions = <String, (String, Map<String, String>)>{
  'kind': ('Kind', {'mechanical': 'Mechanical', 'standard': 'Standard'}),
  'connection': ('Connection', {'wired': 'Wired', 'wireless': 'Wireless'}),
  'layout': ('Layout', {'full': 'Full', 'tkl': 'TKL', '75': '75%', '65': '65%', '60': '60%', '40': '40%'}),
  'switch_type': ('Switch type', {'linear': 'Linear', 'tactile': 'Tactile', 'clicky': 'Clicky'}),
  'stem': ('Stem', {'mx': 'MX', 'alps': 'Alps', 'topre': 'Topre', 'low_profile': 'Low profile'}),
  'connector': ('Connector', {'usb_c': 'USB-C', 'usb_a': 'USB-A', 'mini_usb': 'Mini USB'}),
};
const _tagsFor = {
  'keyboard': ['kind', 'connection', 'layout', 'switch_type', 'stem', 'connector'],
  'switches': ['switch_type', 'stem'],
  'keycaps': ['stem'],
  'stabilizers': ['layout'],
  'cable': ['connector'],
};

/// The seller's current profile (for the payment QR); falls back to the session user.
final _meProvider = FutureProvider.autoDispose<User?>((ref) async {
  final s = ref.watch(sessionProvider);
  if (s.demo) return s.user;
  return ref.watch(apiProvider).me();
});

/// Post a listing, or edit [listing]. Pops with `true` once saved.
class PostListingScreen extends ConsumerStatefulWidget {
  const PostListingScreen({super.key, this.listing});
  final Listing? listing;
  @override
  ConsumerState<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends ConsumerState<PostListingScreen> {
  late final _title = TextEditingController(text: widget.listing?.title);
  late final _price = TextEditingController(text: widget.listing?.price.toString());
  late final _desc = TextEditingController(text: widget.listing?.description);
  late final _area = TextEditingController(text: widget.listing?.meetupArea ?? ref.read(sessionProvider).user?.area);
  late String _category = widget.listing?.category ?? 'keyboard';
  late String? _condition = widget.listing?.condition;
  late final Map<String, String?> _tags = {
    'kind': widget.listing?.kind,
    'connection': widget.listing?.connection,
    'layout': widget.listing?.layout,
    'switch_type': widget.listing?.switchType,
    'stem': widget.listing?.stem,
    'connector': widget.listing?.connector,
  };
  late List<PhotoItem> _photos = [for (final u in widget.listing?.photos ?? const <String>[]) PhotoItem.remote(u)];
  SoundClip? _clip;
  late String? _existingSound = widget.listing?.soundUrl;
  bool _busy = false, _done = false, _submitted = false, _qrBusy = false;
  String _status = '';

  bool get _editing => widget.listing != null;

  @override
  void dispose() {
    for (final c in [_title, _price, _desc, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _titleErr => _title.text.trim().length < 3 || _title.text.trim().length > 80 ? 'Title must be 3 to 80 characters' : null;
  String? get _priceErr {
    final p = int.tryParse(_price.text.trim());
    return p == null || p < 1 || p > 500000 ? 'Price must be between ₱1 and ₱500,000' : null;
  }

  String? get _areaErr => _area.text.trim().isEmpty || _area.text.trim().length > 80 ? 'Add a meetup area (up to 80 characters)' : null;
  String? get _descErr => _desc.text.trim().isEmpty || _desc.text.trim().length > 2000 ? 'Add a short description (up to 2000 characters)' : null;

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (_photos.isEmpty) return showMessage(context, 'Add at least one photo.');
    if (_condition == null) return showMessage(context, 'Choose the condition.');
    if ([_titleErr, _priceErr, _areaErr, _descErr].any((e) => e != null)) return showMessage(context, 'Check the highlighted fields.');
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        if (_photos[i].url == null) setState(() => _status = 'Uploading photo ${i + 1} of ${_photos.length}');
        urls.add(await _photos[i].upload(api, 'photo'));
      }
      String? sound = _existingSound;
      if (_clip != null) {
        setState(() => _status = 'Uploading sound clip');
        sound = await api.upload(kind: 'sound', filename: _clip!.filename, bytes: _clip!.bytes);
      }
      final relevant = _tagsFor[_category]!;
      final body = {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'price': int.parse(_price.text.trim()),
        'condition': _condition,
        for (final t in _tagOptions.keys) t: relevant.contains(t) ? _tags[t] : null,
        'meetup_area': _area.text.trim(),
        'photos': urls,
        'sound_url': sound,
      };
      setState(() => _status = 'Saving');
      _editing ? await api.updateListing(widget.listing!.id, body) : await api.createListing(body);
      if (!mounted) return;
      setState(() => _done = true);
      await Future<void>.delayed(context.reduceMotion ? const Duration(milliseconds: 500) : const Duration(milliseconds: 1100));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() { _busy = false; _status = ''; });
    }
  }

  Future<void> _uploadQr() async {
    final p = await pickPhoto(context);
    if (p == null || !mounted) return;
    setState(() => _qrBusy = true);
    try {
      final api = ref.read(apiProvider);
      await api.updateMe(paymentQrUrl: await p.upload(api, 'qr'));
      ref.invalidate(_meProvider);
      if (mounted) showMessage(context, 'Payment QR saved.');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _qrBusy = false);
    }
  }

  Widget _section(BuildContext context, int i, String title, Widget child, {String? sub}) => Padding(
        padding: const EdgeInsets.only(top: Sp.xl),
        child: Stagger(
          index: i,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: context.tt.titleMedium),
            if (sub != null) Text(sub, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
            const SizedBox(height: Sp.sm),
            child,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(_meProvider);
    final qr = me.value?.paymentQrUrl;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit listing' : 'Post listing')),
      body: Stack(children: [
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.xxl),
            children: [
              _section(context, 0, 'Photos', PhotoPickerGrid(items: _photos, onChanged: (v) => setState(() => _photos = v)), sub: 'Up to 6. The first is the cover. Tap a photo to move or remove it.'),
              if (_submitted && _photos.isEmpty) Padding(padding: const EdgeInsets.only(top: Sp.xs), child: Text('Add at least one photo', style: context.tt.bodySmall!.copyWith(color: context.cs.error))),
              _section(context, 1, 'Details', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(key: const ValueKey('post.title'), controller: _title, textInputAction: TextInputAction.next, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Title', errorText: _submitted ? _titleErr : null)),
                const SizedBox(height: Sp.md),
                TextField(key: const ValueKey('post.price'), controller: _price, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Price', prefixText: '₱ ', errorText: _submitted ? _priceErr : null)),
                const SizedBox(height: Sp.lg),
                ChoiceRow(label: 'Category', keyPrefix: 'post.category', options: _categories, value: _category, clearable: false, onChanged: (v) => setState(() => _category = v!)),
                const SizedBox(height: Sp.lg),
                ChoiceRow(label: 'Condition', keyPrefix: 'post.condition', options: _conditions, value: _condition, clearable: false, onChanged: (v) => setState(() => _condition = v)),
              ])),
              _section(context, 2, 'Compatibility', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final t in _tagsFor[_category]!) ...[
                  ChoiceRow(label: _tagOptions[t]!.$1, keyPrefix: 'post.tag.$t', options: _tagOptions[t]!.$2, value: _tags[t], onChanged: (v) => setState(() => _tags[t] = v)),
                  const SizedBox(height: Sp.md),
                ],
              ]), sub: 'Powers the Fits-My-Build match. Tap a chip again to clear it.'),
              _section(context, 3, 'Meetup and description', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(key: const ValueKey('post.area'), controller: _area, textInputAction: TextInputAction.next, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Meetup area', prefixIcon: const Icon(Icons.place_outlined), errorText: _submitted ? _areaErr : null)),
                const SizedBox(height: Sp.md),
                TextField(key: const ValueKey('post.description'), controller: _desc, minLines: 3, maxLines: 6, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Description', alignLabelWithHint: true, errorText: _submitted ? _descErr : null)),
              ])),
              _section(context, 4, 'Hear it first', SoundClipField(
                clip: _clip,
                existingUrl: _existingSound,
                onChanged: (c, {required removed}) => setState(() {
                  _clip = c;
                  if (c != null || removed) _existingSound = null;
                }),
              ), sub: 'Optional. A short clip of typing sounds sells boards.'),
              _section(context, 5, 'Payment QR', KeycapCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: qr == null
                          ? DecoratedBox(decoration: BoxDecoration(color: context.keys.skeleton, borderRadius: BorderRadius.circular(Rad.sm)), child: Icon(Icons.qr_code_2, color: context.cs.onSurfaceVariant, size: 36))
                          : ClipRRect(borderRadius: BorderRadius.circular(Rad.sm), child: Image(key: const ValueKey('post.qr.current'), image: mediaImage(ref, qr), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.qr_code_2))),
                    ),
                    const SizedBox(width: Sp.md),
                    Expanded(child: Text(qr == null ? 'No QR yet. Buyers who choose QR need one.' : 'Your current GCash / bank QR', style: context.tt.bodyMedium)),
                  ]),
                  const SizedBox(height: Sp.md),
                  KeyButton(key: const ValueKey('post.qr.upload'), label: 'Upload GCash/bank QR', icon: Icons.qr_code_scanner, secondary: true, busy: _qrBusy, onPressed: _uploadQr),
                  const SizedBox(height: Sp.md),
                  Text('Buyers pay outside the app. Keysthetic never processes money.', style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
                ]),
              )),
              const SizedBox(height: Sp.xl),
              KeyButton(key: const ValueKey('post.submit'), label: _busy && _status.isNotEmpty ? _status : (_editing ? 'Save changes' : 'Post listing'), busy: _busy, onPressed: _submit),
            ],
          ),
        ),
        if (_done) const Positioned.fill(child: _SuccessOverlay()),
      ]),
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();
  @override
  Widget build(BuildContext context) => ColoredBox(
        key: const ValueKey('post.success'),
        color: context.cs.surface.withValues(alpha: .94),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: context.reduceMotion ? 1 : 0, end: 1),
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: v, child: child)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 96, color: context.keys.accepted),
              const SizedBox(height: Sp.md),
              Text('Saved', style: context.tt.headlineMedium),
            ]),
          ),
        ),
      );
}
