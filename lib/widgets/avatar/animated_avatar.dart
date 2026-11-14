import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/assistant_settings.dart';
import '../../models/emotion.dart';
import 'face_painter.dart';

/// A living, animated face: it blinks, looks around, breathes, sways its
/// head, lip-syncs while speaking, perks up while listening, and reacts
/// with a little bounce whenever its expression changes or it's tapped.
class AnimatedAvatar extends StatefulWidget {
  final AssistantSettings settings;
  final Emotion emotion;
  final bool speaking;
  final bool listening;
  final bool thinking;

  /// Microphone level 0..1 while listening.
  final ValueListenable<double>? listenLevel;

  /// Ticks once per spoken word (from the TTS engine) for lip-sync timing.
  final ValueListenable<int>? wordTick;

  final double size;

  /// Allow taps to trigger playful reactions.
  final bool interactive;

  const AnimatedAvatar({
    super.key,
    required this.settings,
    this.emotion = Emotion.neutral,
    this.speaking = false,
    this.listening = false,
    this.thinking = false,
    this.listenLevel,
    this.wordTick,
    this.size = 220,
    this.interactive = true,
  });

  @override
  State<AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<AnimatedAvatar> with SingleTickerProviderStateMixin {
  final _rng = math.Random();
  late final Ticker _ticker;
  double _t = 0;
  double _lastT = 0;

  // Blinking.
  double _nextBlink = 1.5;
  double _blinkStart = -1;
  bool _doubleBlink = false;

  // Gaze.
  Offset _gaze = Offset.zero;
  Offset _gazeTarget = Offset.zero;
  double _nextGaze = 1;

  // Lip-sync.
  double _mouth = 0;
  double _mouthShape = 0;
  double _wordEnvelope = 0;
  double _lastWordAt = -10;
  double _syllablePhase = 0;

  // Reactions.
  double _reactionStart = -10;
  Emotion? _tapEmotion;
  double _tapUntil = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    widget.wordTick?.addListener(_onWord);
  }

  @override
  void didUpdateWidget(AnimatedAvatar old) {
    super.didUpdateWidget(old);
    if (old.wordTick != widget.wordTick) {
      old.wordTick?.removeListener(_onWord);
      widget.wordTick?.addListener(_onWord);
    }
    if (old.emotion != widget.emotion || old.settings.avatarStyle != widget.settings.avatarStyle) {
      _reactionStart = _t;
    }
  }

  @override
  void dispose() {
    widget.wordTick?.removeListener(_onWord);
    _ticker.dispose();
    super.dispose();
  }

  void _onWord() {
    _wordEnvelope = 1;
    _lastWordAt = _t;
    _mouthShape = _rng.nextDouble() * 2 - 1;
  }

  void _tick(Duration elapsed) {
    _t = elapsed.inMicroseconds / 1e6;
    final dt = (_t - _lastT).clamp(0.0, 0.1);
    _lastT = _t;

    // ── Blink ──
    if (_t >= _nextBlink && _blinkStart < 0) {
      _blinkStart = _t;
    }
    if (_blinkStart >= 0 && _t - _blinkStart > 0.18) {
      _blinkStart = -1;
      if (!_doubleBlink && _rng.nextDouble() < 0.18) {
        _doubleBlink = true;
        _nextBlink = _t + 0.12;
      } else {
        _doubleBlink = false;
        _nextBlink = _t + 2 + _rng.nextDouble() * 4;
      }
    }

    // ── Gaze ── (wander when idle, look at the user while listening,
    // glance up and aside while thinking).
    if (widget.listening) {
      _gazeTarget = Offset.zero;
    } else if (widget.thinking) {
      _gazeTarget = Offset(0.6, -0.8 + 0.1 * math.sin(_t * 2));
    } else if (_t >= _nextGaze) {
      _gazeTarget = _rng.nextDouble() < 0.4
          ? Offset.zero
          : Offset(_rng.nextDouble() * 1.6 - 0.8, _rng.nextDouble() * 1.0 - 0.5);
      _nextGaze = _t + 1.2 + _rng.nextDouble() * 3;
    }
    _gaze = Offset.lerp(_gaze, _gazeTarget, 1 - math.exp(-dt * 12))!;

    // ── Lip-sync ──
    double target = 0;
    if (widget.speaking) {
      _syllablePhase += dt * 2 * math.pi * 4.2;
      final syllable = (math.sin(_syllablePhase) + 1) / 2; // ~4 syllables/s
      final jitter = (math.sin(_syllablePhase * 2.3 + 1) + 1) / 4;
      final hasWordTicks = _t - _lastWordAt < 1.2;
      if (hasWordTicks) {
        _wordEnvelope = math.max(0, _wordEnvelope - dt * 2.2);
        target = (0.25 + 0.75 * _wordEnvelope) * (0.35 + 0.65 * syllable) + jitter * 0.1;
      } else {
        // Engine doesn't report word boundaries: procedural speech rhythm
        // with brief pauses between "words".
        final wordGate = math.sin(_syllablePhase * 0.23) > -0.75 ? 1.0 : 0.15;
        target = (0.2 + 0.7 * syllable + jitter * 0.2) * wordGate;
      }
      if (_rng.nextDouble() < dt * 3) _mouthShape = _rng.nextDouble() * 2 - 1;
    }
    _mouth += (target - _mouth) * (1 - math.exp(-dt * 22));
    if (!widget.speaking && _mouth < 0.01) _mouth = 0;

    if (_tapEmotion != null && _t > _tapUntil) _tapEmotion = null;

    setState(() {});
  }

  double get _blink {
    if (_blinkStart < 0) return 0;
    final p = (_t - _blinkStart) / 0.18;
    return p < 0.5 ? p * 2 : (1 - p) * 2;
  }

  void _onTap() {
    if (!widget.interactive) return;
    const reactions = [Emotion.laugh, Emotion.playful, Emotion.love, Emotion.wink, Emotion.surprised];
    _tapEmotion = reactions[_rng.nextInt(reactions.length)];
    _tapUntil = _t + 1.6;
    _reactionStart = _t;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final listenLevel = widget.listenLevel?.value ?? 0;
    final emotion = _tapEmotion ??
        (widget.thinking
            ? Emotion.thinking
            : widget.listening && widget.emotion == Emotion.neutral
                ? Emotion.happy
                : widget.emotion);

    // Head motion: breathing bob, idle sway, nodding while talking, curious
    // tilt while listening, and a springy pop on reactions.
    final talkNod = widget.speaking ? math.sin(_t * 5.5) * 0.025 * (0.4 + _mouth) : 0.0;
    final tilt = math.sin(_t * 0.7) * 0.035 +
        (widget.listening ? 0.08 : 0) +
        (widget.thinking ? -0.06 : 0) +
        _gaze.dx * 0.03;
    final bob = math.sin(_t * 1.6) * widget.size * 0.008 + talkNod * widget.size;
    final rx = _t - _reactionStart;
    final pop = rx >= 0 && rx < 0.6 ? math.sin(rx / 0.6 * math.pi) * math.exp(-rx * 3) * 0.12 : 0.0;
    final breathe = 1 + math.sin(_t * 1.6) * 0.006 + listenLevel * 0.04 + pop;

    final frame = FaceFrame(
      style: s.avatarStyle,
      gender: s.gender,
      emotion: emotion,
      blink: emotion == Emotion.sleepy ? math.max(_blink, 0) : _blink,
      mouthOpen: _mouth,
      mouthShape: _mouthShape,
      lookX: _gaze.dx,
      lookY: _gaze.dy,
      time: _t,
      listenLevel: listenLevel,
      accent: s.accentColor,
      skin: s.skinTone,
      hair: s.hairColor,
      eye: s.eyeColor,
    );

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.listening || widget.speaking)
              _Halo(color: s.accentColor, intensity: widget.listening ? 0.4 + listenLevel * 0.6 : 0.25 + _mouth * 0.4),
            Transform.translate(
              offset: Offset(_gaze.dx * widget.size * 0.012, bob),
              child: Transform.rotate(
                angle: tilt,
                child: Transform.scale(
                  scale: breathe,
                  child: CustomPaint(size: Size.square(widget.size), painter: FacePainter(frame)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  final Color color;
  final double intensity;
  const _Halo({required this.color, required this.intensity});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Container(
        width: c.maxWidth * 0.98,
        height: c.maxHeight * 0.98,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35 * intensity.clamp(0.0, 1.0)),
              blurRadius: 30 + 30 * intensity,
              spreadRadius: 4 + 10 * intensity,
            ),
          ],
        ),
      ),
    );
  }
}
