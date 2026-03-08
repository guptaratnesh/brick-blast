import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_controller.dart';
import 'game_models.dart';

class GamePainter extends CustomPainter {
  final GameController g;
  final double t;

  // Shared loaded background image
  static ui.Image? _bgImage;
  static bool _bgLoading = false;

  static Future<void> loadBackground() async {
    if (_bgImage != null || _bgLoading) return;
    _bgLoading = true;
    try {
      final data = await rootBundle.load('assets/space_bg.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _bgImage = frame.image;
    } catch (e) {
      print('BG image load error: \$e');
    }
  }

  const GamePainter(this.g, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    if (g.state == GameState.menu) { _drawMenu(canvas, size); return; }
    _drawBricks(canvas);
    _drawBullets(canvas);
    _drawLaserRays(canvas);
    _drawParticles(canvas);
    _drawDrops(canvas);
    _drawPaddle(canvas, size);
    _drawPowerStrip(canvas, size);
    _drawHUD(canvas, size);
    _drawScorePopups(canvas);
    if (g.state == GameState.paused && g.bossCountdownActive) {
      _drawBossCountdown(canvas, size);
    } else if (g.state == GameState.paused) _drawPauseOverlay(canvas, size);
    if (g.state == GameState.clear) _drawClearOverlay(canvas, size);
    if (g.state == GameState.dead) _drawDeadOverlay(canvas, size);
  }

  // ── Background ────────────────────────────────────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    final W = size.width; final H = size.height;
    final img = _bgImage;
    if (img != null) {
      _drawScrollingBackground(canvas, W, H, img);
    } else {
      _drawAnimatedBackground(canvas, W, H, t);
    }
    // Danger zone line (at paddle level)
    canvas.drawLine(
      Offset(0, g.padY + g.padH + 4),
      Offset(W, g.padY + g.padH + 4),
      Paint()..color = const Color(0xFFFF2244).withOpacity(0.25)..strokeWidth = 1,
    );
  }

  void _drawScrollingBackground(Canvas canvas, double W, double H, ui.Image img) {
    // Slowly scroll image upward in a seamless loop
    // Speed: image height / 60 seconds for a full loop
    const scrollSpeed = 18.0; // pixels per second
    final imgH = img.height.toDouble();
    final imgW = img.width.toDouble();

    // Calculate vertical scroll offset — loops every imgH/scrollSpeed seconds
    final offset = (t * scrollSpeed) % imgH;

    // Scale image to fill screen width
    final scale = W / imgW;
    final displayH = imgH * scale;

    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final paint = Paint()..filterQuality = FilterQuality.low;

    // Draw two copies to fill the seamless loop gap
    // First copy scrolling up
    final dst1 = Rect.fromLTWH(0, -offset * scale, W, displayH);
    canvas.drawImageRect(img, src, dst1, paint);

    // Second copy directly below to fill the wrap gap
    final dst2 = Rect.fromLTWH(0, displayH - offset * scale, W, displayH);
    canvas.drawImageRect(img, src, dst2, paint);

    // Subtle dark overlay so game elements stay readable
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H),
      Paint()..color = Colors.black.withOpacity(0.35));

    // Shooting stars on top of image — keep some life
    _drawShootingStar(canvas, (t % 9.0) / 9.0, W * 0.15, H * 0.25, W * 0.55, H * 0.30);
    _drawShootingStar(canvas, (t % 13.0) / 13.0, W * 0.70, H * 0.10, W * 0.30, H * 0.65);
  }

  void _drawAnimatedBackground(Canvas canvas, double W, double H, double t) {
    final p = Paint();

    // ── Pure deep black base ──
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H),
        Paint()..color = const Color(0xFF01010A));

    // ── Very faint deep blue vignette glow at center (flat, no blur) ──
    canvas.drawCircle(
      Offset(W * 0.5, H * 0.42),
      W * 0.85,
      Paint()..shader = RadialGradient(
        colors: [const Color(0xFF050D2A).withOpacity(0.85), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(W * 0.5, H * 0.42), radius: W * 0.85)),
    );

    // ── Milky Way — wide soft band drifting downward (no blur for perf) ──
    final mwDrift = (t * 6.0) % H;
    for (final offset in [0.0, -H]) {
      final cy = H * 0.40 + mwDrift + offset;
      // Outer glow — semi-transparent wide oval, no blur
      canvas.drawOval(
        Rect.fromCenter(center: Offset(W * 0.48, cy), width: W * 2.0, height: H * 0.22),
        Paint()..color = const Color(0xFF0A0830).withOpacity(0.55),
      );
      // Mid band
      canvas.drawOval(
        Rect.fromCenter(center: Offset(W * 0.50, cy - H * 0.01), width: W * 1.4, height: H * 0.09),
        Paint()..color = const Color(0xFF1A1050).withOpacity(0.45),
      );
      // Bright core streak
      canvas.drawOval(
        Rect.fromCenter(center: Offset(W * 0.50, cy - H * 0.015), width: W * 0.8, height: H * 0.028),
        Paint()..color = const Color(0xFF6655CC).withOpacity(0.18),
      );
    }

    // ── Deep space nebula patches (no blur — flat translucent ovals) ──
    // Static — no per-frame sin/cos movement to save CPU
    final nebulae = [
      (W*0.12, H*0.15, W*0.50, H*0.28, const Color(0xFF050A28), 0.55),
      (W*0.85, H*0.22, W*0.45, H*0.24, const Color(0xFF080520), 0.50),
      (W*0.55, H*0.68, W*0.60, H*0.30, const Color(0xFF060818), 0.45),
      (W*0.20, H*0.78, W*0.44, H*0.22, const Color(0xFF04081E), 0.48),
    ];
    for (final n in nebulae) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(n.$1, n.$2), width: n.$3, height: n.$4),
        Paint()..color = n.$5.withOpacity(n.$6),
      );
    }

    // ── Star field — 4 layers drifting downward (camera zoom effect) ──
    final counts   = [28, 10, 4, 2];
    final speeds   = [0.75, 2.25, 5.5, 2.0];
    final maxSizes = [0.9, 1.6, 2.8, 4.0];
    final brights  = [140, 185, 230, 255];

    for (int layer = 0; layer < 4; layer++) {
      for (int i = 0; i < counts[layer]; i++) {
        final seed   = i * 2.7183 + layer * 37.1 + 1.4142;
        final baseX  = ((seed * 73.1) % 1.0) * W;
        final baseY  = ((seed * 31.7) % 1.0) * H;
        final sz     = maxSizes[layer] * (0.45 + ((seed * 53.9) % 1.0) * 0.55);
        final tPhase = (seed * 11.1) % 6.2832;
        final drift  = (t * speeds[layer] * 10.0) % H;
        final x = baseX;
        final y = (baseY + drift) % H;
        final twinkle = sin(t * 1.6 + tPhase) * 0.30 + 0.70;
        final alpha   = (twinkle * brights[layer]).toInt().clamp(0, 255);
        final tint = i % 7;
        final Color sc;
        if      (tint == 0) {
          sc = Color.fromARGB(alpha, 140, 185, 255);
        } else if (tint == 1) sc = Color.fromARGB(alpha, 180, 210, 255);
        else if (tint == 2) sc = Color.fromARGB((alpha * 0.7).toInt(), 220, 200, 255);
        else                sc = Color.fromARGB(alpha, 235, 240, 255);
        p..color = sc..strokeWidth = 0.8;
        canvas.drawCircle(Offset(x, y), sz, p);
        // sparkle arms removed for performance
      }
    }

    // ── Shooting stars ──
    final s1 = t % 9.0;
    if (s1 < 1.2) _drawShootingStar(canvas, s1 / 1.2, W * 0.05, H * 0.06, W * 0.62, H * 0.38);
    final s2 = (t + 5.0) % 13.0;
    if (s2 < 0.9) _drawShootingStar(canvas, s2 / 0.9, W * 0.90, H * 0.10, W * 0.30, H * 0.50);
  }

  void _drawShootingStar(Canvas canvas, double prog,
      double x1, double y1, double x2, double y2) {
    final cx = x1 + (x2 - x1) * prog;
    final cy = y1 + (y2 - y1) * prog;
    final tx = x1 + (x2 - x1) * (prog - 0.22).clamp(0, 1);
    final ty = y1 + (y2 - y1) * (prog - 0.22).clamp(0, 1);
    final op = prog < 0.10 ? prog / 0.10 : prog > 0.80 ? (1 - prog) / 0.20 : 1.0;
    canvas.drawLine(Offset(tx, ty), Offset(cx, cy),
      Paint()..color = const Color(0xFF4466FF).withOpacity(op * 0.35)..strokeWidth = 3.5);
    canvas.drawLine(Offset(tx, ty), Offset(cx, cy),
      Paint()..color = Colors.white.withOpacity(op * 0.95)..strokeWidth = 1.1);
    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = Colors.white.withOpacity(op));
  }

  // ── Bricks ────────────────────────────────────────────────────────────────
  void _drawBricks(Canvas canvas) {
    for (int i = 0; i < g.bricks.length; i++) {
      final br = g.bricks[i];
      if (!br.alive) continue;
      // Deterministic shake offset — no Random allocation per frame
      final ox = br.shakeFrames > 0 ? ((i * 1.618) % 1.0 - 0.5) * 4 : 0.0;
      // Frozen bricks have their y individually adjusted; use brickDescentY only for non-frozen
      final dy = g.brickDescentY;
      final bx = br.x + ox;
      final by = br.y + dy;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, br.w, br.h), const Radius.circular(6));

      // ── Special brick glow behind ──
      Color? glowColor;
      switch (br.brickType) {
        case BrickType.bomb:      glowColor = const Color(0xFFFF4400); break;
        case BrickType.shield:    glowColor = br.shieldActive ? const Color(0xFF88AAFF) : null; break;
        case BrickType.colorBomb: glowColor = const Color(0xFFFFFFFF); break;
        case BrickType.ice:       glowColor = const Color(0xFFAAEEFF); break;
        case BrickType.fountain:  glowColor = const Color(0xFF00FFCC); break;
        default: break;
      }
      if (glowColor != null) {
        final pulse = sin(t * 0.08 + i * 0.5) * 0.3 + 0.7;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bx - 3, by - 3, br.w + 6, br.h + 6), const Radius.circular(9)),
          Paint()..color = glowColor.withOpacity(0.28 * pulse));
      }

      // ── Frozen overlay ──
      if (br.isFrozen) {
        canvas.drawRRect(rect, Paint()..color = const Color(0xFF88DDFF).withOpacity(0.35));
      }

      // ── Fill ──
      canvas.drawRRect(rect, Paint()..color = br.color);

      // ── Special brick patterns ──
      switch (br.brickType) {
        case BrickType.bomb:
          canvas.drawRRect(rect, Paint()..color = Colors.black.withOpacity(0.4));
          _drawText(canvas, '💣', Offset(bx + br.w / 2, by + br.h / 2), 11);
        case BrickType.shield:
          if (br.shieldActive) {
            canvas.drawRRect(rect, Paint()..color = Colors.white.withOpacity(0.2));
            _drawText(canvas, '🛡️', Offset(bx + br.w / 2, by + br.h / 2), 11);
          } else {
            canvas.drawRRect(rect, Paint()..color = Colors.black.withOpacity(0.25));
            _drawText(canvas, '🔓', Offset(bx + br.w / 2, by + br.h / 2), 9);
          }
        case BrickType.colorBomb:
          final shimmerColor = HSVColor.fromAHSV(1.0, (t * 18.0) % 360, 0.9, 1.0).toColor();
          canvas.drawRRect(rect, Paint()..color = shimmerColor.withOpacity(0.35));
          _drawText(canvas, '🌈', Offset(bx + br.w / 2, by + br.h / 2), 11);
        case BrickType.ice:
          canvas.drawRRect(rect, Paint()..color = Colors.white.withOpacity(0.25));
          _drawText(canvas, '❄️', Offset(bx + br.w / 2, by + br.h / 2), 11);
        case BrickType.fountain:
          _drawText(canvas, '⛲', Offset(bx + br.w / 2, by + br.h / 2), 11);
        case BrickType.normal:
          // HP number if > 1
          if (br.hp > 1) {
            canvas.drawRRect(rect, Paint()..color = Colors.black.withOpacity(0.25));
            _drawText(canvas, '${br.hp}', Offset(bx + br.w / 2, by + br.h / 2), 10, color: Colors.white, bold: true);
          }
      }

      // ── Shine ──
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx + 3, by + 3, br.w - 6, br.h * 0.38), const Radius.circular(3)),
        Paint()..color = Colors.white.withOpacity(br.brickType == BrickType.normal ? 0.22 : 0.15));

      // ── Border ──
      canvas.drawRRect(rect,
        Paint()..color = (glowColor ?? Colors.white).withOpacity(0.18)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
  }

  // ── Bullets ───────────────────────────────────────────────────────────────
  void _drawBullets(Canvas canvas) {
    for (final b in g.bullets) {
      switch (b.type) {
        case BulletType.normal:
          canvas.drawCircle(Offset(b.x, b.y), 4,
            Paint()..color = Colors.white);
          canvas.drawCircle(Offset(b.x, b.y), 2,
            Paint()..color = const Color(0xFF00FFFF));
          break;
        case BulletType.fire:
          // Orange-red glowing bullet
          canvas.drawCircle(Offset(b.x, b.y), 6,
            Paint()..color = const Color(0xFFFF4400).withOpacity(0.4));
          canvas.drawCircle(Offset(b.x, b.y), 4,
            Paint()..color = const Color(0xFFFF8800));
          canvas.drawCircle(Offset(b.x, b.y), 2,
            Paint()..color = const Color(0xFFFFFFAA));
          break;
        case BulletType.laser:
          // Bright yellow with streak
          canvas.drawLine(Offset(b.x, b.y + 10), Offset(b.x, b.y - 10),
            Paint()..color = const Color(0xFFFFFF00).withOpacity(0.5)..strokeWidth = 6);
          canvas.drawLine(Offset(b.x, b.y + 8), Offset(b.x, b.y - 8),
            Paint()..color = const Color(0xFFFFFF00)..strokeWidth = 3);
          canvas.drawLine(Offset(b.x, b.y + 6), Offset(b.x, b.y - 6),
            Paint()..color = Colors.white..strokeWidth = 1.5);
          break;
        case BulletType.whirlgig:
          // Purple spinning bullet
          canvas.drawCircle(Offset(b.x, b.y), 5,
            Paint()..color = const Color(0xFFCC44FF).withOpacity(0.4));
          canvas.drawCircle(Offset(b.x, b.y), 3,
            Paint()..color = const Color(0xFFCC44FF));
          canvas.drawCircle(Offset(b.x, b.y), 1.5,
            Paint()..color = Colors.white);
          break;
      }
    }
  }

  // ── Laser pierce rays ────────────────────────────────────────────────────
  void _drawLaserRays(Canvas canvas) {
    for (final ray in g.laserRays) {
      final op = ray['life']!.clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(ray['x1']!, ray['y1']!),
        Offset(ray['x2']!, ray['y2']!),
        Paint()..color = const Color(0xFFFFFF00).withOpacity(op * 0.6)..strokeWidth = 4);
      canvas.drawLine(
        Offset(ray['x1']!, ray['y1']!),
        Offset(ray['x2']!, ray['y2']!),
        Paint()..color = Colors.white.withOpacity(op)..strokeWidth = 1.5);
    }
  }

  // ── Particles — rects are faster than circles on GPU ────────────────────
  static final _pPaint = Paint();
  void _drawParticles(Canvas canvas) {
    for (final p in g.particles) {
      final r = p.r * p.life;
      _pPaint.color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(p.x - r, p.y - r, r * 2, r * 2), _pPaint);
    }
  }

  // ── Drops ─────────────────────────────────────────────────────────────────
  void _drawDrops(Canvas canvas) {
    for (final d in g.drops) {
      // Glowing circle background
      _drawText(canvas, d.label, Offset(d.x, d.y), 14, color: Colors.white);
    }
  }

  // ── Paddle ────────────────────────────────────────────────────────────────
  void _drawPaddle(Canvas canvas, Size size) {
    final List<Color> skinColors = [
      const Color(0xFF00FFFF), // neon cyan
      const Color(0xFFFF6600), // fire orange
      const Color(0xFF88DDFF), // ice blue
      const Color(0xFFFFD700), // gold
    ];
    final col = skinColors[g.paddleSkin % skinColors.length];
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(g.padX, g.padY, g.padW, g.padH), const Radius.circular(7));
    // Glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(g.padX - 4, g.padY - 4, g.padW + 8, g.padH + 8), const Radius.circular(11)),
      Paint()..color = col.withOpacity(0.18));
    // Main body
    canvas.drawRRect(rect, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [col.withOpacity(0.9), col.withOpacity(0.5)],
    ).createShader(Rect.fromLTWH(g.padX, g.padY, g.padW, g.padH)));
    // Shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(g.padX + 4, g.padY + 2, g.padW - 8, g.padH * 0.4), const Radius.circular(4)),
      Paint()..color = Colors.white.withOpacity(0.35));
    // Cannons
    final cannonPaint = Paint()..color = col;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(g.padX + 3, g.padY - 6, 6, 8), const Radius.circular(2)), cannonPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(g.padX + g.padW - 9, g.padY - 6, 6, 8), const Radius.circular(2)), cannonPaint);

    // Active bullet type indicator on paddle
    if (g.activeBulletType != BulletType.normal) {
      String icon;
      Color iconColor;
      switch (g.activeBulletType) {
        case BulletType.fire:     icon = '🔥'; iconColor = const Color(0xFFFF8800); break;
        case BulletType.laser:    icon = '⚡'; iconColor = const Color(0xFFFFFF00); break;
        case BulletType.whirlgig: icon = '🌀'; iconColor = const Color(0xFFCC44FF); break;
        default:                  icon = '';   iconColor = Colors.white;
      }
      if (icon.isNotEmpty) {
        _drawText(canvas, icon, Offset(g.padX + g.padW / 2, g.padY - 14), 12, color: iconColor);
      }
    }
  }

  // ── HUD ───────────────────────────────────────────────────────────────────
  void _drawHUD(Canvas canvas, Size size) {
    final W = size.width;

    // ── Score (top centre) ────────────────────────────────────────────────────
    _drawText(canvas, 'SCORE  ${g.score}', Offset(W / 2, 44), 18, color: Colors.white, bold: true);

    // ── Lives as individual hearts — left side ────────────────────────────────
    for (int i = 0; i < 3; i++) {
      final filled = i < g.lives;
      _drawText(canvas, filled ? '❤' : '♡', Offset(18.0 + i * 22.0, 52), 18,
        color: filled ? const Color(0xFFFF4466) : Colors.white24);
    }

    // ── Level — right side ────────────────────────────────────────────────────
    _drawText(canvas, 'LV ${g.level}', Offset(W - 28, 52), 13,
      color: const Color(0xFF88AAFF), bold: true);

    // ── Bullet balance — always shown centre ────────────────────────────────
    final normalLeft = g.normalBullets;
    final critical = normalLeft <= 20;
    final warning  = normalLeft <= 50;
    final pulse = critical ? (sin(t * 8) * 0.4 + 0.6) : 1.0;
    final bulletColor = critical
        ? const Color(0xFFFF2244)
        : warning ? const Color(0xFFFFAA00) : Colors.white70;
    _drawText(canvas, '🔫 $normalLeft', Offset(W / 2, 70), 13,
      color: bulletColor.withOpacity(pulse), bold: warning || critical);

    // ── Combo ─────────────────────────────────────────────────────────────────
    if (g.combo > 1) {
      _drawText(canvas, '×${g.combo} COMBO!', Offset(W / 2, 88), 14,
        color: const Color(0xFFFFE135), bold: true);
    }

    // ── Wide paddle indicator ─────────────────────────────────────────────────
    if (g.puWide) {
      final frac = g.puWideT / 600.0;
      final barW = W * 0.3;
      final barY = 106.0;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(W / 2 - barW / 2, barY, barW, 4), const Radius.circular(2)),
        Paint()..color = Colors.white.withOpacity(0.15));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(W / 2 - barW / 2, barY, barW * frac, 4), const Radius.circular(2)),
        Paint()..color = const Color(0xFF00FF88).withOpacity(0.8));
      _drawText(canvas, '↔ WIDE', Offset(W / 2, barY + 14), 11, color: const Color(0xFF00FF88));
    }

    // ── Life lost flash overlay ───────────────────────────────────────────────
    if (g.lifeFlashTimer > 0) {
      final alpha = (g.lifeFlashTimer / 60.0) * 0.5;
      canvas.drawRect(Rect.fromLTWH(0, 0, W, size.height),
        Paint()..color = const Color(0xFFFF0000).withOpacity(alpha));
      final remaining = g.lives;
      final msg = remaining > 0 ? 'LIFE LOST!  $remaining LEFT' : '';
      if (msg.isNotEmpty) {
        _drawText(canvas, msg, Offset(W / 2, size.height * 0.42), 20,
          color: Colors.white.withOpacity((g.lifeFlashTimer / 60.0).clamp(0.0, 1.0)), bold: true);
      }
    }
  }

  // ── Score popups ──────────────────────────────────────────────────────────
  void _drawScorePopups(Canvas canvas) {
    for (final p in g.scorePopups) {
      final op = (p['life'] as double).clamp(0.0, 1.0);
      final combo = p['combo'] as int;
      final scale = 1.0 + (combo * 0.1).clamp(0.0, 1.0);
      _drawText(canvas, '+${p['points']}',
        Offset(p['x'] as double, p['y'] as double),
        (12 * scale).clamp(10, 22),
        color: Color(p['color'] as int).withOpacity(op));
    }
  }

  // ── Power Strip ──────────────────────────────────────────────────────────
  // Returns list of slot rects so game_screen can hit-test taps
  static const double _slotW = 58.0;
  static const double _slotGap = 10.0;

  // Strip sits just below the paddle, above the bottom edge
  double _stripY(double screenH) => g.padY + g.padH + 18;

  List<Rect> powerStripSlotRects(double screenW, double screenH) {
    final types = [BulletType.normal, BulletType.fire, BulletType.laser, BulletType.whirlgig];
    final totalW = types.length * _slotW + (types.length - 1) * _slotGap;
    final startX = (screenW - totalW) / 2;
    final y = _stripY(screenH);
    return List.generate(types.length, (i) => Rect.fromLTWH(startX + i * (_slotW + _slotGap), y, _slotW, _slotW));
  }

  void _drawPowerStrip(Canvas canvas, Size size) {
    if (g.state != GameState.playing && g.state != GameState.paused) return;
    final W = size.width; final H = size.height;

    final types  = [BulletType.normal, BulletType.fire, BulletType.laser, BulletType.whirlgig];
    final icons  = ['🔫', '🔥', '⚡', '🌀'];
    final colors = [const Color(0xFF00FFFF), const Color(0xFFFF6600), const Color(0xFFFFFF00), const Color(0xFFCC44FF)];
    final totalW = types.length * _slotW + (types.length - 1) * _slotGap;
    final startX = (W - totalW) / 2;
    final y      = _stripY(H);

    // Strip background panel
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(startX - 12, y - 8, totalW + 24, _slotW + 16), const Radius.circular(18)),
      Paint()..color = Colors.black.withOpacity(0.65));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(startX - 12, y - 8, totalW + 24, _slotW + 16), const Radius.circular(18)),
      Paint()..color = Colors.white.withOpacity(0.10)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    for (int i = 0; i < types.length; i++) {
      final type    = types[i];
      final col     = colors[i];
      final slotX   = startX + i * (_slotW + _slotGap);
      final slotRect = RRect.fromRectAndRadius(Rect.fromLTWH(slotX, y, _slotW, _slotW), const Radius.circular(12));
      final isActive = g.activeBulletType == type;
      // All types share normalBullets pool
      final count   = g.normalBullets;
      final hasAmmo = count > 0;
      final unlocked = type == BulletType.normal
          || (type == BulletType.fire     && g.level >= 5)
          || (type == BulletType.laser    && g.level >= 10)
          || (type == BulletType.whirlgig && g.level >= 25);

      // Slot background
      canvas.drawRRect(slotRect, Paint()..color = isActive
        ? col.withOpacity(0.25)
        : Colors.white.withOpacity(hasAmmo ? 0.07 : 0.03));

      // Active glow border
      if (isActive) {
        final pulse = (sin(t * 0.1) * 0.3 + 0.7);
        canvas.drawRRect(slotRect,
          Paint()..color = col.withOpacity(0.9 * pulse)..style = PaintingStyle.stroke..strokeWidth = 2.5);
        // Bullet count bar at bottom of slot — all types
        final maxAmmo = type == BulletType.normal ? 500.0 : type == BulletType.whirlgig ? 50.0 : 200.0;
        final frac = (g.normalBullets / 200.0).clamp(0.0, 1.0);
        final barY = y + _slotW - 8;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(slotX + 4, barY, _slotW - 8, 4), const Radius.circular(2)),
          Paint()..color = Colors.white.withOpacity(0.15));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(slotX + 4, barY, (_slotW - 8) * frac, 4), const Radius.circular(2)),
          Paint()..color = col.withOpacity(0.85));
      } else {
        canvas.drawRRect(slotRect,
          Paint()..color = Colors.white.withOpacity(hasAmmo ? 0.15 : 0.06)..style = PaintingStyle.stroke..strokeWidth = 1);
      }

      // Dim if locked or no ammo
      if (!unlocked || !hasAmmo) {
        canvas.drawRRect(slotRect, Paint()..color = Colors.black.withOpacity(0.6));
      }

      // Icon — lock icon if not yet unlocked
      if (!unlocked) {
        _drawText(canvas, '🔒', Offset(slotX + _slotW / 2, y + _slotW / 2 - 6), 18, color: Colors.white24);
        final req = type == BulletType.fire ? 5 : type == BulletType.laser ? 10 : 25;
        _drawText(canvas, 'LV$req', Offset(slotX + _slotW / 2, y + _slotW - 12), 9, color: Colors.white24);
      } else {
        _drawText(canvas, icons[i], Offset(slotX + _slotW / 2, y + _slotW / 2 - 6),
          isActive ? 22 : 18, color: hasAmmo ? Colors.white : Colors.white38);
        if (isActive) {
          _drawText(canvas, '${g.normalBullets}', Offset(slotX + _slotW / 2, y + _slotW - 12), 11,
            color: g.normalBullets > 0 ? col : Colors.white24, bold: true);
        }
      }

    }
  }

  // ── Overlays ──────────────────────────────────────────────────────────────
  void _drawMenu(Canvas canvas, Size size) {
    final W = size.width; final H = size.height;
    _drawText(canvas, '🚀 BULLET BLAST', Offset(W / 2, H * 0.28), 28, color: Colors.white, bold: true);
    _drawText(canvas, 'Touch & hold to fire', Offset(W / 2, H * 0.38), 16, color: const Color(0xFF88AAFF));
    _drawText(canvas, 'Destroy all bricks before', Offset(W / 2, H * 0.45), 14, color: Colors.white70);
    _drawText(canvas, 'they reach the paddle!', Offset(W / 2, H * 0.50), 14, color: Colors.white70);
    _drawText(canvas, '🔥 Fire  ⚡ Laser  🌀 Whirlgig', Offset(W / 2, H * 0.58), 13, color: const Color(0xFFFFE135));
    _drawText(canvas, 'TAP TO START', Offset(W / 2, H * 0.7), 20, color: const Color(0xFF00FFFF), bold: true);
    if (g.best > 0) _drawText(canvas, 'BEST: ${g.best}', Offset(W / 2, H * 0.78), 14, color: const Color(0xFFFFE135));
  }

  void _drawPauseOverlay(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.55));
    _drawText(canvas, 'PAUSED', Offset(size.width / 2, size.height * 0.45), 28, color: Colors.white, bold: true);
    _drawText(canvas, 'TAP TO RESUME', Offset(size.width / 2, size.height * 0.55), 16, color: const Color(0xFF00FFFF));
  }

  void _drawBossCountdown(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withOpacity(0.7));
    _drawText(canvas, '⚠ LEVEL ${g.level} ⚠', Offset(size.width / 2, size.height * 0.38), 26, color: const Color(0xFFFF4444), bold: true);
    _drawText(canvas, 'INCOMING WAVE', Offset(size.width / 2, size.height * 0.48), 18, color: Colors.white);
    final secs = ((g.bossCountdownT / 60) + 1).floor();
    _drawText(canvas, '$secs', Offset(size.width / 2, size.height * 0.60), 48, color: const Color(0xFFFFE135), bold: true);
  }

  void _drawClearOverlay(Canvas canvas, Size size) {
    final W = size.width; final H = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.black.withOpacity(0.6));
    _drawText(canvas, 'WAVE CLEAR!', Offset(W / 2, H * 0.35), 28, color: const Color(0xFF00FF88), bold: true);
    // Stars
    if (g.showStarAnimation) {
      final stars = g.lastLevelStars;
      for (int i = 0; i < 3; i++) {
        final filled = i < stars;
        final starX = W / 2 + (i - 1) * 44.0;
        final starY = H * 0.47;
        _drawText(canvas, filled ? '★' : '☆', Offset(starX, starY), 28,
          color: filled ? const Color(0xFFFFE135) : Colors.white30);
      }
    }
    _drawText(canvas, 'Score: ${g.score}', Offset(W / 2, H * 0.58), 16, color: Colors.white70);
    _drawText(canvas, 'TAP TO CONTINUE', Offset(W / 2, H * 0.68), 18, color: const Color(0xFF00FFFF), bold: true);
  }

  void _drawDeadOverlay(Canvas canvas, Size size) {
    final W = size.width; final H = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = Colors.black.withOpacity(0.75));

    // Title — different message if out of bullets
    final title = g.gameOverByBullets ? 'OUT OF BULLETS!' : 'GAME OVER';
    final titleColor = g.gameOverByBullets ? const Color(0xFFFFAA00) : const Color(0xFFFF2244);
    _drawText(canvas, title, Offset(W / 2, H * 0.32), 28, color: titleColor, bold: true);

    // Subtitle reason
    if (g.gameOverByBullets) {
      _drawText(canvas, 'All 3 lives exhausted', Offset(W / 2, H * 0.41), 14, color: Colors.white54);
    }

    _drawText(canvas, 'Score: ${g.score}', Offset(W / 2, H * 0.48), 18, color: Colors.white);
    if (g.score >= g.best && g.score > 0) {
      _drawText(canvas, '🏆 NEW BEST!', Offset(W / 2, H * 0.56), 16, color: const Color(0xFFFFE135), bold: true);
    } else if (g.best > 0) {
      _drawText(canvas, 'Best: ${g.best}', Offset(W / 2, H * 0.56), 14, color: Colors.white54);
    }
    _drawText(canvas, 'TAP TO PLAY AGAIN', Offset(W / 2, H * 0.67), 18, color: const Color(0xFF00FFFF), bold: true);
  }

  // ── Special brick mark — fast single letter, no emoji ───────────────────
  static final _markPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;
  void _drawSpecialMark(Canvas canvas, double bx, double by, double bw, double bh, Color color, String letter) {
    _markPaint.color = color.withOpacity(0.9);
    // Small circle in center
    final cx = bx + bw / 2; final cy = by + bh / 2;
    canvas.drawCircle(Offset(cx, cy), bh * 0.28, _markPaint);
    // Letter inside
    _drawText(canvas, letter, Offset(cx, cy), 8, color: color, bold: true);
  }

  // ── Text helper — single reused TextPainter instance ─────────────────────
  static final _tp = TextPainter(textDirection: TextDirection.ltr);
  void _drawText(Canvas canvas, String text, Offset center, double size,
      {Color color = Colors.white, bool bold = false}) {
    _tp.text = TextSpan(text: text, style: TextStyle(
      color: color, fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontFamily: 'monospace',
    ));
    _tp.layout();
    _tp.paint(canvas, center - Offset(_tp.width / 2, _tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
