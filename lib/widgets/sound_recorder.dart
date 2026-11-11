import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'keycap_card.dart';
import 'snack.dart';
import 'waveform.dart';

const maxSoundBytes = 2 * 1024 * 1024; // server limit
const minClip = Duration(seconds: 5), maxClip = Duration(seconds: 10);

class SoundClip {
  const SoundClip(this.filename, this.bytes);
  final String filename;
  final Uint8List bytes;
}

/// "Hear it first" clip editor: record 5-10 s in-app (AAC/m4a) or pick an audio
/// file (<= 2 MB), then preview it on the [Waveform]. [existingUrl] is a clip
/// already on the listing (shown until replaced). Keys: `post.sound.record|stop|pick|play|remove`.
class SoundClipField extends ConsumerStatefulWidget {
  const SoundClipField({super.key, required this.clip, required this.existingUrl, required this.onChanged});
  final SoundClip? clip;
  final String? existingUrl;
  final void Function(SoundClip? clip, {required bool removed}) onChanged;

  @override
  ConsumerState<SoundClipField> createState() => _SoundClipFieldState();
}

class _SoundClipFieldState extends ConsumerState<SoundClipField> {
  AudioRecorder? _rec;
  AudioPlayer? _player;
  Timer? _tick;
  final _watch = Stopwatch();
  bool _recording = false, _playing = false;
  double _level = 0, _progress = 0;
  Duration _elapsed = Duration.zero;

  bool get _hasSound => widget.clip != null || widget.existingUrl != null;

  @override
  void dispose() {
    _tick?.cancel();
    _rec?.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _rec ??= AudioRecorder();
      if (!await _rec!.hasPermission()) {
        if (mounted) showMessage(context, 'Microphone access is off. Allow it in Settings to record, or pick an audio file instead.');
        return;
      }
      await _player?.stop();
      final path = '${Directory.systemTemp.path}/clip_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec!.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not start recording on this device. Try picking an audio file instead.');
      return;
    }
    _watch..reset()..start();
    setState(() {
      _recording = true;
      _playing = false;
      _elapsed = Duration.zero;
      _level = 0;
    });
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final db = (await _rec!.getAmplitude()).current; // dBFS, about -60..0
      if (!mounted || !_recording) return;
      setState(() {
        _elapsed = _watch.elapsed;
        _level = ((db + 55) / 55).clamp(0.0, 1.0);
      });
      if (_elapsed >= maxClip) _stop();
    });
  }

  Future<void> _stop() async {
    if (!_recording) return;
    if (_watch.elapsed < minClip) {
      showMessage(context, 'Keep going: clips need at least 5 seconds.');
      return;
    }
    _tick?.cancel();
    _watch.stop();
    final path = await _rec!.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    if (bytes.length > maxSoundBytes) {
      if (mounted) showMessage(context, 'That clip is over 2 MB. Try a shorter one.');
      return;
    }
    widget.onChanged(SoundClip('clip.m4a', bytes), removed: false);
  }

  Future<void> _pick() async {
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['m4a', 'aac', 'wav', 'mp3']);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      if (bytes.length > maxSoundBytes) {
        showMessage(context, 'That file is ${(bytes.length / 1048576).toStringAsFixed(1)} MB. The limit is 2 MB.');
        return;
      }
      await _player?.stop();
      widget.onChanged(SoundClip(f.name, bytes), removed: false);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open that file. Allow file access and try again.');
    }
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player!.pause();
      setState(() => _playing = false);
      return;
    }
    try {
      if (_player == null) {
        final p = _player = AudioPlayer();
        p.onPlayerComplete.listen((_) => mounted ? setState(() { _playing = false; _progress = 0; }) : null);
        p.onPositionChanged.listen((pos) async {
          final d = await p.getDuration();
          if (mounted && d != null && d.inMilliseconds > 0) setState(() => _progress = pos.inMilliseconds / d.inMilliseconds);
        });
      }
      final c = widget.clip;
      final s = ref.read(sessionProvider);
      await _player!.play(c != null ? BytesSource(c.bytes) : UrlSource('${s.baseUrl ?? ''}${widget.existingUrl}'));
      setState(() => _playing = true);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not play that clip.');
    }
  }

  String _fmt(Duration d) => '${d.inSeconds.toString().padLeft(2, '0')}.${(d.inMilliseconds % 1000 ~/ 100)} s';

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return KeycapCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_recording) ...[
          Row(children: [
            Icon(Icons.fiber_manual_record, color: cs.error, size: 16),
            const SizedBox(width: Sp.sm),
            Text('Recording ${_fmt(_elapsed)}', key: const ValueKey('post.sound.timer'), style: monoStyle(15, cs.onSurface)),
            const Spacer(),
            Text('${minClip.inSeconds}-${maxClip.inSeconds} s', style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: Sp.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              key: const ValueKey('post.sound.level'),
              value: _level,
              minHeight: 10,
              backgroundColor: context.keys.skeleton,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          const SizedBox(height: Sp.md),
          KeyButton(key: const ValueKey('post.sound.stop'), label: 'Stop recording', icon: Icons.stop_circle_outlined, onPressed: _stop),
        ] else if (_hasSound) ...[
          Row(children: [
            IconButton(
              key: const ValueKey('post.sound.play'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: _playing ? 'Pause' : 'Play clip',
              icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36, color: cs.primary),
              onPressed: _togglePlay,
            ),
            Expanded(child: Waveform(progress: _progress, playing: _playing, height: 40)),
          ]),
          Text(widget.clip != null ? 'New clip ready (${widget.clip!.filename})' : 'Current clip on this listing',
              style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: Sp.sm),
          Wrap(spacing: Sp.sm, children: [
            TextButton.icon(key: const ValueKey('post.sound.record'), style: _tb, onPressed: _start, icon: const Icon(Icons.mic_none), label: const Text('Re-record')),
            TextButton.icon(key: const ValueKey('post.sound.pick'), style: _tb, onPressed: _pick, icon: const Icon(Icons.audio_file_outlined), label: const Text('Pick file')),
            TextButton.icon(
              key: const ValueKey('post.sound.remove'),
              style: _tb,
              onPressed: () {
                _player?.stop();
                setState(() { _playing = false; _progress = 0; });
                widget.onChanged(null, removed: true);
              },
              icon: Icon(Icons.delete_outline, color: cs.error),
              label: Text('Remove', style: TextStyle(color: cs.error)),
            ),
          ]),
        ] else ...[
          Text('Record the clack, 5 to 10 seconds, or pick an audio file up to 2 MB.', style: context.tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          Row(children: [
            Expanded(child: KeyButton(key: const ValueKey('post.sound.record'), label: 'Record', icon: Icons.mic, onPressed: _start)),
            const SizedBox(width: Sp.md),
            Expanded(child: KeyButton(key: const ValueKey('post.sound.pick'), label: 'Pick file', icon: Icons.audio_file_outlined, secondary: true, onPressed: _pick)),
          ]),
        ],
      ]),
    );
  }

  static final _tb = TextButton.styleFrom(minimumSize: const Size(48, 48));
}
