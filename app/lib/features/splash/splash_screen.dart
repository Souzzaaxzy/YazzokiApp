import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/app_state_scope.dart';

/// Splash total duration in ms — the animation HARD cap (spec: max 9s).
const int splashDurationMs = 8500;

/// Yazzoki splash screen — "Yuki" (snow) composition.
///
/// Fully native (CustomPaint + one AnimationController, no video/deps). The
/// scene is a quiet Japanese winter, built in true LAYERS:
///
///   night sky gradient + moon glow + vignette
///   → far snow (small, slow) / drifting kana (Japanese characters)
///   → the emblem: the brush strokes are WRITTEN top-to-bottom
///   → the red hanko seal is stamped last, with a small pop
///   → sakura petals + near snow (large, fast) in the foreground
///
/// No binary rain, no HUD brackets, no glitch: the motifs are snowflakes,
/// kana and petals. Everything stays GPU-friendly (bounded counts, one
/// repaint boundary).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;
  bool _restoreDone = false;
  bool _restored = false;
  bool _ready = false;
  bool _restoreStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: splashDurationMs),
    )..forward();
    // Even if the restore hangs (offline timeout), the animation reaching
    // its end forces the navigation — the user is never stuck.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _maybeNavigate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppStateScope must be reached here (never in initState). One shot.
    if (!_restoreStarted) {
      _restoreStarted = true;
      _restoreAndNavigate();
    }
  }

  Future<void> _restoreAndNavigate() async {
    if (_navigated) return;
    final state = AppStateScope.of(context);
    final authenticated = await state.restoreSession();
    if (!mounted) return;
    _restored = authenticated;
    _restoreDone = true;
    _maybeNavigate();
  }

  void _maybeNavigate() {
    if (_navigated || !mounted) return;
    if (!_restoreDone) return;
    final timeUp = _controller.status == AnimationStatus.completed;
    if (!timeUp && !_ready) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(
      _restored ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The mark is complete (strokes written + seal stamped); navigation can
  /// then fire as soon as the session restore finishes.
  void _onSceneReady() {
    if (_ready) return;
    setState(() => _ready = true);
    _maybeNavigate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.absoluteBlack,
      body: _YazzokiSplashScene(
        animation: _controller,
        onReady: _onSceneReady,
      ),
    );
  }
}

/// Scene host: owns the persistent snow/kana/petal data and steps it on
/// every animation tick (deterministic seed → stable tests).
class _YazzokiSplashScene extends StatefulWidget {
  const _YazzokiSplashScene({required this.animation, required this.onReady});

  final Animation<double> animation;
  final VoidCallback onReady;

  @override
  State<_YazzokiSplashScene> createState() => _YazzokiSplashSceneState();
}

class _YazzokiSplashSceneState extends State<_YazzokiSplashScene> {
  late final math.Random _rng;
  late final List<_Snowflake> _farSnow;
  late final List<_Snowflake> _nearSnow;
  late final List<_KanaDrop> _kana;
  late final List<_Petal> _petals;
  bool _readySent = false;
  ui.Image? _logo;
  ui.Image? _seal;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(42);
    _farSnow = List.generate(46, (_) => _Snowflake.far(_rng));
    _nearSnow = List.generate(22, (_) => _Snowflake.near(_rng));
    _kana = List.generate(16, (_) => _KanaDrop(rng: _rng));
    _petals = List.generate(12, (_) => _Petal(rng: _rng));
    widget.animation.addListener(_onTick);
    _loadLogo();
  }

  /// Loads the Yazzoki emblem once. If decoding fails (or is still pending
  /// in a test environment) the painter falls back to the drawn wordmark.
  ///
  /// The emblem ships as TWO aligned layers so the splash can reveal them in
  /// sequence: the brush strokes (the Japanese characters) first, then the
  /// red hanko seal — exactly the order the brand mark is "written".
  Future<void> _loadLogo() async {
    final strokes = await _decode('assets/brand/logo_strokes.png');
    final seal = await _decode('assets/brand/logo_seal.png');
    if (!mounted) return;
    setState(() {
      _logo = strokes;
      _seal = seal;
    });
  }

  Future<ui.Image?> _decode(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(data.buffer.asUint8List(), completer.complete);
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant _YazzokiSplashScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_onTick);
      widget.animation.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    // The scene is "ready" only once the emblem is fully written AND the red
    // seal has been stamped — navigation then fires as soon as the session
    // restore finishes, so the user always sees the complete mark.
    if (!_readySent && widget.animation.value >= 0.72) {
      _readySent = true;
      widget.onReady();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _YazzokiSplashPainter(
          progress: widget.animation.value,
          farSnow: _farSnow,
          nearSnow: _nearSnow,
          kana: _kana,
          petals: _petals,
          logo: _logo,
          seal: _seal,
        ),
        size: Size.infinite,
      ),
    );
  }
}

// ── Sim state objects (persistent, mutated in place) ─────────

/// A drifting snowflake. `arms` is 6 for the drawn star flakes; the smallest
/// ones are rendered as soft dots (cheaper, and reads as depth).
class _Snowflake {
  _Snowflake._({
    required this.x,
    required this.y,
    required this.size,
    required this.fallSpeed,
    required this.swayAmp,
    required this.swayPhase,
    required this.swaySpeed,
    required this.opacity,
    required this.arms,
  });

  factory _Snowflake.far(math.Random rng) => _Snowflake._(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 0.8 + rng.nextDouble() * 1.8,
        fallSpeed: 0.012 + rng.nextDouble() * 0.020,
        swayAmp: 0.004 + rng.nextDouble() * 0.012,
        swayPhase: rng.nextDouble() * math.pi * 2,
        swaySpeed: 0.4 + rng.nextDouble() * 0.9,
        opacity: 0.18 + rng.nextDouble() * 0.35,
        arms: 0,
      );

  factory _Snowflake.near(math.Random rng) => _Snowflake._(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 4.5 + rng.nextDouble() * 6.0,
        fallSpeed: 0.035 + rng.nextDouble() * 0.055,
        swayAmp: 0.010 + rng.nextDouble() * 0.026,
        swayPhase: rng.nextDouble() * math.pi * 2,
        swaySpeed: 0.5 + rng.nextDouble() * 1.2,
        opacity: 0.5 + rng.nextDouble() * 0.45,
        arms: 6,
      );

  final double x;
  double y;
  final double size;
  final double fallSpeed;
  final double swayAmp;
  final double swayPhase;
  final double swaySpeed;
  final double opacity;

  /// 0 → draw a soft dot; 6 → draw a six-armed flake.
  final int arms;

  void tick(double dt) {
    y += fallSpeed * dt;
    if (y > 1.02) y -= 1.04;
  }

  /// Horizontal sway offset (-1..1) at global time [t].
  double sway(double t) => math.sin(t * swaySpeed * math.pi * 2 + swayPhase);
}

/// A column of falling Japanese characters — the "kana rain" that replaces
/// the old binary rain. Characters drift down slowly with a soft fade.
class _KanaDrop {
  _KanaDrop({required math.Random rng})
      : x = 0.04 + rng.nextDouble() * 0.92,
        y = rng.nextDouble(),
        size = 12 + rng.nextDouble() * 16,
        speed = 0.010 + rng.nextDouble() * 0.018,
        opacity = 0.10 + rng.nextDouble() * 0.18,
        chars = _pick(rng, 2 + rng.nextInt(3));

  static String _pick(math.Random rng, int n) {
    final out = StringBuffer();
    for (var i = 0; i < n; i++) {
      out.write(_kanaPool[rng.nextInt(_kanaPool.length)]);
    }
    return out.toString();
  }

  final double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final String chars;

  void tick(double dt) {
    y += speed * dt;
    if (y > 1.05) y -= 1.1;
  }
}

/// A sakura petal drifting diagonally in the foreground.
class _Petal {
  _Petal({required math.Random rng})
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        size = 5 + rng.nextDouble() * 7,
        fallSpeed = 0.020 + rng.nextDouble() * 0.035,
        driftX = (rng.nextDouble() - 0.3) * 0.02,
        spin = (rng.nextDouble() - 0.5) * 3.2,
        phase = rng.nextDouble() * math.pi * 2,
        opacity = 0.35 + rng.nextDouble() * 0.4;

  final double x;
  double y;
  final double size;
  final double fallSpeed;
  final double driftX;
  final double spin;
  final double phase;
  final double opacity;

  void tick(double dt) {
    y += fallSpeed * dt;
    if (y > 1.05) y -= 1.1;
  }
}

/// Japanese characters used by the kana rain (hiragana, katakana + a few
/// kanji evoking winter/Japan).
const List<String> _kanaPool = [
  'ゆ', 'き', 'ふ', 'ゆ', 'は', 'な', 'さ', 'く', 'ら', 'つ', 'き', 'か',
  'ぜ', 'と', 'り', 'い', 'み', 'ず', 'う', 'み', 'そ', 'ら', 'こ', 'と',
  'ヤ', 'マ', 'ト', 'カ', 'ワ', 'ユ', 'キ',
  '雪', '風', '花', '月', '夜', '桜', '山', '川', '空', '星', '冬', '白',
];

/// Paints the full layered scene. Order defines depth:
/// sky → moon → far snow → kana → emblem (strokes then seal) → petals →
/// near snow → vignette.
class _YazzokiSplashPainter extends CustomPainter {
  _YazzokiSplashPainter({
    required this.progress,
    required this.farSnow,
    required this.nearSnow,
    required this.kana,
    required this.petals,
    this.logo,
    this.seal,
  });

  final double progress;
  final List<_Snowflake> farSnow;
  final List<_Snowflake> nearSnow;
  final List<_KanaDrop> kana;
  final List<_Petal> petals;
  final ui.Image? logo;
  final ui.Image? seal;

  static const _kStep = 1 / 60;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in farSnow) {
      s.tick(_kStep);
    }
    for (final s in nearSnow) {
      s.tick(_kStep);
    }
    for (final k in kana) {
      k.tick(_kStep);
    }
    for (final p in petals) {
      p.tick(_kStep);
    }

    final t = progress;
    _paintSky(canvas, size, t);
    _paintMoon(canvas, size, t);
    _paintSnow(canvas, size, t, farSnow);
    _paintKana(canvas, size, t);
    _paintLogo(canvas, size, t);
    _paintPetals(canvas, size, t);
    _paintSnow(canvas, size, t, nearSnow);
    _paintVignette(canvas, size);
  }

  // ── night sky ─────────────────────────────────────────────
  void _paintSky(Canvas canvas, Size size, double t) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A0D12), Color(0xFF000000), Color(0xFF07080A)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);
  }

  // ── soft moon glow behind the mark ────────────────────────
  void _paintMoon(Canvas canvas, Size size, double t) {
    final appear = _fade(t, 0.02, 0.4);
    if (appear <= 0.01) return;
    final center = Offset(size.width * 0.5, size.height * 0.40);
    final radius = size.shortestSide * 0.42;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFCFE0F2).withValues(alpha: 0.16 * appear),
          AppColors.electricBlue.withValues(alpha: 0.06 * appear),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);
  }

  // ── snow ──────────────────────────────────────────────────
  void _paintSnow(
    Canvas canvas,
    Size size,
    double t,
    List<_Snowflake> flakes,
  ) {
    final world = _fade(t, 0.05, 0.5);
    if (world <= 0.01) return;
    for (final f in flakes) {
      final x = f.x * size.width + f.sway(t) * size.width * f.swayAmp * 12;
      final y = f.y * size.height;
      final alpha = f.opacity * world;
      if (alpha <= 0.02) continue;

      if (f.arms == 0) {
        // Soft dot (far layer).
        canvas.drawCircle(
          Offset(x, y),
          f.size,
          Paint()
            ..color = const Color(0xFFF2F6FA).withValues(alpha: alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, f.size * 0.6),
        );
      } else {
        _drawFlake(canvas, Offset(x, y), f.size, alpha);
      }
    }
  }

  /// A six-armed snowflake with small side branches.
  void _drawFlake(Canvas canvas, Offset c, double r, double alpha) {
    final paint = Paint()
      ..color = const Color(0xFFF4F8FC).withValues(alpha: alpha)
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    final branch = Paint()
      ..color = const Color(0xFFEAF2FA).withValues(alpha: alpha * 0.85)
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final tip = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.drawLine(c, tip, paint);
      final bx = c.dx + math.cos(a) * r * 0.6;
      final by = c.dy + math.sin(a) * r * 0.6;
      for (final d in [a - 0.6, a + 0.6]) {
        canvas.drawLine(
          Offset(bx, by),
          Offset(bx + math.cos(d) * r * 0.34, by + math.sin(d) * r * 0.34),
          branch,
        );
      }
    }
  }

  // ── falling kana ──────────────────────────────────────────
  void _paintKana(Canvas canvas, Size size, double t) {
    final world = _fade(t, 0.08, 0.6);
    if (world <= 0.01) return;
    for (final k in kana) {
      final alpha = k.opacity * world;
      if (alpha <= 0.02) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: k.chars,
          style: TextStyle(
            fontFamily: 'ZenOldMincho',
            fontSize: k.size,
            height: 1.25,
            color: const Color(0xFFDCE8F4).withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(k.x * size.width - tp.width / 2, k.y * size.height - tp.height),
      );
    }
  }

  // ── logo (strokes written top→bottom, then the seal) ──────
  void _paintLogo(Canvas canvas, Size size, double t) {
    final appear = _easeOutBack(_fade(t, 0.12, 0.5));
    if (appear <= 0.004) return;

    final image = logo;
    final sealImage = seal;
    final targetH = size.height * 0.32;
    final center = Offset(size.width / 2, size.height * 0.46);

    if (image != null) {
      final targetW = targetH * image.width / image.height;
      final dst = Rect.fromCenter(
        center: center,
        width: targetW,
        height: targetH,
      );

      // Soft cold halo behind the emblem.
      final halo = Paint()
        ..color = const Color(0xFFCFE0F2).withValues(alpha: 0.14 * appear)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(dst.inflate(14), const Radius.circular(24)),
        halo,
      );

      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // The characters are WRITTEN from top to bottom: reveal the strokes
      // through a clip whose bottom edge travels down the emblem.
      final write = Curves.easeInOut.transform(_fade(t, 0.12, 0.52));
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          dst.left,
          dst.top,
          dst.right,
          dst.top + dst.height * write,
        ),
      );
      canvas.drawImageRect(
        image,
        src,
        dst,
        Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.white.withValues(alpha: appear),
            BlendMode.modulate,
          ),
      );
      // A bright edge rides the writing front so the reveal reads as ink.
      if (write > 0.01 && write < 0.995) {
        final edgeY = dst.top + dst.height * write;
        canvas.drawLine(
          Offset(dst.left, edgeY),
          Offset(dst.right, edgeY),
          Paint()
            ..color = const Color(0xFFDCE8F4).withValues(alpha: 0.7 * appear)
            ..strokeWidth = 2
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      canvas.restore();

      // The red hanko seal is stamped LAST with a small pop. It ships as a
      // full-canvas layer aligned with the strokes, so it is drawn into the
      // SAME dst rect; the pop scales about the seal's own centre.
      if (sealImage != null) {
        final stamp = _easeOutBack(_fade(t, 0.5, 0.66));
        if (stamp > 0.004) {
          final sealSrc = Rect.fromLTWH(
            0,
            0,
            sealImage.width.toDouble(),
            sealImage.height.toDouble(),
          );
          final anchor = Offset(
            dst.left + dst.width * 0.123,
            dst.top + dst.height * 0.880,
          );
          final scale = 0.85 + 0.15 * stamp;
          canvas.save();
          canvas.translate(anchor.dx, anchor.dy);
          canvas.scale(scale);
          canvas.translate(-anchor.dx, -anchor.dy);
          canvas.drawImageRect(
            sealImage,
            sealSrc,
            dst,
            Paint()
              ..colorFilter = ColorFilter.mode(
                Colors.white.withValues(alpha: stamp),
                BlendMode.modulate,
              ),
          );
          canvas.restore();
        }
      }
      return;
    }

    // Fallback: drawn mincho wordmark (never a Text widget).
    final tp = TextPainter(
      text: TextSpan(
        text: 'Yazzoki',
        style: TextStyle(
          fontFamily: 'ZenOldMincho',
          fontSize: 54,
          fontWeight: FontWeight.w700,
          letterSpacing: 6,
          color: Colors.white.withValues(alpha: appear),
          shadows: const [
            Shadow(color: Color(0xFFCFE0F2), blurRadius: 26),
            Shadow(color: Color(0xFF8FBCE4), blurRadius: 12),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height * 0.46 - tp.height / 2),
    );
  }

  // ── sakura petals (foreground) ────────────────────────────
  void _paintPetals(Canvas canvas, Size size, double t) {
    final world = _fade(t, 0.25, 0.7);
    if (world <= 0.01) return;
    for (final p in petals) {
      final alpha = p.opacity * world;
      if (alpha <= 0.02) continue;
      final x = p.x * size.width + p.driftX * size.width * t * 10;
      final y = p.y * size.height;
      final angle = p.phase + p.spin * t * 3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final petalPaint = Paint()
        ..color = const Color(0xFFF3D9E0).withValues(alpha: alpha);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size * 0.7,
        height: p.size * 1.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(p.size),
          topRight: Radius.circular(p.size),
          bottomLeft: Radius.circular(p.size * 0.3),
          bottomRight: Radius.circular(p.size * 0.3),
        ),
        petalPaint,
      );
      canvas.restore();
    }
  }

  // ── vignette ──────────────────────────────────────────────
  void _paintVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const [0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  // ── helpers ───────────────────────────────────────────────
  double _fade(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  double _easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }

  @override
  bool shouldRepaint(covariant _YazzokiSplashPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.farSnow != farSnow ||
      oldDelegate.nearSnow != nearSnow ||
      oldDelegate.logo != logo ||
      oldDelegate.seal != seal;
}
