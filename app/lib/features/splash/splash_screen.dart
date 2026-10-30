import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/routes.dart';
import '../../core/widgets/app_state_scope.dart';

/// Splash total duration in ms — the animation HARD cap (spec: max 9s).
const int splashDurationMs = 8500;

/// Yazzoki splash screen — V2 (cinemática).
///
/// Fully native (CustomPaint + one AnimationController, no video/assets/deps).
/// The scene is built in true LAYERS around the brush-stroke emblem:
///
///   background (deep gradient + vignette + transient grid + far digital rain)
///   → mid rain / particles / light beams / HUD brackets (behind the emblem)
///   → the emblem image itself (with a soft ice-blue halo)
///   → front particles / sparks / glitch slices / HUD markers in front
///   → scanline crossing the logo + final cinematic center flash
///
/// The emblem fades/scales in while the network expands, and the whole scene
/// stays GPU-friendly (bounded counts, repaint isolated by the route).
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

  /// The scene is visually established (letters formed, network expanding);
  /// navigation can then fire as soon as the restore finishes.
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

/// Scene host: owns the persistent particle/burst/label data and steps it
/// on every animation tick (deterministic seed → stable tests).
class _YazzokiSplashScene extends StatefulWidget {
  const _YazzokiSplashScene({required this.animation, required this.onReady});

  final Animation<double> animation;
  final VoidCallback onReady;

  @override
  State<_YazzokiSplashScene> createState() => _YazzokiSplashSceneState();
}

class _YazzokiSplashSceneState extends State<_YazzokiSplashScene> {
  late final math.Random _rng;
  late final List<_RainColumn> _columns;
  late final List<_Particle> _particles;
  late final List<_Fragment> _fragments;
  late final List<_NetworkNode> _network;
  late final List<_Beam> _beams;
  late final List<_HudMarker> _hud;
  late final List<_Spark> _sparks;
  bool _readySent = false;
  ui.Image? _logo;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(42);
    _columns = List.generate(34, (i) => _RainColumn(index: i, rng: _rng));
    _particles = List.generate(40, (_) => _Particle(rng: _rng));
    _fragments = List.generate(14, (_) => _Fragment(rng: _rng));
    _network = List.generate(20, (_) => _NetworkNode(rng: _rng));
    _beams = List.generate(6, (_) => _Beam(rng: _rng));
    _hud = List.generate(12, (_) => _HudMarker(rng: _rng));
    _sparks = List.generate(10, (_) => _Spark(rng: _rng));
    widget.animation.addListener(_onTick);
    _loadLogo();
  }

  /// Loads the Yazzoki emblem once. If decoding fails (or is still pending
  /// in a test environment) the painter falls back to the drawn wordmark.
  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/brand/logo_paper.png');
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(
        data.buffer.asUint8List(),
        completer.complete,
      );
      final img = await completer.future;
      if (mounted) setState(() => _logo = img);
    } catch (_) {
      // No image: the painted wordmark keeps the splash usable.
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
    if (!_readySent && widget.animation.value >= 0.5) {
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
          columns: _columns,
          particles: _particles,
          fragments: _fragments,
          network: _network,
          beams: _beams,
          hud: _hud,
          sparks: _sparks,
          logo: _logo,
        ),
        size: Size.infinite,
      ),
    );
  }
}

// ── Sim state objects (persistent, mutated in place) ─────────

/// One falling binary stream.
class _RainColumn {
  _RainColumn({required this.index, required math.Random rng}) {
    speed = 0.5 + rng.nextDouble() * 1.3;
    brightness = 0.2 + rng.nextDouble() * 0.8;
    char = rng.nextBool() ? '0' : '1';
    // Non-uniform density: some columns cluster near one side.
    baseY = rng.nextDouble();
  }

  final int index;
  late final double speed;
  late final double brightness;
  late final String char;
  late final double baseY;
  double offset = 0;

  void tick(double dt) {
    offset = (offset + speed * dt * 0.3) % 1.0;
  }
}

/// Drifting glowing dot (back or front layer, some fast).
class _Particle {
  _Particle({required math.Random rng})
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        size = 0.6 + rng.nextDouble() * 1.8,
        driftY = 0.006 + rng.nextDouble() * 0.025,
        driftX = (rng.nextDouble() - 0.5) * 0.01,
        opacity = 0.15 + rng.nextDouble() * 0.7,
        twinkle = rng.nextDouble() * math.pi * 2,
        colorIndex = rng.nextInt(4),
        fast = rng.nextDouble() < 0.25;

  final double x;
  double y;
  final double size;
  final double driftY;
  final double driftX;
  final double opacity;
  final double twinkle;
  final int colorIndex;
  final bool fast;

  void tick(double dt) {
    y = (y - (fast ? 0.05 : 0.013) * dt) % 1.0;
  }
}

/// Small digital rectangle fragment that fades in/out.
class _Fragment {
  _Fragment({required math.Random rng})
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        w = 8 + rng.nextDouble() * 22,
        h = 4 + rng.nextDouble() * 10,
        colorIndex = rng.nextInt(4),
        phase = rng.nextDouble() * math.pi * 2;

  final double x;
  final double y;
  final double w;
  final double h;
  final int colorIndex;
  final double phase;

  double visibility(double t) {
    final v = (math.sin(t * 6 + phase) + 1) * 0.5;
    return v * v;
  }
}

/// Pulsing network node (lower/center region).
class _NetworkNode {
  _NetworkNode({required math.Random rng})
      : x = rng.nextDouble(),
        y = 0.5 + rng.nextDouble() * 0.45,
        size = 1.0 + rng.nextDouble() * 1.6,
        phase = rng.nextDouble() * math.pi * 2;

  final double x;
  final double y;
  final double size;
  final double phase;
}

/// A light beam crossing the composition (centage-independent).
class _Beam {
  _Beam({required math.Random rng})
      : angle = rng.nextDouble() * math.pi,
        thickness = 1.5 + rng.nextDouble() * 4,
        duration = 0.6 + rng.nextDouble() * 1.1,
        delay = rng.nextDouble() * 2,
        colorIndex = rng.nextInt(4);

  final double angle;
  final double thickness;
  final double duration;
  final double delay;
  final int colorIndex;

  /// 0..1 progress of this beam's journey at global time [t]; null when idle.
  double? progressAt(double t) {
    final local = t * 8.5 - delay;
    if (local < 0 || local > duration) return null;
    return local / duration;
  }
}

/// Atmospheric HUD marker (bracket / reticle / segment) — never text.
class _HudMarker {
  _HudMarker({required math.Random rng})
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        kind = rng.nextInt(3),
        size = 14 + rng.nextDouble() * 26,
        phase = rng.nextDouble() * math.pi * 2,
        colorIndex = rng.nextInt(4);

  final double x;
  final double y;
  final int kind;
  final double size;
  final double phase;
  final int colorIndex;
}

/// A quick front spark (energy dash).
class _Spark {
  _Spark({required math.Random rng})
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        length = 8 + rng.nextDouble() * 18,
        angle = rng.nextDouble() * math.pi * 2,
        phase = rng.nextDouble() * math.pi * 2,
        colorIndex = rng.nextInt(4);

  final double x;
  final double y;
  final double length;
  final double angle;
  final double phase;
  final int colorIndex;
}

/// Ordered digital palette used by accents (0..3): cyan, green, violet, magenta.
Color _accentColor(int index, double alpha) {
  return switch (index % 4) {
    0 => AppColors.electricBlue.withValues(alpha: alpha),
    1 => AppColors.success.withValues(alpha: alpha),
    2 => const Color(0xFF9D4EFF).withValues(alpha: alpha),
    3 => const Color(0xFFFF3EC8).withValues(alpha: alpha),
    _ => AppColors.electricBlue.withValues(alpha: alpha),
  };
}

/// Paints the full layered scene. Order defines depth:
/// background → far rain → back particles → beams → network → HUD (behind)
/// → inner-letter mask layer → letters + per-letter glow → HUD (front) →
/// near rain → front particles/sparks/glitch → scanline → center flash.
class _YazzokiSplashPainter extends CustomPainter {
  _YazzokiSplashPainter({
    required this.progress,
    required this.columns,
    required this.particles,
    required this.fragments,
    required this.network,
    required this.beams,
    required this.hud,
    required this.sparks,
    this.logo,
  });

  final double progress;
  final List<_RainColumn> columns;
  final List<_Particle> particles;
  final List<_Fragment> fragments;
  final List<_NetworkNode> network;
  final List<_Beam> beams;
  final List<_HudMarker> hud;
  final List<_Spark> sparks;
  final ui.Image? logo;

  static const _glyphBase = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: 13,
    color: Color(0xFF008CFF),
    fontWeight: FontWeight.w600,
  );
  static const _kStep = 1 / 60;


  @override
  void paint(Canvas canvas, Size size) {
    for (final c in columns) {
      c.tick(_kStep);
    }
    for (final p in particles) {
      p.tick(_kStep);
    }

    final t = progress;
    _paintBackground(canvas, size, t);
    _paintRain(canvas, size, t, far: true);
    _paintBackParticles(canvas, size, t);
    _paintBeams(canvas, size, t);
    _paintNetwork(canvas, size, t);

    _paintHud(canvas, size, t, front: false);
    _paintLogo(canvas, size, t);
    _paintFragments(canvas, size, t);
    _paintHud(canvas, size, t, front: true);
    _paintRain(canvas, size, t, far: false);
    _paintFront(canvas, size, t);
    _paintScanline(canvas, size, t);
    _paintFlash(canvas, size, t);
  }

  // ── background ────────────────────────────────────────────
  void _paintBackground(Canvas canvas, Size size, double t) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF03060B), Color(0xFF000103), Color(0xFF001209)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.electricBlue
              .withValues(alpha: 0.16 * (0.2 + 0.8 * _fade(t, 0.05, 0.5))),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glow);

    // Transient grid flash (early awakening pulse).
    final grid = _fade(t, 0.05, 0.2) * (1 - _fade(t, 0.3, 0.5));
    if (grid > 0.01) {
      final gp = Paint()
        ..color = AppColors.electricBlue.withValues(alpha: 0.13 * grid)
        ..strokeWidth = 0.5;
      final step = size.shortestSide / 14;
      for (double x = 0; x <= size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
      }
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
      }
    }
  }

  // ── digital rain (far = deeper/smaller, near = closer/larger) ──
  void _paintRain(Canvas canvas, Size size, double t, {required bool far}) {
    final gauge = size.width / columns.length;
    final centerY = size.height * 0.5;
    for (var c = 0; c < columns.length; c++) {
      final col = columns[c];
      final isFar = col.baseY < 0.4;
      if (far != isFar) continue;

      final x = col.index * gauge + gauge / 2;
      final y = col.offset * size.height;
      final distToCenter = (y - centerY).abs();
      if (distToCenter < size.height * 0.15) continue;

      final depth = 1.0 - (y / size.height - 0.5).abs() * 1.2;
      final alpha = col.brightness * depth * (far ? 0.45 : 0.85);
      if (alpha <= 0.04) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: col.char,
          style: _glyphBase.copyWith(
            fontSize: far ? 9 : 13,
            color: _accentColor(c % 4, alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }
  }

  // ── back particles ────────────────────────────────────────
  void _paintBackParticles(Canvas canvas, Size size, double t) {
    final world = _fade(t, 0.0, 0.55);
    if (world <= 0.01) return;
    for (final p in particles) {
      if (p.fast) continue;
      final twinkle = (math.sin(p.twinkle + t * 7) + 1) * 0.5;
      final alpha = p.opacity * (0.3 + 0.7 * twinkle) * world;
      if (alpha <= 0.02) continue;
      final paint = Paint()
        ..color = _accentColor(p.colorIndex, alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  // ── light beams crossing the composition ──────────────────
  void _paintBeams(Canvas canvas, Size size, double t) {
    final world = _fade(t, 0.1, 0.55);
    if (world <= 0.01) return;
    for (final b in beams) {
      final p = b.progressAt(t);
      if (p == null) continue;
      final alpha = math.sin(p * math.pi) * 0.5 * world;
      if (alpha <= 0.02) continue;
      final paint = Paint()
        ..color = _accentColor(b.colorIndex, alpha)
        ..strokeWidth = b.thickness * (1 - p * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
      final dir = Offset(math.cos(b.angle), math.sin(b.angle));
      final norm = Offset(-dir.dy, dir.dx);
      final start = Offset(size.width * 0.2, size.height * 0.5) +
          norm * 80 +
          dir * (p - 0.5) * size.shortestSide * 2.2;
      final end = start - dir * size.shortestSide * 0.7;
      canvas.drawLine(start, end, paint);
    }
  }

  // ── network ───────────────────────────────────────────────
  void _paintNetwork(Canvas canvas, Size size, double t) {
    final net = _fade(t, 0.35, 0.95);
    if (net <= 0.01) return;
    final pts = <Offset>[
      for (final n in network)
        Offset(n.x * size.width, n.y * size.height * 0.68),
    ];
    final line = Paint()
      ..color = _accentColor(0, 0.15 * net)
      ..strokeWidth = 0.6;
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final a = pts[i];
        final b = pts[j];
        if ((a - b).distance < size.shortestSide * 0.26) {
          canvas.drawLine(a, b, line);
        }
      }
    }
    for (var i = 0; i < pts.length; i++) {
      final n = network[i];
      final pulse = (math.sin(t * 5 + n.phase) + 1) * 0.5;
      final node = Paint()
        ..color = _accentColor(pulse > 0.6 ? 1 : 0, 0.7 * net)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3);
      canvas.drawCircle(pts[i], n.size * (0.8 + 0.5 * pulse), node);
    }
  }

  // ── HUD markers (atmospheric, no text) ────────────────────
  void _paintHud(Canvas canvas, Size size, double t, {required bool front}) {
    final world = _fade(t, 0.15, 0.85);
    if (world <= 0.01) return;
    for (var i = 0; i < hud.length; i++) {
      final m = hud[i];
      final isBehind = m.kind == 0 || m.kind == 1;
      if (front == isBehind) continue;
      final alpha = (0.2 + 0.5 * (math.sin(t * 4 + m.phase) + 1) * 0.5) * world;
      if (alpha <= 0.03) continue;
      final paint = Paint()
        ..color = _accentColor(m.colorIndex, alpha)
        ..strokeWidth = 1.0;
      final cx = m.x * size.width;
      final cy = m.y * size.height;
      final s = m.size;
      switch (m.kind) {
        case 0: // corner bracket
          _drawBracket(canvas, Offset(cx, cy), s, paint);
        case 1: // reticle
          canvas.drawCircle(
            Offset(cx, cy),
            s * 0.4,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = paint.color
              ..strokeWidth = 1,
          );
          canvas.drawLine(Offset(cx - s, cy), Offset(cx + s, cy), paint);
        case 2: // segment ticks
          canvas.drawLine(Offset(cx, cy - s), Offset(cx, cy + s), paint);
          canvas.drawLine(Offset(cx - s, cy), Offset(cx + s, cy), paint);
      }
    }
  }

  void _drawBracket(Canvas canvas, Offset p, double s, Paint paint) {
    final path = Path()
      ..moveTo(p.dx - s, p.dy - s)
      ..lineTo(p.dx - s, p.dy - s * 0.4)
      ..moveTo(p.dx - s, p.dy - s)
      ..lineTo(p.dx - s * 0.4, p.dy - s)
      ..moveTo(p.dx + s, p.dy - s)
      ..lineTo(p.dx + s * 0.4, p.dy - s)
      ..moveTo(p.dx + s, p.dy - s)
      ..lineTo(p.dx + s, p.dy - s * 0.4)
      ..moveTo(p.dx - s, p.dy + s)
      ..lineTo(p.dx - s, p.dy + s * 0.4)
      ..moveTo(p.dx - s, p.dy + s)
      ..lineTo(p.dx - s * 0.4, p.dy + s)
      ..moveTo(p.dx + s, p.dy + s)
      ..lineTo(p.dx + s * 0.4, p.dy + s)
      ..moveTo(p.dx + s, p.dy + s)
      ..lineTo(p.dx + s, p.dy + s * 0.4);
    canvas.drawPath(path, paint);
  }

  // ── logo (real emblem image, painted on the canvas) ──────
  //
  // The emblem is a raster brush stroke, so it is painted as an image rather
  // than rebuilt from glyphs. When the image is unavailable (decode pending
  // or failed) a mincho wordmark is drawn instead, keeping the scene intact.
  void _paintLogo(Canvas canvas, Size size, double t) {
    final appear = _easeOutBack(_fade(t, 0.2, 0.55));
    if (appear <= 0.004) return;

    final image = logo;
    if (image != null) {
      final targetH = size.height * 0.30;
      final targetW = targetH * image.width / image.height;
      final dst = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.46),
        width: targetW,
        height: targetH,
      );

      // Soft ice-blue halo behind the emblem.
      final halo = Paint()
        ..color = AppColors.electricBlue.withValues(alpha: 0.18 * appear)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(dst.inflate(14), const Radius.circular(24)),
        halo,
      );

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.white.withValues(alpha: appear),
            BlendMode.modulate,
          ),
      );

      // Scanline crossing the emblem (kept from the previous composition).
      final y = dst.top + dst.height * ((t * 3.1) % 1.0);
      canvas.drawLine(
        Offset(dst.left, y),
        Offset(dst.right, y),
        Paint()
          ..color = AppColors.electricBlue.withValues(alpha: 0.35 * appear)
          ..strokeWidth = 1.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
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
          shadows: [
            Shadow(color: AppColors.electricBlue, blurRadius: 26),
            Shadow(color: AppColors.primaryBlue, blurRadius: 12),
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

  // ── digital fragments (square/rect data chunks) ───────────
  void _paintFragments(Canvas canvas, Size size, double t) {
    final world = _fade(t, 0.3, 0.9);
    if (world <= 0.01) return;
    for (var i = 0; i < fragments.length; i++) {
      final f = fragments[i];
      final v = f.visibility(t);
      final alpha = v * world * 0.6;
      if (alpha <= 0.03) continue;
      final paint = Paint()
        ..color = _accentColor(f.colorIndex, alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
      canvas.drawRect(
        Rect.fromLTWH(
          f.x * size.width,
          f.y * size.height,
          f.w,
          f.h,
        ),
        paint,
      );
    }
  }

  // ── front layer (fast particles + sparks + glitch slices) ─
  void _paintFront(Canvas canvas, Size size, double t) {
    final world = _fade(t, 0.4, 0.9);
    if (world <= 0.01) return;

    for (final p in particles) {
      if (!p.fast) continue;
      final twinkle = (math.sin(p.twinkle + t * 12) + 1) * 0.5;
      final alpha = p.opacity * (0.5 + 0.5 * twinkle) * world;
      if (alpha <= 0.03) continue;
      final paint = Paint()
        ..color = _accentColor(p.colorIndex, alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * 1.8,
        paint,
      );
    }

    for (var i = 0; i < sparks.length; i++) {
      final s = sparks[i];
      final v = (math.sin(t * 9 + s.phase) + 1) * 0.5;
      final alpha = 0.7 * v * v * world;
      if (alpha <= 0.04) continue;
      final paint = Paint()
        ..color = _accentColor(s.colorIndex, alpha)
        ..strokeWidth = 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1);
      final p = Offset(s.x * size.width, s.y * size.height);
      final d = Offset(math.cos(s.angle), math.sin(s.angle)) * s.length;
      canvas.drawLine(p - d, p + d, paint);
    }

    final glitchAmp = _glitchAmp(t);
    if (glitchAmp > 0.03) {
      for (var i = 0; i < 3; i++) {
        final y = size.height * 0.34 +
            ((t * 7 + i * 0.37) % 1.0) * size.height * 0.32;
        final w = size.shortestSide * glitchAmp * (0.22 + 0.18 * i);
        final paint = Paint()..color = _accentColor(i + 1, 0.32 * glitchAmp);
        canvas.drawRect(
          Rect.fromLTWH(size.width / 2 - w - i * 6, y, w * 2, 1.4),
          paint,
        );
      }
    }
  }

  // ── scanline crossing the logo ────────────────────────────
  void _paintScanline(Canvas canvas, Size size, double t) {
    final primary = _pulseWindow(t, 0.45, 0.7);
    final always =
        0.1 + 0.14 * (math.sin(t * 9) + 1) * 0.5 * _fade(t, 0.5, 0.9);
    if (primary <= 0.01 && always <= 0.02) return;
    final y = size.height * (0.3 + 0.4 * ((t * 3.1) % 1.0));
    final p1 = Paint()
      ..color =
          AppColors.electricBlue.withValues(alpha: 0.45 * (primary + always))
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), p1);
    final p2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * (primary + always))
      ..strokeWidth = 0.7;
    canvas.drawLine(Offset(0, y + 3), Offset(size.width, y + 3), p2);
  }

  // ── final cinematic center flash ───────────────────────────
  void _paintFlash(Canvas canvas, Size size, double t) {
    final warm = _fade(t, 0.72, 0.86) * _fade(t, 0.95, 1.0);
    if (warm <= 0.01) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.22 * warm),
          AppColors.electricBlue.withValues(alpha: 0.1 * warm),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  // ── helpers ───────────────────────────────────────────
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

  /// Sharp glitch amplitude: bursts during storm segments, ~0 otherwise.
  double _glitchAmp(double t) {
    final storm = _fade(t, 0.45, 0.6) * _fade(t, 0.72, 0.7) +
        _fade(t, 0.4, 0.5) * _fade(t, 0.68, 0.62);
    final burst = _pulseWindow(t, 0.5, 0.56) +
        _pulseWindow(t, 0.62, 0.66) +
        _pulseWindow(t, 0.82, 0.85);
    return (storm * 0.4 + burst).clamp(0.0, 1.0);
  }

  /// 1 inside the [start,end] window, with sharp edges.
  double _pulseWindow(double t, double start, double end) {
    final on = _fade(t, start, start + 0.02);
    final off = 1 - _fade(t, end - 0.02, end);
    return on * off;
  }

  @override
  bool shouldRepaint(covariant _YazzokiSplashPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.columns != columns ||
      oldDelegate.particles != particles ||
      oldDelegate.network != network ||
      oldDelegate.logo != logo;
}
