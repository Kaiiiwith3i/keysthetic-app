import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'keycap_card.dart';
import 'pressable.dart';
import 'snack.dart';
import 'waveform.dart';

/// "Hear it first": play/pause over a [Waveform]. [url] is the listing's
/// `/storage/...` path: streamed from the server live, read from the bundle in demo mode.
/// The platform player is created on first tap, so the card renders without it.
class SoundPlayer extends ConsumerStatefulWidget {
  const SoundPlayer({super.key, required this.url});
  final String url;
  @override
  ConsumerState<SoundPlayer> createState() => _SoundPlayerState();
}

class _SoundPlayerState extends ConsumerState<SoundPlayer> {
  AudioPlayer? _p;
  final _subs = <StreamSubscription<void>>[];
  bool _playing = false, _started = false;
  Duration _pos = Duration.zero, _dur = Duration.zero;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p?.dispose();
    super.dispose();
  }

  Source _source() {
    final s = ref.read(sessionProvider);
    return s.demo ? AssetSource('demo${widget.url}') : UrlSource('${s.baseUrl ?? ''}${widget.url}');
  }

  Future<void> _toggle() async {
    try {
      var p = _p;
      if (p == null) {
        p = _p = AudioPlayer();
        _subs.addAll([
          p.onPlayerStateChanged.listen((s) => mounted ? setState(() => _playing = s == PlayerState.playing) : null),
          p.onPositionChanged.listen((d) => mounted ? setState(() => _pos = d) : null),
          p.onDurationChanged.listen((d) => mounted ? setState(() => _dur = d) : null),
          p.onPlayerComplete.listen((_) => mounted ? setState(() {
                _started = false;
                _pos = Duration.zero;
              }) : null),
        ]);
      }
      if (_playing) {
        await p.pause();
      } else if (_started) {
        await p.resume();
      } else {
        _started = true;
        await p.play(_source());
      }
    } catch (_) {
      _started = false;
      if (mounted) showMessage(context, "Couldn't play this sound.");
    }
  }

  String _t(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final progress = _dur.inMilliseconds == 0 ? 0.0 : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    return KeycapCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Row(children: [
        Pressable(
          key: const ValueKey('detail.sound.play'),
          semanticLabel: _playing ? 'Pause typing sound' : 'Play typing sound',
          minSize: 56,
          onTap: _toggle,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: cs.onPrimary, size: 30),
          ),
        ),
        const SizedBox(width: Sp.md),
        Expanded(child: Waveform(progress: progress, playing: _playing, height: 44)),
        const SizedBox(width: Sp.md),
        Text(_t(_playing || _started ? _pos : _dur), style: monoStyle(13, cs.onSurfaceVariant)),
      ]),
    );
  }
}
