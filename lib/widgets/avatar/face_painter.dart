import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/assistant_settings.dart';
import '../../models/emotion.dart';

/// Everything needed to draw one frame of the face.
@immutable
class FaceFrame {
  final AvatarStyle style;
  final AssistantGender gender;
  final Emotion emotion;

  /// 0 = eyes open, 1 = fully closed.
  final double blink;

  /// 0 = closed, 1 = wide open (lip-sync).
  final double mouthOpen;

  /// Mouth shape variation while talking (-1..1): wide vs round vowels.
  final double mouthShape;

  /// Gaze direction, -1..1 on each axis.
  final double lookX, lookY;

  /// Seconds since the avatar started; drives small looping details.
  final double time;

  /// Microphone level while the user is speaking (0..1).
  final double listenLevel;

  final Color accent, skin, hair, eye;

  const FaceFrame({
    required this.style,
    required this.gender,
    required this.emotion,
    this.blink = 0,
    this.mouthOpen = 0,
    this.mouthShape = 0,
    this.lookX = 0,
    this.lookY = 0,
    this.time = 0,
    this.listenLevel = 0,
    required this.accent,
    required this.skin,
    required this.hair,
    required this.eye,
  });
}

enum _Eye { dot, ring, sparkle, chevron, sleepArc, happyArc, cross, spiral }

enum _Mouth { smile, bigSmile, cat, frown, flat, wavy, tongue, o, teeth, pout, beak }

/// Paints the face in a -1..1 unit space so it scales to any size.
class FacePainter extends CustomPainter {
  final FaceFrame f;
  FacePainter(this.f);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(r);
    switch (f.style) {
      case AvatarStyle.orb:
        _paintOrb(canvas);
      case AvatarStyle.kawaii:
        _paintKawaii(canvas);
      case AvatarStyle.human:
        _HumanFace(f).paint(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FacePainter old) => true;

  // ───────────────────────────── Orb (robot) ─────────────────────────────

  void _paintOrb(Canvas c) {
    final accent = f.accent;
    // Drop shadow.
    c.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.93), width: 1.2, height: 0.12),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.05),
    );
    // Metallic shell.
    final shell = Rect.fromCircle(center: Offset.zero, radius: 0.88);
    c.drawCircle(
      Offset.zero,
      0.88,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [Color(0xFFFFFFFF), Color(0xFFC9D2DC), Color(0xFF6E7C8C), Color(0xFF39434F)],
          stops: [0, 0.35, 0.8, 1],
        ).createShader(shell),
    );
    // Side "ear" light.
    final earRect = Rect.fromCenter(center: const Offset(-0.86, 0.02), width: 0.16, height: 0.34);
    c.drawOval(earRect.inflate(0.04), Paint()..color = const Color(0xFF8C98A6));
    c.drawOval(
      earRect,
      Paint()
        ..color = accent
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.04),
    );
    // Screen.
    final screen = Rect.fromCenter(center: const Offset(0.06, 0.02), width: 1.42, height: 1.36);
    c.drawOval(
      screen.inflate(0.035),
      Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03),
    );
    c.drawOval(
      screen,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          colors: [
            Color.lerp(const Color(0xFF14243D), accent, 0.08 + 0.15 * f.listenLevel)!,
            const Color(0xFF060B16),
          ],
        ).createShader(screen),
    );

    // Face features, with a soft glow pass beneath a crisp pass.
    c.save();
    c.translate(0.06 + f.lookX * 0.07, 0.04 + f.lookY * 0.05);
    c.scale(1.05);
    final glow = Paint()
      ..color = accent.withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.05);
    final ink = Paint()..color = Color.lerp(accent, Colors.white, 0.35)!;
    _doodleFeatures(c, glow, accent.withValues(alpha: 0.75), orb: true);
    _doodleFeatures(c, ink, Color.lerp(accent, Colors.white, 0.5)!, orb: true);
    c.restore();

    // Glass reflection on the screen.
    c.save();
    c.clipPath(Path()..addOval(screen));
    c.drawOval(
      Rect.fromCenter(center: const Offset(-0.18, -0.48), width: 1.0, height: 0.42),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCenter(center: const Offset(-0.18, -0.48), width: 1.0, height: 0.42)),
    );
    c.restore();
  }

  // ───────────────────────────── Kawaii ─────────────────────────────

  void _paintKawaii(Canvas c) {
    final face = Rect.fromCenter(center: Offset.zero, width: 1.9, height: 1.8);
    c.drawOval(
      face.shift(const Offset(0, 0.04)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.05),
    );
    c.drawOval(
      face,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [Colors.white, Color.lerp(Colors.white, f.accent, 0.12)!],
        ).createShader(face),
    );
    c.drawOval(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025
        ..color = Color.lerp(const Color(0xFFE6D5CF), f.accent, 0.3)!,
    );
    c.save();
    c.translate(f.lookX * 0.06, 0.05 + f.lookY * 0.05);
    _doodleFeatures(c, Paint()..color = const Color(0xFF5A1D10), const Color(0xFFF08C8C), orb: false);
    c.restore();
  }

  // ───────────────────────── Shared doodle features ─────────────────────────

  (_Eye, _Eye) _eyesFor(Emotion e) => switch (e) {
        Emotion.laugh => (_Eye.chevron, _Eye.chevron),
        Emotion.wink || Emotion.playful => (_Eye.dot, _Eye.chevron),
        Emotion.love => (_Eye.sparkle, _Eye.sparkle),
        Emotion.surprised => (_Eye.ring, _Eye.ring),
        Emotion.confused => (_Eye.spiral, _Eye.spiral),
        Emotion.crying => (_Eye.chevron, _Eye.chevron),
        Emotion.sleepy => (_Eye.sleepArc, _Eye.sleepArc),
        Emotion.dizzy => (_Eye.cross, _Eye.cross),
        Emotion.happy when f.time % 9 > 6 => (_Eye.happyArc, _Eye.happyArc),
        _ => (_Eye.dot, _Eye.dot),
      };

  _Mouth _mouthFor(Emotion e) => switch (e) {
        Emotion.neutral => _Mouth.smile,
        Emotion.happy => _Mouth.smile,
        Emotion.laugh => _Mouth.bigSmile,
        Emotion.wink => _Mouth.smile,
        Emotion.playful => _Mouth.tongue,
        Emotion.love => _Mouth.cat,
        Emotion.surprised => _Mouth.o,
        Emotion.thinking => _Mouth.flat,
        Emotion.confused => _Mouth.pout,
        Emotion.sad => _Mouth.frown,
        Emotion.crying => _Mouth.frown,
        Emotion.angry => _Mouth.teeth,
        Emotion.sleepy => _Mouth.o,
        Emotion.dizzy => _Mouth.wavy,
      };

  void _doodleFeatures(Canvas c, Paint ink, Color pink, {required bool orb}) {
    final e = f.emotion;
    final (le, re) = _eyesFor(e);
    final eyeR = orb ? 0.14 : 0.1;
    final ex = orb ? 0.3 : 0.4;
    const ey = -0.1;
    final stroke = orb ? 0.05 : 0.035;
    final eyeScale = 1 + f.listenLevel * 0.25 + (e == Emotion.surprised ? 0.1 : 0);

    Paint strokeOf(Paint p, [double? w]) => Paint()
      ..color = p.color
      ..maskFilter = p.maskFilter
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w ?? stroke;

    // Blush.
    if (const {Emotion.happy, Emotion.love, Emotion.laugh, Emotion.playful, Emotion.wink}
        .contains(e)) {
      final blush = Paint()
        ..color = pink.withValues(alpha: orb ? 0.25 : 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03);
      for (final s in [-1.0, 1.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(s * (ex + 0.12), 0.1), width: 0.2, height: 0.09), blush);
      }
    }

    // Eyebrows.
    final brow = strokeOf(ink, stroke * 0.85);
    switch (e) {
      case Emotion.angry:
        for (final s in [-1.0, 1.0]) {
          c.drawLine(Offset(s * (ex + 0.17), ey - 0.27), Offset(s * (ex - 0.1), ey - 0.15), brow);
        }
      case Emotion.sad || Emotion.crying:
        for (final s in [-1.0, 1.0]) {
          c.drawLine(Offset(s * (ex + 0.16), ey - 0.15), Offset(s * (ex - 0.08), ey - 0.25), brow);
        }
      case Emotion.thinking:
        c.drawLine(Offset(ex - 0.12, ey - 0.28), Offset(ex + 0.14, ey - 0.24), brow);
      case Emotion.surprised:
        for (final s in [-1.0, 1.0]) {
          c.drawArc(Rect.fromCenter(center: Offset(s * ex, ey - 0.2), width: 0.26, height: 0.14),
              math.pi * 1.15, math.pi * 0.7, false, brow);
        }
      default:
        break;
    }

    // Eyes.
    for (final (i, kind) in [le, re].indexed) {
      final side = i == 0 ? -1.0 : 1.0;
      final center = Offset(side * ex, ey);
      _doodleEye(c, center, kind, side, eyeR * eyeScale, ink, strokeOf(ink), orb);
    }

    // Mouth.
    final mouthCenter = Offset(e == Emotion.thinking ? 0.08 : 0, orb ? 0.22 : 0.18);
    if (f.mouthOpen > 0.04 && e != Emotion.dizzy) {
      _openMouth(c, mouthCenter, ink, pink, orb);
    } else {
      _closedMouth(c, _mouthFor(e), mouthCenter, ink, strokeOf(ink), pink, orb);
    }

    // Extras.
    if (e == Emotion.crying || e == Emotion.sad) {
      final fall = (f.time * (e == Emotion.crying ? 0.8 : 0.5)) % 1.0;
      final tear = Paint()..color = const Color(0xFF9ED8F5).withValues(alpha: 1 - fall * 0.6);
      final base = Offset(ex - 0.02, ey + 0.1 + fall * 0.35);
      final path = Path()
        ..moveTo(base.dx, base.dy - 0.09)
        ..quadraticBezierTo(base.dx + 0.07, base.dy, base.dx, base.dy + 0.045)
        ..quadraticBezierTo(base.dx - 0.07, base.dy, base.dx, base.dy - 0.09);
      c.drawPath(path, tear);
      if (e == Emotion.crying) {
        c.drawPath(path.shift(Offset(-2 * ex + 0.04, -0.12 + ((f.time * 0.8 + 0.5) % 1.0) * 0.1)), tear);
      }
    }
    if (e == Emotion.sleepy) _zzz(c, Offset(ex + 0.25, ey - 0.35), strokeOf(ink, stroke * 0.6));
    if (e == Emotion.thinking) {
      for (var i = 0; i < 3; i++) {
        final a = (math.sin(f.time * 4 - i * 0.8) + 1) / 2;
        c.drawCircle(Offset(ex + 0.12 + i * 0.12, ey - 0.42 - i * 0.04), 0.025 + 0.012 * a,
            Paint()..color = ink.color.withValues(alpha: 0.4 + 0.6 * a));
      }
    }
    if (e == Emotion.love) {
      for (var i = 0; i < 2; i++) {
        final p = (f.time * 0.4 + i * 0.5) % 1.0;
        _heart(c, Offset((i == 0 ? -1 : 1) * (ex + 0.3), -0.2 - p * 0.45), 0.07 * (1 - p * 0.4),
            Paint()..color = pink.withValues(alpha: 1 - p));
      }
    }
    if (e == Emotion.angry) {
      final p = Paint()
        ..color = const Color(0xFFE53935).withValues(alpha: orb ? 0.8 : 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.7
        ..strokeCap = StrokeCap.round;
      final o = Offset(ex + 0.26, ey - 0.42);
      for (final a in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
        final d = Offset(math.cos(a + math.pi / 4), math.sin(a + math.pi / 4));
        c.drawArc(Rect.fromCircle(center: o + d * 0.07, radius: 0.05), a + math.pi * 0.75, math.pi / 2, false, p);
      }
    }
    if (e == Emotion.confused) {
      final drop = Paint()..color = const Color(0xFF9ED8F5);
      final b = Offset(-ex - 0.22, ey - 0.25);
      c.drawPath(
        Path()
          ..moveTo(b.dx, b.dy - 0.08)
          ..quadraticBezierTo(b.dx + 0.06, b.dy, b.dx, b.dy + 0.04)
          ..quadraticBezierTo(b.dx - 0.06, b.dy, b.dx, b.dy - 0.08),
        drop,
      );
    }
  }

  void _doodleEye(Canvas c, Offset o, _Eye kind, double side, double r, Paint fill,
      Paint line, bool orb) {
    final blink = f.blink;
    final blinkable = kind == _Eye.dot || kind == _Eye.ring || kind == _Eye.sparkle;
    if (blinkable && blink > 0.75) {
      c.drawLine(o.translate(-r, 0), o.translate(r, 0), line);
      return;
    }
    final sy = blinkable ? (1 - blink).clamp(0.12, 1.0) : 1.0;
    switch (kind) {
      case _Eye.dot:
        c.drawOval(Rect.fromCenter(center: o, width: r * 2, height: r * 2 * sy * (orb ? 1.1 : 1)), fill);
      case _Eye.ring:
        c.drawOval(Rect.fromCenter(center: o, width: r * 2.2, height: r * 2.2 * sy), line);
        c.drawCircle(o.translate(f.lookX * r * 0.3, f.lookY * r * 0.3), r * 0.35, fill);
      case _Eye.sparkle:
        c.drawOval(Rect.fromCenter(center: o, width: r * 2.3, height: r * 2.3 * sy), fill);
        final hi = Paint()..color = orb ? const Color(0xFF07101E) : Colors.white;
        final tw = 1 + 0.2 * math.sin(f.time * 6);
        c.drawCircle(o.translate(-r * 0.35, -r * 0.35 * sy), r * 0.42 * tw, hi);
        c.drawCircle(o.translate(r * 0.4, r * 0.35 * sy), r * 0.2, hi);
      case _Eye.chevron:
        // Left eye '>' and right eye '<' point toward the nose.
        final d = side < 0 ? 1.0 : -1.0;
        c.drawPath(
          Path()
            ..moveTo(o.dx - d * r, o.dy - r * 0.8)
            ..lineTo(o.dx + d * r, o.dy)
            ..lineTo(o.dx - d * r, o.dy + r * 0.8),
          line,
        );
      case _Eye.sleepArc:
        c.drawArc(Rect.fromCenter(center: o.translate(0, -r * 0.4), width: r * 2.2, height: r * 1.4),
            math.pi * 0.1, math.pi * 0.8, false, line);
      case _Eye.happyArc:
        c.drawArc(Rect.fromCenter(center: o.translate(0, r * 0.4), width: r * 2.2, height: r * 1.6),
            math.pi * 1.1, math.pi * 0.8, false, line);
      case _Eye.cross:
        c.drawLine(o.translate(-r, -r), o.translate(r, r), line);
        c.drawLine(o.translate(-r, r), o.translate(r, -r), line);
      case _Eye.spiral:
        final p = Path();
        final rot = f.time * 3 * side;
        for (var t = 0.0; t <= math.pi * 5; t += 0.2) {
          final rr = r * 1.1 * t / (math.pi * 5);
          final pt = o + Offset(math.cos(t + rot), math.sin(t + rot)) * rr;
          t == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        c.drawPath(p, _copy(line)..strokeWidth = line.strokeWidth * 0.7);
    }
  }

  void _closedMouth(Canvas c, _Mouth m, Offset o, Paint fill, Paint line, Color pink, bool orb) {
    final w = orb ? 0.16 : 0.14;
    switch (m) {
      case _Mouth.smile:
        final s = f.emotion == Emotion.neutral ? 0.7 : 1.0;
        c.drawArc(Rect.fromCenter(center: o.translate(0, -0.04), width: w * 2 * s, height: 0.16 * s),
            math.pi * 0.12, math.pi * 0.76, false, line);
      case _Mouth.bigSmile:
        _openMouth(c, o, fill, pink, orb, forced: 0.7);
      case _Mouth.cat:
        for (final s in [-1.0, 1.0]) {
          c.drawArc(Rect.fromCenter(center: o.translate(s * w * 0.45, -0.02), width: w * 0.9, height: 0.12),
              0, math.pi, false, line);
        }
      case _Mouth.frown:
        c.drawArc(Rect.fromCenter(center: o.translate(0, 0.05), width: w * 1.6, height: 0.14),
            math.pi * 1.15, math.pi * 0.7, false, line);
      case _Mouth.flat:
        c.drawLine(o.translate(-w * 0.5, 0), o.translate(w * 0.5, -0.015), line);
      case _Mouth.wavy:
        final p = Path()..moveTo(o.dx - w * 1.2, o.dy);
        for (var i = 1; i <= 8; i++) {
          p.lineTo(o.dx - w * 1.2 + i * w * 0.3, o.dy + (i.isOdd ? -0.04 : 0.02));
        }
        c.drawPath(p, line);
      case _Mouth.tongue:
        c.drawArc(Rect.fromCenter(center: o.translate(0, -0.04), width: w * 2, height: 0.16),
            math.pi * 0.12, math.pi * 0.76, false, line);
        final wag = math.sin(f.time * 5) * 0.015;
        final t = Rect.fromCenter(center: o.translate(wag, 0.09), width: 0.15, height: 0.16);
        c.drawRRect(RRect.fromRectAndCorners(t,
            bottomLeft: const Radius.circular(0.075), bottomRight: const Radius.circular(0.075)),
            Paint()..color = pink);
        c.drawRRect(RRect.fromRectAndCorners(t,
            bottomLeft: const Radius.circular(0.075), bottomRight: const Radius.circular(0.075)),
            _copy(line)..strokeWidth = line.strokeWidth * 0.6);
        c.drawLine(t.topCenter.translate(0, 0.01), t.center.translate(0, 0.03),
            _copy(line)..strokeWidth = line.strokeWidth * 0.5);
      case _Mouth.o:
        final s = f.emotion == Emotion.sleepy ? 0.6 + 0.15 * math.sin(f.time * 1.5) : 1.0;
        c.drawOval(Rect.fromCenter(center: o, width: 0.12 * s, height: 0.14 * s), line);
      case _Mouth.teeth:
        final rect = Rect.fromCenter(center: o, width: w * 2.4, height: 0.2);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(0.1));
        c.drawRRect(rr, Paint()..color = orb ? const Color(0xFF07101E) : Colors.white);
        c.drawRRect(rr, line);
        c.save();
        c.clipRRect(rr);
        final thin = _copy(line)..strokeWidth = line.strokeWidth * 0.6;
        c.drawLine(rect.centerLeft, rect.centerRight, thin);
        for (var i = 1; i < 5; i++) {
          final x = rect.left + rect.width * i / 5;
          c.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), thin);
        }
        c.restore();
      case _Mouth.pout:
        final rect = Rect.fromCenter(center: o, width: 0.2, height: 0.1);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(0.05));
        c.drawRRect(rr, Paint()..color = pink);
        c.drawRRect(rr, _copy(line)..strokeWidth = line.strokeWidth * 0.7);
        c.drawLine(rect.centerLeft.translate(0.04, 0), rect.centerRight.translate(-0.04, 0),
            _copy(line)..strokeWidth = line.strokeWidth * 0.5);
      case _Mouth.beak:
        c.drawPath(
          Path()
            ..moveTo(o.dx - 0.09, o.dy - 0.05)
            ..lineTo(o.dx + 0.09, o.dy - 0.05)
            ..lineTo(o.dx, o.dy + 0.07)
            ..close(),
          Paint()..color = pink,
        );
    }
  }

  void _openMouth(Canvas c, Offset o, Paint fill, Color pink, bool orb, {double? forced}) {
    final open = forced ?? f.mouthOpen;
    final sad = f.emotion == Emotion.sad || f.emotion == Emotion.crying || f.emotion == Emotion.angry;
    final w = (orb ? 0.18 : 0.15) * (1 + 0.25 * f.mouthShape);
    final h = 0.05 + 0.2 * open * (1 - 0.25 * f.mouthShape);
    final curve = sad ? 0.05 : -0.03;
    final path = Path()
      ..moveTo(o.dx - w, o.dy - 0.03)
      ..quadraticBezierTo(o.dx, o.dy - 0.03 + curve, o.dx + w, o.dy - 0.03)
      ..quadraticBezierTo(o.dx + w * 0.95, o.dy + h, o.dx, o.dy + h)
      ..quadraticBezierTo(o.dx - w * 0.95, o.dy + h, o.dx - w, o.dy - 0.03)
      ..close();
    c.drawPath(path, orb ? (_copy(fill)..color = fill.color.withValues(alpha: 0.35)) : fill);
    c.save();
    c.clipPath(path);
    c.drawOval(Rect.fromCenter(center: Offset(o.dx, o.dy + h), width: w * 1.3, height: h * 0.9),
        Paint()..color = orb ? pink.withValues(alpha: 0.7) : pink);
    c.restore();
    if (orb) {
      c.drawPath(
        path,
        _copy(fill)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.035
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _zzz(Canvas c, Offset o, Paint line) {
    for (var i = 0; i < 3; i++) {
      final p = (f.time * 0.35 + i / 3) % 1.0;
      final s = 0.05 + 0.04 * p;
      final at = o + Offset(p * 0.18, -p * 0.3);
      final paint = _copy(line)..color = line.color.withValues(alpha: (1 - p) * line.color.a);
      c.drawPath(
        Path()
          ..moveTo(at.dx - s, at.dy - s)
          ..lineTo(at.dx + s, at.dy - s)
          ..lineTo(at.dx - s, at.dy + s)
          ..lineTo(at.dx + s, at.dy + s),
        paint,
      );
    }
  }
}

void _heart(Canvas c, Offset o, double s, Paint p) {
  c.drawPath(
    Path()
      ..moveTo(o.dx, o.dy + s * 0.9)
      ..cubicTo(o.dx - s * 1.6, o.dy - s * 0.2, o.dx - s * 0.6, o.dy - s * 1.2, o.dx, o.dy - s * 0.35)
      ..cubicTo(o.dx + s * 0.6, o.dy - s * 1.2, o.dx + s * 1.6, o.dy - s * 0.2, o.dx, o.dy + s * 0.9),
    p,
  );
}

// ───────────────────────────── Human ─────────────────────────────

class _HumanFace {
  final FaceFrame f;
  _HumanFace(this.f);

  Color get _skinShade => Color.lerp(f.skin, const Color(0xFF6D3B2A), 0.25)!;
  Color get _browColor => Color.lerp(f.hair, Colors.black, 0.25)!;
  bool get _female => f.gender == AssistantGender.female;
  bool get _male => f.gender == AssistantGender.male;

  void paint(Canvas c) {
    _backHair(c);
    _body(c);
    _ears(c);
    _head(c);
    _cheeks(c);
    _eyes(c);
    _brows(c);
    _nose(c);
    _mouth(c);
    _frontHair(c);
    _extras(c);
  }

  void _body(Canvas c) {
    // Neck.
    final neck = Rect.fromLTRB(-0.17, 0.4, 0.17, 0.95);
    c.drawRect(neck, Paint()..color = _skinShade);
    // Shoulders / top.
    final shirt = Path()
      ..moveTo(-0.95, 1.05)
      ..quadraticBezierTo(-0.9, 0.78, -0.45, 0.74)
      ..quadraticBezierTo(0, 0.95, 0.45, 0.74)
      ..quadraticBezierTo(0.9, 0.78, 0.95, 1.05)
      ..close();
    c.drawPath(
      shirt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [f.accent, Color.lerp(f.accent, Colors.black, 0.35)!],
        ).createShader(const Rect.fromLTRB(-1, 0.7, 1, 1.05)),
    );
    c.drawPath(
      Path()
        ..moveTo(-0.2, 0.76)
        ..quadraticBezierTo(0, 0.93, 0.2, 0.76),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.025
        ..color = Color.lerp(f.accent, Colors.black, 0.4)!,
    );
  }

  Rect get _headRect => Rect.fromCenter(center: const Offset(0, -0.08), width: 1.04, height: 1.3);

  Path get _headPath {
    // Slightly tapered jaw.
    final r = _headRect;
    final jaw = _male ? 0.2 : 0.14;
    return Path()
      ..moveTo(r.left, r.center.dy - 0.05)
      ..cubicTo(r.left, r.top - 0.02, r.right, r.top - 0.02, r.right, r.center.dy - 0.05)
      ..cubicTo(r.right, r.center.dy + 0.3, jaw + 0.08, r.bottom, 0, r.bottom)
      ..cubicTo(-jaw - 0.08, r.bottom, r.left, r.center.dy + 0.3, r.left, r.center.dy - 0.05)
      ..close();
  }

  void _head(Canvas c) {
    c.drawPath(
      _headPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.3),
          radius: 0.9,
          colors: [Color.lerp(f.skin, Colors.white, 0.15)!, f.skin, _skinShade],
          stops: const [0, 0.6, 1],
        ).createShader(_headRect),
    );
  }

  void _ears(Canvas c) {
    for (final s in [-1.0, 1.0]) {
      final r = Rect.fromCenter(center: Offset(s * 0.52, -0.02), width: 0.14, height: 0.24);
      c.drawOval(r, Paint()..color = f.skin);
      c.drawOval(r.deflate(0.035), Paint()..color = _skinShade.withValues(alpha: 0.5));
      if (_female) {
        c.drawCircle(Offset(s * 0.53, 0.1), 0.025, Paint()..color = const Color(0xFFFFD54F));
      }
    }
  }

  void _backHair(Canvas c) {
    final paint = Paint()..color = Color.lerp(f.hair, Colors.black, 0.15)!;
    switch (f.gender) {
      case AssistantGender.female:
        final sway = math.sin(f.time * 1.3) * 0.02;
        c.drawPath(
          Path()
            ..moveTo(-0.62, -0.2)
            ..cubicTo(-0.75, -1.0, 0.75, -1.0, 0.62, -0.2)
            ..cubicTo(0.7, 0.3, 0.72 + sway, 0.6, 0.66 + sway, 0.85)
            ..quadraticBezierTo(0.4, 0.95, 0.3, 0.6)
            ..lineTo(-0.3, 0.6)
            ..quadraticBezierTo(-0.4, 0.95, -0.66 + sway, 0.85)
            ..cubicTo(-0.72 + sway, 0.6, -0.7, 0.3, -0.62, -0.2)
            ..close(),
          paint,
        );
      case AssistantGender.neutral:
        c.drawPath(
          Path()
            ..moveTo(-0.6, -0.2)
            ..cubicTo(-0.72, -1.0, 0.72, -1.0, 0.6, -0.2)
            ..quadraticBezierTo(0.66, 0.2, 0.6, 0.35)
            ..lineTo(-0.6, 0.35)
            ..quadraticBezierTo(-0.66, 0.2, -0.6, -0.2)
            ..close(),
          paint,
        );
      case AssistantGender.male:
        break;
    }
  }

  void _frontHair(Canvas c) {
    final hairRect = const Rect.fromLTRB(-0.6, -0.9, 0.6, -0.2);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(f.hair, Colors.white, 0.18)!, f.hair],
      ).createShader(hairRect);
    final path = switch (f.gender) {
      AssistantGender.male => Path()
        ..moveTo(-0.54, -0.05)
        ..cubicTo(-0.62, -0.75, -0.2, -0.9, 0.08, -0.84)
        ..cubicTo(0.45, -0.82, 0.62, -0.6, 0.54, -0.05)
        ..lineTo(0.49, -0.3)
        ..quadraticBezierTo(0.35, -0.52, 0.0, -0.5)
        ..quadraticBezierTo(-0.25, -0.62, -0.42, -0.45)
        ..lineTo(-0.49, -0.3)
        ..close(),
      AssistantGender.female => Path()
        ..moveTo(-0.53, 0.05)
        ..cubicTo(-0.62, -0.7, -0.25, -0.9, 0.05, -0.85)
        ..cubicTo(0.45, -0.82, 0.64, -0.55, 0.53, 0.05)
        ..quadraticBezierTo(0.48, -0.35, 0.18, -0.5)
        ..quadraticBezierTo(-0.1, -0.35, -0.42, -0.36)
        ..quadraticBezierTo(-0.5, -0.2, -0.53, 0.05)
        ..close(),
      AssistantGender.neutral => Path()
        ..moveTo(-0.54, 0.0)
        ..cubicTo(-0.62, -0.75, -0.25, -0.9, 0.0, -0.86)
        ..cubicTo(0.25, -0.9, 0.62, -0.75, 0.54, 0.0)
        ..lineTo(0.46, -0.36)
        ..quadraticBezierTo(0.25, -0.4, 0.0, -0.36)
        ..quadraticBezierTo(-0.25, -0.4, -0.46, -0.36)
        ..close(),
    };
    c.drawPath(path, paint);
    // Shine.
    c.drawPath(
      Path()
        ..moveTo(-0.3, -0.72)
        ..quadraticBezierTo(-0.05, -0.8, 0.2, -0.74),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.035
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _cheeks(Canvas c) {
    final e = f.emotion;
    final strength = switch (e) {
      Emotion.love || Emotion.laugh => 0.45,
      Emotion.happy || Emotion.playful || Emotion.wink => 0.3,
      Emotion.angry => 0.25,
      _ => 0.12,
    };
    final paint = Paint()
      ..color = const Color(0xFFFF6F7D).withValues(alpha: strength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.05);
    for (final s in [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(s * 0.3, 0.14), width: 0.2, height: 0.1), paint);
    }
    if (_male) {
      // Light stubble shadow along the jaw.
      c.save();
      c.clipPath(_headPath);
      c.drawOval(
        Rect.fromCenter(center: const Offset(0, 0.48), width: 0.75, height: 0.42),
        Paint()
          ..color = f.hair.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04),
      );
      c.restore();
    }
  }

  void _eyes(Canvas c) {
    final e = f.emotion;
    for (final side in [-1.0, 1.0]) {
      final o = Offset(side * 0.22, -0.06);
      final closedArc = e == Emotion.laugh ||
          e == Emotion.crying ||
          ((e == Emotion.wink || e == Emotion.playful) && side > 0);
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.025
        ..color = const Color(0xFF2B1A14);
      if (closedArc) {
        // ^ shaped happy-closed eye, or ∩ for crying.
        c.drawArc(Rect.fromCenter(center: o.translate(0, 0.03), width: 0.2, height: 0.12),
            math.pi * 1.1, math.pi * 0.8, false, line);
        continue;
      }
      if (e == Emotion.dizzy) {
        line.strokeWidth = 0.022;
        c.drawLine(o.translate(-0.07, -0.05), o.translate(0.07, 0.05), line);
        c.drawLine(o.translate(-0.07, 0.05), o.translate(0.07, -0.05), line);
        continue;
      }

      final wide = e == Emotion.surprised ? 1.25 : 1.0 + f.listenLevel * 0.15;
      final sclera = Rect.fromCenter(center: o, width: 0.22, height: 0.13 * wide);
      final eyePath = Path()
        ..moveTo(sclera.left, o.dy)
        ..quadraticBezierTo(o.dx, sclera.top - 0.04 * wide, sclera.right, o.dy)
        ..quadraticBezierTo(o.dx, sclera.bottom + 0.03, sclera.left, o.dy)
        ..close();
      c.drawPath(eyePath, Paint()..color = const Color(0xFFFDFDFD));
      c.save();
      c.clipPath(eyePath);
      final irisC = o + Offset(f.lookX * 0.045, f.lookY * 0.02 + (e == Emotion.thinking ? -0.02 : 0));
      final irisR = 0.055;
      c.drawCircle(
        irisC,
        irisR,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.lerp(f.eye, Colors.white, 0.25)!,
            f.eye,
            Color.lerp(f.eye, Colors.black, 0.5)!,
          ], stops: const [0, 0.7, 1])
              .createShader(Rect.fromCircle(center: irisC, radius: irisR)),
      );
      if (e == Emotion.confused) {
        final sp = Path();
        for (var t = 0.0; t <= math.pi * 4; t += 0.25) {
          final rr = irisR * 0.9 * t / (math.pi * 4);
          final pt = irisC + Offset(math.cos(t + f.time * 4 * side), math.sin(t + f.time * 4 * side)) * rr;
          t == 0 ? sp.moveTo(pt.dx, pt.dy) : sp.lineTo(pt.dx, pt.dy);
        }
        c.drawPath(sp, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012
          ..color = Colors.black);
      } else {
        final pupil = e == Emotion.love ? 0.034 : (e == Emotion.surprised ? 0.018 : 0.026);
        if (e == Emotion.love) {
          _heart(c, irisC, 0.035, Paint()..color = const Color(0xFFE53958));
        } else {
          c.drawCircle(irisC, pupil, Paint()..color = Colors.black);
        }
      }
      c.drawCircle(irisC.translate(-0.018, -0.02), 0.014, Paint()..color = Colors.white);
      c.drawCircle(irisC.translate(0.02, 0.016), 0.007, Paint()..color = Colors.white70);

      // Eyelids: blink plus emotion-specific lid positions.
      var upper = f.blink;
      var lower = 0.0;
      switch (e) {
        case Emotion.sleepy:
          upper = math.max(upper, 0.55 + 0.1 * math.sin(f.time * 1.2));
        case Emotion.happy || Emotion.love || Emotion.wink || Emotion.playful:
          lower = 0.3;
        case Emotion.angry:
          upper = math.max(upper, 0.3);
        case Emotion.sad:
          upper = math.max(upper, 0.25);
        case Emotion.thinking:
          upper = math.max(upper, side > 0 ? 0.3 : 0.15);
        default:
          break;
      }
      final lid = Paint()..color = f.skin;
      final h = sclera.height + 0.06;
      if (upper > 0) {
        final top = sclera.top - 0.04;
        final bottom = top + h * upper;
        final tilt = e == Emotion.angry ? 0.05 * side * -1 : (e == Emotion.sad ? -0.04 * side * -1 : 0.0);
        c.drawPath(
          Path()
            ..moveTo(sclera.left - 0.02, top)
            ..lineTo(sclera.right + 0.02, top)
            ..lineTo(sclera.right + 0.02, bottom - tilt)
            ..lineTo(sclera.left - 0.02, bottom + tilt)
            ..close(),
          lid,
        );
      }
      if (lower > 0) {
        c.drawOval(
          Rect.fromCenter(center: Offset(o.dx, sclera.bottom + 0.05 - lower * 0.08), width: 0.3, height: 0.12),
          lid,
        );
      }
      c.restore();

      // Upper lid line and lashes.
      final lidY = sclera.top - 0.04 + (sclera.height + 0.06) * math.max(f.blink, 0) * 0.98;
      if (f.blink > 0.85) {
        c.drawArc(Rect.fromCenter(center: o.translate(0, -0.01), width: 0.22, height: 0.06),
            0.1, math.pi - 0.2, false, line);
      } else {
        c.drawPath(
          Path()
            ..moveTo(sclera.left, o.dy)
            ..quadraticBezierTo(o.dx, math.min(lidY, sclera.top - 0.04 * wide) , sclera.right, o.dy),
          line..strokeWidth = _female ? 0.03 : 0.02,
        );
      }
      if (_female && f.blink < 0.85) {
        final lash = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.014
          ..color = const Color(0xFF2B1A14);
        final outer = Offset(side * 0.33, -0.065);
        c.drawLine(outer, outer.translate(side * 0.04, -0.03), lash);
        c.drawLine(outer.translate(-side * 0.03, -0.025), outer.translate(side * 0.01, -0.06), lash);
      }
    }
  }

  void _brows(Canvas c) {
    final e = f.emotion;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _male ? 0.04 : (_female ? 0.022 : 0.03)
      ..color = _browColor;
    for (final side in [-1.0, 1.0]) {
      // inner and outer y offsets relative to rest position.
      var (inner, outer, lift) = switch (e) {
        Emotion.angry => (0.06, -0.03, 0.0),
        Emotion.sad || Emotion.crying => (-0.05, 0.03, 0.0),
        Emotion.surprised => (0.0, 0.0, -0.07),
        Emotion.confused => side < 0 ? (0.03, 0.0, 0.0) : (0.0, 0.0, -0.05),
        Emotion.thinking => side > 0 ? (0.0, 0.0, -0.05) : (0.02, 0.0, 0.0),
        Emotion.love || Emotion.happy || Emotion.laugh => (0.0, 0.0, -0.02),
        _ => (0.0, 0.0, 0.0),
      };
      lift -= f.listenLevel * 0.03;
      final baseY = -0.22 + lift;
      final innerPt = Offset(side * 0.11, baseY + inner);
      final outerPt = Offset(side * 0.33, baseY + 0.02 + outer);
      c.drawPath(
        Path()
          ..moveTo(innerPt.dx, innerPt.dy)
          ..quadraticBezierTo(side * 0.24, baseY - 0.045 + (inner + outer) / 2, outerPt.dx, outerPt.dy),
        paint,
      );
    }
  }

  void _nose(Canvas c) {
    c.drawPath(
      Path()
        ..moveTo(0.0, 0.0)
        ..quadraticBezierTo(0.04, 0.12, 0.0, 0.16)
        ..quadraticBezierTo(-0.03, 0.17, -0.05, 0.155),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.018
        ..color = _skinShade,
    );
  }

  Color get _lipColor => _female
      ? const Color(0xFFD45D6C)
      : Color.lerp(f.skin, const Color(0xFFB0544D), 0.45)!;

  void _mouth(Canvas c) {
    final e = f.emotion;
    const o = Offset(0, 0.3);
    var open = f.mouthOpen;
    if (e == Emotion.laugh) open = math.max(open, 0.55);
    if (e == Emotion.surprised) open = math.max(open, 0.4);

    final lip = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.022
      ..color = Color.lerp(_lipColor, Colors.black, 0.2)!;

    // Smile curvature: positive = corners up.
    final curve = switch (e) {
      Emotion.happy || Emotion.love || Emotion.laugh || Emotion.playful || Emotion.wink => 0.05,
      Emotion.sad || Emotion.crying || Emotion.angry => -0.04,
      Emotion.surprised || Emotion.sleepy => 0.0,
      _ => 0.02,
    };

    if (open < 0.05) {
      final w = switch (e) {
        Emotion.surprised || Emotion.sleepy => 0.06,
        Emotion.confused => 0.09,
        _ => 0.14,
      };
      if (e == Emotion.dizzy) {
        final p = Path()..moveTo(o.dx - 0.13, o.dy);
        for (var i = 1; i <= 6; i++) {
          p.lineTo(o.dx - 0.13 + i * 0.26 / 6, o.dy + (i.isOdd ? -0.025 : 0.01));
        }
        c.drawPath(p, lip);
        return;
      }
      // Lips.
      c.drawPath(
        Path()
          ..moveTo(o.dx - w, o.dy - curve)
          ..quadraticBezierTo(o.dx - w * 0.4, o.dy - 0.035, o.dx, o.dy - 0.02)
          ..quadraticBezierTo(o.dx + w * 0.4, o.dy - 0.035, o.dx + w, o.dy - curve)
          ..quadraticBezierTo(o.dx, o.dy + 0.06 + curve * 0.5, o.dx - w, o.dy - curve)
          ..close(),
        Paint()..color = _lipColor.withValues(alpha: _female ? 1 : 0.7),
      );
      c.drawPath(
        Path()
          ..moveTo(o.dx - w, o.dy - curve)
          ..quadraticBezierTo(o.dx, o.dy + curve * 1.4, o.dx + w, o.dy - curve),
        lip,
      );
      if (e == Emotion.playful) {
        final wag = math.sin(f.time * 5) * 0.01;
        c.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromCenter(center: o.translate(0.02 + wag, 0.05), width: 0.09, height: 0.09),
            bottomLeft: const Radius.circular(0.045),
            bottomRight: const Radius.circular(0.045),
          ),
          Paint()..color = const Color(0xFFF07C8A),
        );
      }
      return;
    }

    // Talking / open mouth.
    final shape = f.mouthShape; // -1 round "o" … 1 wide "ee"
    final w = 0.12 * (1 + 0.25 * shape) + (e == Emotion.laugh ? 0.03 : 0);
    final h = 0.03 + 0.15 * open * (1 - 0.3 * shape);
    final top = o.dy - 0.02;
    final mouth = Path()
      ..moveTo(o.dx - w, top - curve)
      ..quadraticBezierTo(o.dx, top - 0.02, o.dx + w, top - curve)
      ..quadraticBezierTo(o.dx + w * 0.9, top + h + curve * 0.3, o.dx, top + h)
      ..quadraticBezierTo(o.dx - w * 0.9, top + h + curve * 0.3, o.dx - w, top - curve)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFF4A1414));
    c.save();
    c.clipPath(mouth);
    // Upper teeth.
    c.drawRect(Rect.fromLTRB(o.dx - w, top - 0.05, o.dx + w, top + 0.025 + h * 0.08),
        Paint()..color = const Color(0xFFF7F3EE));
    // Tongue.
    c.drawOval(Rect.fromCenter(center: Offset(o.dx, top + h), width: w * 1.3, height: h * 0.9),
        Paint()..color = const Color(0xFFE0707C));
    c.restore();
    c.drawPath(mouth, lip..color = _lipColor..strokeWidth = _female ? 0.03 : 0.022);
  }

  void _extras(Canvas c) {
    final e = f.emotion;
    if (e == Emotion.crying || e == Emotion.sad) {
      final fall = (f.time * 0.6) % 1.0;
      final tear = Paint()..color = const Color(0xFF8FD3F7).withValues(alpha: 0.9 - fall * 0.5);
      for (final side in e == Emotion.crying ? [-1.0, 1.0] : [1.0]) {
        final b = Offset(side * 0.25, 0.02 + fall * 0.3);
        c.drawPath(
          Path()
            ..moveTo(b.dx, b.dy - 0.06)
            ..quadraticBezierTo(b.dx + 0.04, b.dy, b.dx, b.dy + 0.03)
            ..quadraticBezierTo(b.dx - 0.04, b.dy, b.dx, b.dy - 0.06),
          tear,
        );
      }
    }
    if (e == Emotion.confused || e == Emotion.dizzy) {
      final b = const Offset(0.44, -0.42);
      c.drawPath(
        Path()
          ..moveTo(b.dx, b.dy - 0.08)
          ..quadraticBezierTo(b.dx + 0.05, b.dy, b.dx, b.dy + 0.035)
          ..quadraticBezierTo(b.dx - 0.05, b.dy, b.dx, b.dy - 0.08),
        Paint()..color = const Color(0xFF8FD3F7),
      );
    }
    if (e == Emotion.love) {
      for (var i = 0; i < 3; i++) {
        final p = (f.time * 0.35 + i / 3) % 1.0;
        _heart(c, Offset(-0.7 + i * 0.7, -0.6 - p * 0.35), 0.06, Paint()..color = const Color(0xFFFF5C8A).withValues(alpha: 1 - p));
      }
    }
  }
}

Paint _copy(Paint p) => Paint()
  ..color = p.color
  ..style = p.style
  ..strokeWidth = p.strokeWidth
  ..strokeCap = p.strokeCap
  ..strokeJoin = p.strokeJoin
  ..maskFilter = p.maskFilter;
