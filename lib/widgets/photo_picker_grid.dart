
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api.dart';
import '../services/providers.dart';
import '../theme/tokens.dart';
import 'pressable.dart';
import 'snack.dart';

const maxImageBytes = 3 * 1024 * 1024; // server limit for photo / qr / legit

/// A photo that is either already on the server ([url]) or picked locally ([bytes]).
class PhotoItem {
  PhotoItem.local(this.name, Uint8List this.bytes) : url = null;
  PhotoItem.remote(String this.url) : name = '', bytes = null;
  final String name;
  final Uint8List? bytes;
  final String? url;

  /// Uploads local bytes (kind: photo | qr | legit); remote photos are returned as-is.
  Future<String> upload(Api api, String kind) async => url ?? await api.upload(kind: kind, filename: name, bytes: bytes!);
}

/// Camera / gallery sheet -> compressed, size-checked [PhotoItem]; null if cancelled or rejected (a message is shown).
Future<PhotoItem?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          key: const ValueKey('photo.camera'),
          minTileHeight: 56,
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Take a photo'),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          key: const ValueKey('photo.gallery'),
          minTileHeight: 56,
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null || !context.mounted) return null;
  try {
    final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    if (bytes.length > maxImageBytes) {
      if (context.mounted) showMessage(context, 'That photo is ${(bytes.length / 1048576).toStringAsFixed(1)} MB. The limit is 3 MB. Try a smaller one.');
      return null;
    }
    return PhotoItem.local(f.name.isEmpty ? 'photo.jpg' : f.name, bytes);
  } on PlatformException {
    if (context.mounted) {
      showMessage(context, source == ImageSource.camera
          ? 'Camera access is off. Allow it in Settings to take photos, or choose from the gallery.'
          : 'Keysthetic cannot open your photos. Allow access in Settings.');
    }
    return null;
  }
}

class PhotoView extends ConsumerWidget {
  const PhotoView(this.item, {super.key});
  final PhotoItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final err = ColoredBox(color: context.keys.skeleton, child: Icon(Icons.broken_image_outlined, color: context.cs.onSurfaceVariant));
    return item.bytes != null
        ? Image.memory(item.bytes!, fit: BoxFit.cover, errorBuilder: (_, _, _) => err)
        : Image(image: mediaImage(ref, item.url!), fit: BoxFit.cover, errorBuilder: (_, _, _) => err);
  }
}

/// Dashed-feel tile with an icon; the one "add" affordance.
class AddTile extends StatelessWidget {
  const AddTile({super.key, required this.label, required this.onTap, this.icon = Icons.add_a_photo_outlined});
  final String label;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        minSize: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.keys.capTop,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: context.cs.outline, width: 1.5),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: context.cs.primary),
              const SizedBox(height: Sp.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                child: Text(label, textAlign: TextAlign.center, style: context.tt.labelMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      );
}

/// One required/optional photo (Legit Check label & PCB, payment QR): preview + replace.
class SinglePhotoField extends StatelessWidget {
  const SinglePhotoField({super.key, required this.label, required this.item, required this.onChanged, this.hint});
  final String label;
  final String? hint;
  final PhotoItem? item;
  final ValueChanged<PhotoItem?> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 96,
          height: 96,
          child: item == null
              ? AddTile(label: 'Add photo', onTap: () async {
                  final p = await pickPhoto(context);
                  if (p != null) onChanged(p);
                })
              : ClipRRect(borderRadius: BorderRadius.circular(Rad.md), child: PhotoView(item!)),
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: context.tt.titleSmall),
            if (hint != null) Text(hint!, style: context.tt.bodySmall!.copyWith(color: context.cs.onSurfaceVariant)),
            if (item != null)
              Wrap(children: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () async {
                    final p = await pickPhoto(context);
                    if (p != null) onChanged(p);
                  },
                  child: const Text('Replace'),
                ),
                TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => onChanged(null), child: const Text('Remove')),
              ]),
          ]),
        ),
      ]);
}

/// Up to [max] photos in a 3-column grid. Tap a photo for move / remove.
/// Keys: `<keyPrefix>.add`, `<keyPrefix>.<index>`, sheet `<keyPrefix>.earlier|later|remove`.
class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({super.key, required this.items, required this.onChanged, this.max = 6, this.keyPrefix = 'post.photo'});
  final List<PhotoItem> items;
  final ValueChanged<List<PhotoItem>> onChanged;
  final int max;
  final String keyPrefix;

  Future<void> _add(BuildContext context) async {
    final p = await pickPhoto(context);
    if (p != null) onChanged([...items, p]);
  }

  Future<void> _actions(BuildContext context, int i) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (i > 0) ListTile(key: ValueKey('$keyPrefix.earlier'), minTileHeight: 56, leading: const Icon(Icons.arrow_back), title: Text(i == 1 ? 'Make cover photo' : 'Move earlier'), onTap: () => Navigator.pop(context, 'earlier')),
          if (i < items.length - 1) ListTile(key: ValueKey('$keyPrefix.later'), minTileHeight: 56, leading: const Icon(Icons.arrow_forward), title: const Text('Move later'), onTap: () => Navigator.pop(context, 'later')),
          ListTile(key: ValueKey('$keyPrefix.remove'), minTileHeight: 56, leading: Icon(Icons.delete_outline, color: context.cs.error), title: Text('Remove photo', style: TextStyle(color: context.cs.error)), onTap: () => Navigator.pop(context, 'remove')),
        ]),
      ),
    );
    final out = [...items];
    switch (a) {
      case 'earlier':
        out.insert(i - 1, out.removeAt(i));
      case 'later':
        out.insert(i + 1, out.removeAt(i));
      case 'remove':
        out.removeAt(i);
      default:
        return;
    }
    onChanged(out);
  }

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: Sp.sm,
        crossAxisSpacing: Sp.sm,
        children: [
          for (var i = 0; i < items.length; i++)
            Pressable(
              key: ValueKey('$keyPrefix.$i'),
              onTap: () => _actions(context, i),
              semanticLabel: 'Photo ${i + 1}${i == 0 ? ', cover' : ''}. Tap for options',
              minSize: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Rad.md),
                child: Stack(fit: StackFit.expand, children: [
                  PhotoView(items[i]),
                  if (i == 0)
                    Positioned(
                      left: Sp.xs,
                      bottom: Sp.xs,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: context.cs.primary, borderRadius: BorderRadius.circular(Rad.sm / 2)),
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: 2), child: Text('COVER', style: context.tt.labelSmall!.copyWith(color: context.cs.onPrimary))),
                      ),
                    ),
                ]),
              ),
            ),
          if (items.length < max) AddTile(key: ValueKey('$keyPrefix.add'), label: '${items.length}/$max\nAdd photo', onTap: () => _add(context)),
        ],
      );
}
