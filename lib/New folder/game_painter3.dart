import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'game_controller.dart';
import 'game_models.dart';


class GamePainter extends CustomPainter {
  final GameController g;
  final double animTime;

  // Cached grid picture — drawn once, replayed every frame
  ui.Picture? _gridPicture;
  double _gridW = 0, _gridH = 0;

  // Cached gradients — created once, reused every frame
  static const _ballGradientNormal = RadialGradient(
    center: Alignment(-0.3, -0.3),
    colors: [Colors.white, Color(0xFF00E5FF), Color(0xFF0055AA)],
    stops: [0.0, 0.4, 1.0],
  );
  static const _ballGradientFire = RadialGradient(
    center: Alignment(-0.3, -0.3),
    colors: [Colors.white, Color(0xFFFF8800), Color(0xFFFF2200)],
    stops: [0.0, 0.4, 1.0],
  );
  static const _laserStarGradient = RadialGradient(
    colors: [Colors.white, Color(0xFFFFE500), Color(0xFFFF6600)],
    stops: [0.0, 0.5, 1.0],
  );

  GamePainter(this.g, this.animTime);

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    // Animated background
    _drawAnimatedBackground(canvas, W, H, animTime);

    // Last-life red pulse overlay
    if (g.lives == 1 && g.state == GameState.playing) {
      final pulse = sin(g.lastLifePulseT * 0.12) * 0.5 + 0.5;
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H),
          Paint()..color = const Color(0xFFCC0000).withOpacity(0.18 * pulse));
      // Red border vignette
      canvas.drawRect(Rect.fromLTWH(0, 0, W, H),
        Paint()
          ..color = const Color(0xFFFF0000).withOpacity(0.5 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);
    }

    // Grid hidden — background is now animated cosmic scene

    // Bricks
    for (int i = 0; i < g.bricks.length; i++) {
  final b = g.bricks[i];
  if (b.alive) _drawBrick(canvas, b, isCenter: i == g.centerBrickIndex);
}
    // Particles
    for (final p in g.particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.r * p.life,
        Paint()..color = p.color.withOpacity(p.life),
      );
    }

    // Drops
    for (final d in g.drops) {
      _drawDrop(canvas, d);
    }

// ── ADD THIS LASER RAYS BLOCK HERE ──
for (final ray in g.laserRays) {
  final opacity = ray['life']!.clamp(0.0, 1.0);
  final p1 = Offset(ray['x1']!, ray['y1']!);
  final p2 = Offset(ray['x2']!, ray['y2']!);
  // Middle beam (no blur — too expensive per ray)
  canvas.drawLine(p1, p2, Paint()
      ..color = const Color(0xFFFF00FF).withOpacity(opacity * 0.8)
      ..strokeWidth = 3);
  // White core
  canvas.drawLine(p1, p2, Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1.5);
}
// ── END LASER RAYS BLOCK ──

/* FLOWERPOT DRAWING DISABLED
if (g.flowerpotActive) { ... }
*/
// Whirlgig fireworks
if (g.whirlgigActive) {
  for (final p in g.whirlgigParticles) {
    if (!(p['active'] as bool)) continue;
    final life = p['life'] as double;
    final r = (p['r'] as double) * life;
    final color = Color(p['color'] as int).withOpacity(life.clamp(0.0, 1.0));

    // Core (no per-particle blur — expensive on low-end)
    canvas.drawCircle(
      Offset(p['x'] as double, p['y'] as double),
      r,
      Paint()..color = color,
    );
  }

  // Center glow burst
  final burstOpacity = (g.whirlgigT / 180.0).clamp(0.0, 1.0);
  canvas.drawCircle(
    Offset(g.whirlgigX, g.whirlgigY),
    80 * burstOpacity,
    Paint()
      ..color = Colors.white.withOpacity(burstOpacity * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
  );
}
    // Laser star (drawn before balls so star appears on top)
    _drawLaserStar(canvas, g, W, H);

    // Balls
    for (final b in g.balls) {
  _drawBall(canvas, b, animTime);
}

    // Bullets
    for (final b in g.bullets) {
      final bx = b['x']!;
      final by = b['y']!;
      // Core bullet (no blur — capped at 12 max)
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx - 3, by - 8, 6, 14), const Radius.circular(3)),
        Paint()..color = const Color(0xFFFFFF00));
      // Bright tip
      canvas.drawCircle(Offset(bx, by - 8), 3,
          Paint()..color = Colors.white);
    }

    // Paddle
    _drawPaddle(canvas, g);

    // HUD
    _drawHUD(canvas, g, W, H);

  // Pause overlay
if (g.state == GameState.paused) {
  // Dim background
  canvas.drawRect(
    Rect.fromLTWH(0, 0, W, H),
    Paint()..color = Colors.black.withOpacity(0.6),
  );
  // Pause panel
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(W * 0.15, H * 0.3, W * 0.7, H * 0.35),
      const Radius.circular(20),
    ),
    Paint()..color = const Color(0xFF1A1A2E),
  );
  // Border
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(W * 0.15, H * 0.3, W * 0.7, H * 0.35),
      const Radius.circular(20),
    ),
    Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  _drawText(canvas, '⏸ PAUSED', Offset(W / 2, H * 0.38), 24,
      color: Colors.white, bold: true);
  _drawText(canvas, 'TAP TO RESUME', Offset(W / 2, H * 0.48), 14,
      color: const Color(0xFF00E5FF));
  _drawText(canvas, 'SCORE: ${g.score}', Offset(W / 2, H * 0.56), 13,
      color: Colors.white54);
}

    // Combo text
    if (g.combo > 1 && g.comboTimer > 0) {
      final opacity = (g.comboTimer / 30).clamp(0.0, 1.0);
      final fontSize = min(20.0 + g.combo * 3, 48.0);
      _drawText(canvas, '${g.combo}x COMBO!',
          Offset(W / 2, H / 2 - 40), fontSize,
          color: const Color(0xFFFFE135).withOpacity(opacity),
          bold: true);
    }

    // Lucky save popup
    if (g.luckyT > 0) {
      final fade = (g.luckyT / 90.0).clamp(0.0, 1.0);
      final scale = fade < 0.2 ? fade / 0.2 : 1.0; // pop in
      _drawText(canvas, '🍀 LUCKY SAVE!', Offset(W / 2, H * 0.42),
          22 * scale, color: const Color(0xFF00FF88).withOpacity(fade), bold: true);
    }

    // Overlays
    if (g.state == GameState.menu) {
      _drawOverlay(canvas, W, H, 'BRICK BLAST', 'Tap to Play!',
          const Color(0xFFFF3E6C), animTime);
    } else if (g.state == GameState.dead) {
      _drawOverlay(canvas, W, H, 'GAME OVER',
          'Score: ${g.score}   Tap to Retry', const Color(0xFFFF3E6C), animTime);
    } else if (g.state == GameState.clear) {
      _drawStarScreen(canvas, g, W, H, animTime);
    }

    // Level intro flash
    if (g.state == GameState.playing && g.levelFrameCount < 90) {
      final fade = 1.0 - (g.levelFrameCount / 90.0);
      _drawText(canvas, 'LEVEL ${g.level}', Offset(W / 2, H / 2 - 20), 36,
          color: const Color(0xFFFFE135).withOpacity(fade), bold: true);
      _drawText(canvas, 'GET READY!', Offset(W / 2, H / 2 + 24), 18,
          color: Colors.white.withOpacity(fade), bold: true);
    }

    // Boss countdown overlay
    if (g.bossCountdownActive) {
      _drawBossCountdown(canvas, g, W, H, animTime);
    }
  }


  void _drawStarScreen(Canvas canvas, GameController g, double W, double H, double animTime) {
    // starAnimT counts DOWN from 120 to 0
    // We use it to sequence row appearances
    final elapsed = 120 - g.starAnimT; // 0→120 as time goes on

    final cx = W / 2;
   const rowH = 44.0;
    const panelH = rowH * 3 + 90.0;
    final topY = (H - panelH) / 2 + 30;
    const starR = 13.0;
    const innerR = 5.5;

    // Dark panel background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(W * 0.06, topY - 50, W * 0.88, rowH * 3 + 150),
        const Radius.circular(24)),
      Paint()..color = Colors.black.withOpacity(0.95));

    // Title
    final titleLabel = g.lastLevelStars == 3
        ? '✨ PERFECT! ✨'
        : g.lastLevelStars == 2 ? '🎉 GREAT!' : '✅ CLEARED!';
    final titleColor = g.lastLevelStars == 3
        ? const Color(0xFFFFE135)
        : g.lastLevelStars == 2 ? const Color(0xFF00FF88) : Colors.white;
    _drawText(canvas, titleLabel, Offset(cx, topY - 15), 16,
        color: titleColor, bold: true);

    // Row definitions
    final rowData = [
      (label: 'Level Cleared',  earned: true),
      (label: 'No Lives Lost',  earned: g.perfectClear),
      (label: 'Under 30 Secs', earned: g.levelFrameCount < 30 * 60),
    ];

    // Each row appears every 30 frames: row0 at t=20, row1 at t=50, row2 at t=80
    for (int i = 0; i < 3; i++) {
      final appearAt = 20 + i * 30;
      if (elapsed < appearAt) continue;

      final rowElapsed = (elapsed - appearAt).clamp(0, 25);
      final t = rowElapsed / 25.0; // 0→1
      final rowY = topY + 30 + i * rowH;
      final earned = rowData[i].earned;

      // Slide in from left
      final slideOffset = (1.0 - t) * W * 0.5;
      canvas.save();
      canvas.translate(-slideOffset, 0);
      canvas.clipRect(Rect.fromLTWH(0, 0, W, H));

      // Star bounce scale
      double scale;
      if (t < 0.6) {
        scale = t / 0.6 * 1.3;
      } else {
        scale = 1.3 - (t - 0.6) / 0.4 * 0.3;
      }
      final sz = starR * scale.clamp(0.0, 1.5);

      // Star position: left side
      final starX = cx - W * 0.28;

      // Draw star shape
      final path = Path();
      for (int j = 0; j < 10; j++) {
        final r = j.isEven ? sz : innerR * scale.clamp(0.0, 1.5);
        final a = (j / 10.0) * 3.14159 * 2 - 3.14159 / 2;
        final px = starX + cos(a) * r;
        final py = rowY + sin(a) * r;
        j == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      path.close();

      if (earned) {
        // Outer glow
        canvas.drawPath(path, Paint()
          ..color = const Color(0xFFFFE500).withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        // Base yellow fill
        canvas.drawPath(path, Paint()..color = const Color(0xFFFFD700));
        // Glossy gradient overlay
        canvas.drawPath(path, Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.9),
              const Color(0xFFFFE500).withOpacity(0.8),
              const Color(0xFFFFB800),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(starX, rowY), radius: starR)));
        // Bright border
        canvas.drawPath(path, Paint()
          ..color = const Color(0xFFFFF176)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        // Empty star
        canvas.drawPath(path, Paint()..color = Colors.white10);
        canvas.drawPath(path, Paint()
          ..color = Colors.white30
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }

      // Label
     _drawText(canvas, rowData[i].label, Offset(cx + 14, rowY), 11,
          color: earned ? Colors.white : Colors.white38, bold: earned);

      // Tick or cross
      _drawText(canvas, earned ? '✓' : '✗',
          Offset(cx + W * 0.33, rowY), 11,
          color: earned ? const Color(0xFF00FF88) : Colors.white24, bold: true);

      canvas.restore();
    }

    // Tap to continue — appears after all rows shown
    if (elapsed >= 95) {
      final pulse = sin(animTime * 4) * 0.3 + 0.7;
      _drawText(canvas, '▶  TAP TO CONTINUE TO LEVEL > ${g.level + 1}',
          Offset(cx, topY + 30 + 3 * rowH + 10), 17,
          color: const Color(0xFF00E5FF).withOpacity(pulse), bold: true);
    }
  }


  void _drawBossCountdown(Canvas canvas, GameController g, double W, double H, double animTime) {
    final t = g.bossCountdownT; // 180 → 0
    final cx = W / 2;
    final cy = H / 2;

    // Full screen red flash background
    final bgOpacity = (sin(animTime * 6) * 0.15 + 0.55).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H),
        Paint()..color = const Color(0xFFCC0000).withOpacity(bgOpacity));

    // Pulsing red border
    final borderPulse = sin(animTime * 8) * 0.5 + 0.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H),
      Paint()
        ..color = const Color(0xFFFF0000).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + borderPulse * 6);

    // BOSS LEVEL label
    _drawText(canvas, '👾 BOSS LEVEL 👾', Offset(cx, cy - 110), 22,
        color: Colors.white, bold: true);
    _drawText(canvas, 'LEVEL ${g.level}', Offset(cx, cy - 75), 16,
        color: const Color(0xFFFF6666));

    // Countdown number (3, 2, 1)
    final countNum = (t / 60).ceil().clamp(1, 3); // 3 for t=180-121, 2 for 120-61, 1 for 60-1
    final frameInCount = t % 60 == 0 ? 60 : t % 60; // 1→60 within each second
    final scale = 1.0 + (1.0 - frameInCount / 60.0) * 0.8; // big when number appears, shrinks
    final numOpacity = (frameInCount / 60.0).clamp(0.3, 1.0);

    // Number glow
    final numStr = '$countNum';
    _drawTextScaled(canvas, numStr, Offset(cx, cy), 90 * scale,
        color: const Color(0xFFFFE135).withOpacity(numOpacity),
        bold: true);

    // x3 SCORE label
    _drawText(canvas, '✦ SCORE x3 MULTIPLIER ✦', Offset(cx, cy + 80), 14,
        color: const Color(0xFFFFE135).withOpacity(0.9), bold: true);

    // Warning stripes at bottom
    _drawText(canvas, '⚠  PREPARE YOURSELF  ⚠', Offset(cx, cy + 110), 13,
        color: Colors.white.withOpacity(0.8));

    // Progress bar showing time left
    final progress = t / 180.0;
    canvas.drawRect(
      Rect.fromLTWH(W * 0.1, H - 60, W * 0.8, 8),
      Paint()..color = Colors.white.withOpacity(0.2));
    canvas.drawRect(
      Rect.fromLTWH(W * 0.1, H - 60, W * 0.8 * progress, 8),
      Paint()..color = const Color(0xFFFF3333));
  }

  void _drawTextScaled(Canvas canvas, String text, Offset center, double fontSize,
      {Color color = Colors.white, bool bold = false}) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        shadows: [
          Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 12, offset: const Offset(2, 2)),
          Shadow(color: color.withOpacity(0.5), blurRadius: 20),
        ],
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }


  void _drawAnimatedBackground(Canvas canvas, double W, double H, double t) {
    final p = Paint();

    // ── Deep space base gradient (deep blue → deep purple → near-black) ──
    final bgShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF04041A), // top: near-black deep blue
        Color(0xFF0D0628), // mid: deep indigo
        Color(0xFF150322), // bottom: deep purple-black
      ],
      stops: [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, W, H));
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..shader = bgShader);

    // ── Milky Way band — diagonal glowing swath ──
    final mwDrift = sin(t * 0.05) * H * 0.02;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(W * 0.5, H * 0.38 + mwDrift), width: W * 1.8, height: H * 0.28),
      Paint()
        ..color = const Color(0xFF2A1650).withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(W * 0.45, H * 0.36 + mwDrift), width: W * 1.4, height: H * 0.14),
      Paint()
        ..color = const Color(0xFF5B2D8A).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35),
    );
    // Bright core of Milky Way
    canvas.drawOval(
      Rect.fromCenter(center: Offset(W * 0.5, H * 0.37 + mwDrift), width: W * 0.7, height: H * 0.055),
      Paint()
        ..color = const Color(0xFFB896FF).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // ── Nebula color clouds ──
    final nebulae = [
      // (cx, cy, rx, ry, color, speedX, speedY, opacity)
      (W*0.15, H*0.18, W*0.42, H*0.22, const Color(0xFF1A0A5C), 0.03, 0.02, 0.50),
      (W*0.82, H*0.30, W*0.38, H*0.20, const Color(0xFF0A1A5C), 0.04, 0.03, 0.45),
      (W*0.50, H*0.65, W*0.55, H*0.25, const Color(0xFF2E0A4A), 0.02, 0.04, 0.40),
      (W*0.25, H*0.75, W*0.35, H*0.18, const Color(0xFF003366), 0.05, 0.02, 0.35),
      (W*0.75, H*0.80, W*0.40, H*0.20, const Color(0xFF1A004D), 0.03, 0.05, 0.38),
    ];
    for (final n in nebulae) {
      final dx = sin(t * n.$6 + n.$1) * W * 0.03;
      final dy = cos(t * n.$7 + n.$2) * H * 0.025;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(n.$1 + dx, n.$2 + dy), width: n.$3, height: n.$4),
        Paint()
          ..color = n.$5.withOpacity(n.$8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
      );
    }

    // ── Sparkling star field — 3 layers (distant, mid, close) ──
    for (int layer = 0; layer < 3; layer++) {
      final count  = [80, 40, 15][layer];
      final speed  = [4.0, 10.0, 22.0][layer];   // zoom speed
      final maxSz  = [1.2, 2.0, 3.2][layer];
      final bright = [180, 210, 255][layer];

      for (int i = 0; i < count; i++) {
        final seed = i * 2.7183 + layer * 31.4 + 1.4142;
        final baseX = ((seed * 73.1) % 1.0) * W;
        final baseY = ((seed * 31.7) % 1.0) * H;
        final sz    = maxSz * (0.4 + ((seed * 53.9) % 1.0) * 0.6);
        final twinklePhase = (seed * 11.1) % 6.28;

        // Zoom toward viewer — stars drift outward from center
        final zoomT = (t * speed * 0.004) % 1.0;
        final fromCx = baseX - W / 2;
        final fromCy = baseY - H / 2;
        final x = W / 2 + fromCx * (1 + zoomT * 0.4);
        final y = H / 2 + fromCy * (1 + zoomT * 0.4);
        if (x < 0 || x > W || y < 0 || y > H) continue;

        final twinkle = sin(t * 1.8 + twinklePhase) * 0.35 + 0.65;
        final alpha = (twinkle * bright).toInt().clamp(0, 255);

        final tint = i % 6;
        final Color sc;
        if      (tint == 0) sc = Color.fromARGB(alpha, 160, 200, 255); // blue-white
        else if (tint == 1) sc = Color.fromARGB(alpha, 255, 210, 180); // warm gold
        else if (tint == 2) sc = Color.fromARGB(alpha, 200, 160, 255); // violet
        else                sc = Color.fromARGB(alpha, 230, 230, 255); // pure white

        p.color = sc;
        canvas.drawCircle(Offset(x, y), sz, p);

        // Close stars get a cross-sparkle
        if (layer == 2) {
          p.color = sc.withOpacity(0.5);
          canvas.drawLine(Offset(x - sz*2.5, y), Offset(x + sz*2.5, y), p..strokeWidth = 0.8);
          canvas.drawLine(Offset(x, y - sz*2.5), Offset(x, y + sz*2.5), p..strokeWidth = 0.8);
        }
      }
    }

    // ── Floating planets ──
    // Each entry: (cx, cy, radius, color1, color2, orbitR, orbitSpeed)
    final planets = [
      (W*0.78, H*0.15, 22.0, const Color(0xFF7B3FBF), const Color(0xFF3A1A7A), W*0.015, 0.12),
      (W*0.18, H*0.32, 14.0, const Color(0xFF1A6BB5), const Color(0xFF0D3A6B), W*0.012, 0.09),
      (W*0.88, H*0.55, 32.0, const Color(0xFF9C5500), const Color(0xFF5C2D00), W*0.018, 0.07),
      (W*0.10, H*0.72, 18.0, const Color(0xFF2A8A4A), const Color(0xFF0A4A20), W*0.010, 0.14),
      (W*0.65, H*0.82, 11.0, const Color(0xFFAA4466), const Color(0xFF661A33), W*0.008, 0.18),
    ];
    // Which planet index has a ring
    const ringPlanetIndex = 2;

    for (int pi = 0; pi < planets.length; pi++) {
      final pl = planets[pi];
      final orbitSpeed = pl.$7;
      final orbitR     = pl.$6;
      final ox = sin(t * orbitSpeed) * orbitR;
      final oy = cos(t * orbitSpeed * 0.7) * orbitR * 0.5;
      final px = pl.$1 + ox;
      final py = pl.$2 + oy;
      final r  = pl.$3;

      // Planet glow aura
      canvas.drawCircle(Offset(px, py), r * 1.7,
        Paint()
          ..color = pl.$4.withOpacity(0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

      // Planet body gradient
      final planetShader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: [pl.$4.withOpacity(1.0), pl.$5],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(px, py), radius: r));
      canvas.drawCircle(Offset(px, py), r, Paint()..shader = planetShader);

      // Atmosphere rim
      canvas.drawCircle(Offset(px, py), r,
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18);

      // Ring (Saturn-like) for designated planet
      if (pi == ringPlanetIndex) {
        canvas.save();
        canvas.translate(px, py);
        canvas.scale(1.0, 0.28);
        canvas.drawCircle(Offset.zero, r * 1.75,
          Paint()
            ..color = const Color(0xFFD4A855).withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.55);
        canvas.restore();
      }

      // Surface highlight
      canvas.drawCircle(Offset(px - r*0.3, py - r*0.3), r * 0.25,
        Paint()..color = Colors.white.withOpacity(0.18));
    }

    // ── Reflective neon road at bottom ──
    final roadY = H * 0.88;
    // Road gradient — glowing neon surface
    final roadShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF6600FF).withOpacity(0.0),
        const Color(0xFF6600FF).withOpacity(0.22),
        const Color(0xFF00CCFF).withOpacity(0.28),
      ],
    ).createShader(Rect.fromLTWH(0, roadY, W, H - roadY));
    canvas.drawRect(Rect.fromLTWH(0, roadY, W, H - roadY), Paint()..shader = roadShader);

    // Neon horizon line
    canvas.drawLine(
      Offset(0, roadY),
      Offset(W, roadY),
      Paint()
        ..color = const Color(0xFF00CCFF).withOpacity(0.6)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Road grid lines converging to vanishing point
    final vp = Offset(W / 2, roadY); // vanishing point
    for (int i = 0; i < 7; i++) {
      final spread = (i - 3) * W * 0.18;
      final roadLinePhase = (t * 0.3 + i * 0.15) % 1.0;
      final alpha = (0.12 + roadLinePhase * 0.2).clamp(0.0, 0.35);
      canvas.drawLine(
        Offset(vp.dx + spread * 0.08, roadY + 2),
        Offset(vp.dx + spread, H),
        Paint()
          ..color = const Color(0xFF8844FF).withOpacity(alpha)
          ..strokeWidth = 0.8,
      );
    }

    // ── Shooting star every ~10 seconds ──
    final sCycle = t % 10.0;
    if (sCycle < 1.4) {
      final prog = sCycle / 1.4;
      final sx1 = W * 0.05;  final sy1 = H * 0.08;
      final sx2 = W * 0.65;  final sy2 = H * 0.42;
      final cx2 = sx1 + (sx2 - sx1) * prog;
      final cy2 = sy1 + (sy2 - sy1) * prog;
      final tx  = sx1 + (sx2 - sx1) * (prog - 0.2).clamp(0, 1);
      final ty  = sy1 + (sy2 - sy1) * (prog - 0.2).clamp(0, 1);
      final sOp = prog < 0.12 ? prog/0.12 : prog > 0.78 ? (1-prog)/0.22 : 1.0;
      // Glow tail
      canvas.drawLine(Offset(tx, ty), Offset(cx2, cy2),
        Paint()
          ..color = const Color(0xFF88AAFF).withOpacity(sOp * 0.5)
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      // Core
      canvas.drawLine(Offset(tx, ty), Offset(cx2, cy2),
        Paint()
          ..color = Colors.white.withOpacity(sOp)
          ..strokeWidth = 1.2);
      canvas.drawCircle(Offset(cx2, cy2), 2.8,
          Paint()..color = Colors.white.withOpacity(sOp));
    }
  }

  void _drawGrid(Canvas canvas, double W, double H) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    for (double x = 0; x < W; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, H), paint);
    }
    for (double y = 0; y < H; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(W, y), paint);
    }
  }

void _drawBrick(Canvas canvas, Brick b, {bool isCenter = false}) {    final rng = Random();
    final ox = b.shakeFrames > 0 ? (rng.nextDouble() - 0.5) * 4 : 0.0;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(b.x + ox, b.y, b.w, b.h),
      const Radius.circular(6),
    );

    // Main fill
    canvas.drawRRect(rect, Paint()..color = b.color);

// Main fill
canvas.drawRRect(rect, Paint()..color = b.color);

// Center brick special glow
if (isCenter) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(b.x + ox - 3, b.y - 3, b.w + 6, b.h + 6),
      const Radius.circular(9),
    ),
    Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  _drawText(canvas, '★', Offset(b.x + ox + b.w / 2, b.y + b.h / 2), 12,
      color: Colors.white, bold: true);
}
    // Shine
    
    // Shine
final shineRect = RRect.fromRectAndRadius(
  Rect.fromLTWH(b.x + ox + 3, b.y + 3, b.w - 6, b.h * 0.38),
  const Radius.circular(3),
);
canvas.drawRRect(
  shineRect,
  Paint()..color = Colors.white.withOpacity(0.22),
);

/* FLOWERPOT BRICK ICON DISABLED
if (b.hiddenPower == PowerupType.flowerpot) { ... }
*/
    // HP bar
    if (b.maxHp > 1) {
      canvas.drawRect(
        Rect.fromLTWH(b.x + ox + 2, b.y + b.h - 6, b.w - 4, 4),
        Paint()..color = Colors.black.withOpacity(0.5),
      );
      canvas.drawRect(
        Rect.fromLTWH(b.x + ox + 2, b.y + b.h - 6, (b.w - 4) * (b.hp / b.maxHp), 4),
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawBall(Canvas canvas, Ball b, double animTime) {
  // Laser ball is fully hidden — star handles all drawing
  if (b.laser) return;

  final Color trailColor = b.fire
      ? const Color(0xFFFF6600)
      : const Color(0xFF00E5FF);
  final Color glowColor = b.fire
      ? const Color(0xFFFF4400)
      : const Color(0xFF00FFFF);

  // Trail
  for (int i = 0; i < b.trail.length; i++) {
    final t = b.trail[i];
    final frac = i / b.trail.length;
    canvas.drawCircle(t, b.r * frac,
        Paint()..color = trailColor.withOpacity(frac * 0.4));
  }

  // Outer glow
  canvas.drawCircle(Offset(b.x, b.y), b.r + 8,
      Paint()
        ..color = glowColor.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

  // Ball gradient — use cached gradient, only createShader (cheap rect math only)
  final gradient = b.fire ? _ballGradientFire : _ballGradientNormal;
  final paint = Paint()
    ..shader = gradient.createShader(
        Rect.fromCircle(center: Offset(b.x, b.y), radius: b.r));
  canvas.drawCircle(Offset(b.x, b.y), b.r, paint);
}
  

  void _drawLaserStar(Canvas canvas, GameController g, double W, double H) {
  // Find the laser ball — use its position so star moves with it
  Ball? laserBall;
  for (final b in g.balls) {
    if (b.laser) { laserBall = b; break; }
  }
  if (laserBall == null) return;

  final cx = laserBall.x;
  final cy = laserBall.y;
  final spinAngle = g.laserSpinAngle;
  const rayCount = 8;
  const starR = 14.0;  // half size
  const innerR = 5.5;

  // 8 spinning rays from star position to screen edges
  for (int i = 0; i < rayCount; i++) {
    final angle = spinAngle + (i / rayCount) * pi * 2;
    final dx = cos(angle);
    final dy = sin(angle);
    final endX = cx + dx * 900;
    final endY = cy + dy * 900;
    canvas.drawLine(Offset(cx, cy), Offset(endX, endY),
      Paint()
        ..color = const Color(0xFFFFE500).withOpacity(0.12)
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawLine(Offset(cx, cy), Offset(endX, endY),
      Paint()
        ..color = const Color(0xFFFFE500).withOpacity(0.55)
        ..strokeWidth = 2.0);
    canvas.drawLine(Offset(cx, cy), Offset(endX, endY),
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..strokeWidth = 0.8);
  }

  // Spinning 5-pointed star
  final starPath = Path();
  const points = 5;
  for (int i = 0; i < points * 2; i++) {
    final r = i.isEven ? starR : innerR;
    final a = spinAngle + (i / (points * 2)) * pi * 2 - pi / 2;
    final px = cx + cos(a) * r;
    final py = cy + sin(a) * r;
    i == 0 ? starPath.moveTo(px, py) : starPath.lineTo(px, py);
  }
  starPath.close();

  // Star trail
  for (int t = 0; t < laserBall.trail.length; t++) {
    final tp = laserBall.trail[t];
    final frac = t / laserBall.trail.length;
    canvas.drawCircle(tp, 4 * frac,
      Paint()..color = const Color(0xFFFFE500).withOpacity(frac * 0.5));
  }

  canvas.drawPath(starPath,
    Paint()
      ..color = const Color(0xFFFFE500).withOpacity(0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  canvas.drawPath(starPath,
    Paint()
      ..shader = _laserStarGradient.createShader(
          Rect.fromCircle(center: Offset(cx, cy), radius: starR)));
  canvas.drawPath(starPath,
    Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

  final pulse = sin(g.laserSpinAngle * 5) * 0.3 + 0.7;
  canvas.drawCircle(Offset(cx, cy), 5 * pulse,
    Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  canvas.drawCircle(Offset(cx, cy), 3 * pulse, Paint()..color = Colors.white);
}

  void _drawPaddle(Canvas canvas, GameController g) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(g.padX, g.padY, g.padW, g.padH),
      const Radius.circular(8),
    );

    // Paddle skin colors
    // 0=neon(cyan), 1=fire(orange), 2=ice(light blue), 3=gold
    final skinColors = [
      [const Color(0xFF00FFFF), const Color(0xFF00E5FF)], // neon
      [const Color(0xFFFF6600), const Color(0xFFFF3300)], // fire
      [const Color(0xFFAAEEFF), const Color(0xFF66CCFF)], // ice
      [const Color(0xFFFFE135), const Color(0xFFFFAA00)], // gold
    ];
    final skinGlow = [
      const Color(0xFF00FFFF),
      const Color(0xFFFF4400),
      const Color(0xFF88DDFF),
      const Color(0xFFFFE135),
    ];
    final s = g.paddleSkin.clamp(0, 3);
    final glowColor = skinGlow[s];
    final fillColor = skinColors[s][1];

    // Glow
    canvas.drawRRect(rect,
      Paint()
        ..color = glowColor.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Main fill
    canvas.drawRRect(rect, Paint()..color = fillColor);

    // Shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(g.padX + 6, g.padY + 3, g.padW - 12, 4),
        const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.55));

    // Border
    canvas.drawRRect(rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);

    // Gun glow on paddle
    if (g.puGun) {
      final gunPulse = sin(g.puGunT * 0.2) * 0.4 + 0.6;
      // Yellow cannons on left and right
      final lx = g.padX + 4;
      final rx = g.padX + g.padW - 10;
      final cy = g.padY - 6;
      for (final cx in [lx, rx]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx, cy - 8, 6, 10), const Radius.circular(2)),
          Paint()..color = const Color(0xFFFFDD00));
        canvas.drawCircle(Offset(cx + 3, cy - 8), 5,
          Paint()..color = const Color(0xFFFFFF00).withOpacity(0.6 * gunPulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      // Paddle yellow glow
      canvas.drawRRect(rect,
        Paint()
          ..color = const Color(0xFFFFDD00).withOpacity(0.35 * gunPulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      _drawText(canvas, '🔫', Offset(g.padX + g.padW / 2, g.padY - 18), 13,
          color: const Color(0xFFFFDD00).withOpacity(gunPulse));
    }

    // Magnet glow on paddle
    if (g.puMagnet) {
      final magnetPulse = sin(g.puMagnetT * 0.15) * 0.4 + 0.6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(g.padX - 6, g.padY - 6, g.padW + 12, g.padH + 12),
          const Radius.circular(12)),
        Paint()
          ..color = const Color(0xFFFF00FF).withOpacity(0.5 * magnetPulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawRRect(rect,
        Paint()
          ..color = const Color(0xFFFF00FF).withOpacity(0.3 * magnetPulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      // Magnet label
      _drawText(canvas, '🧲', Offset(g.padX + g.padW / 2, g.padY - 16), 13,
          color: const Color(0xFFFF00FF).withOpacity(magnetPulse));
    }
  }

  void _drawDrop(Canvas canvas, PowerupDrop d) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(d.x, d.y), width: d.w, height: d.h),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.black.withOpacity(0.7));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = d.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(canvas, d.label, Offset(d.x, d.y), 12, color: d.color, bold: true);
  }


void _drawHUD(Canvas canvas, GameController g, double W, double H) {
  const topPad = 50.0;

  // Score bar background
  canvas.drawRect(
    Rect.fromLTWH(0, topPad, W, 46),
    Paint()..color = Colors.black.withOpacity(0.6),
  );

  _drawText(canvas, 'SCORE: ${g.score}', const Offset(12, topPad + 18), 15,
      color: const Color(0xFF00E5FF), bold: true, align: TextAlign.left);
  _drawText(canvas, 'BEST: ${g.best}', const Offset(12, topPad + 36), 11,
      color: Colors.white54, align: TextAlign.left);
  _drawText(canvas, 'LEVEL ${g.level}', Offset(W / 2, topPad + 24), 15,
      color: Colors.white, bold: true);
  // Big heart with life count inside
  // Skin selector tap hint
  final skinEmoji = ['🔵','🔥','🧊','🏆'][g.paddleSkin];
  _drawText(canvas, skinEmoji, Offset(W - 108, topPad + 24), 16,
      color: Colors.white);

  _drawText(canvas, '❤', Offset(W - 70, topPad + 24), 26,
      color: const Color(0xFFFF4466), bold: true);
  _drawText(canvas, '${g.lives}', Offset(W - 70, topPad + 24), 12,
      color: Colors.white, bold: true);

  // Powerup strip below score bar
  _drawPowerupStrip(canvas, g, W, topPad + 48);
}

void _drawPowerupStrip(Canvas canvas, GameController g, double W, double stripY) {
  const stripH = 32.0;

  canvas.drawRect(
    Rect.fromLTWH(0, stripY, W, stripH),
    Paint()..color = Colors.black.withOpacity(0.5),
  );

  canvas.drawLine(
    Offset(0, stripY),
    Offset(W, stripY),
    Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1,
  );

  final items = [
  (label: '🔥', count: g.countFire,      active: g.puFire,         color: const Color(0xFFFF4444)),
  (label: '⬛', count: g.countBig,       active: g.puBig,          color: const Color(0xFF00E5FF)),
  (label: '✦',  count: g.countMulti,     active: g.puMulti,        color: const Color(0xFFFFE135)),
  (label: '↔',  count: g.countWide,      active: g.puWide,         color: const Color(0xFF00FF88)),
  (label: '⚡', count: g.countLaser,     active: g.puLaser,        color: const Color(0xFFFFE500)),
  // (label: '🌸', ...) // flowerpot disabled
  (label: '🧲', count: g.puMagnet ? 1 : 0, active: g.puMagnet,       color: const Color(0xFFFF00FF)),
  (label: '🔫', count: g.puGun   ? 1 : 0, active: g.puGun,          color: const Color(0xFFFFDD00)),
];

  final itemW = W / items.length;

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final cx = i * itemW + itemW / 2;
    final cy = stripY + stripH / 2;

    // Active glow background
    if (item.active) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * itemW + 3, stripY + 3, itemW - 6, stripH - 6),
          const Radius.circular(6),
        ),
        Paint()..color = item.color.withOpacity(0.25),
      );
    }

    // Icon
    _drawText(canvas, item.label, Offset(cx - 14, cy), 14,
        color: item.active ? item.color : Colors.white38);

    // Count badge
    
    // Count badge — show tick or cross
canvas.drawCircle(
  Offset(cx + 10, cy - 6),
  9,
  Paint()..color = item.count > 0
      ? const Color(0xFF00CC44)  // green = available
      : const Color(0xFFFF4444), // red = used up
);
_drawText(
  canvas,
  item.count > 0 ? '✓' : '✕',
  Offset(cx + 10, cy - 6),
  10,
  color: Colors.white,
  bold: true,
);

    // Active timer bar
    if (item.active) {
      double pct = 1.0;
      if (item.label == '🔥') pct = g.puFireT / puDuration;
      if (item.label == '⬛') pct = g.puBigT  / puDuration;
      if (item.label == '✦')  pct = g.puMultiT / puDuration;
      if (item.label == '↔')  pct = g.puWideT  / puDuration;
      if (item.label == '⚡') pct = g.puLaserT / puDuration;
      if (item.label == '🧲') pct = g.puMagnetT / 300;
      if (item.label == '🔫') pct = g.puGunT / 600;

      canvas.drawRect(
        Rect.fromLTWH(i * itemW + 3, stripY + stripH - 3, (itemW - 6) * pct, 3),
        Paint()..color = item.color,
      );
    }
  }
}
  
  

  void _drawOverlay(Canvas canvas, double W, double H,
      String title, String sub, Color color, double animTime) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()..color = Colors.black.withOpacity(0.82),
    );

    // Title with glow
    final glowPulse = 0.7 + sin(animTime * 3) * 0.3;
    canvas.drawCircle(
      Offset(W / 2, H / 2 - 50),
      min(W * 0.5, 160),
      Paint()
        ..color = color.withOpacity(0.08 * glowPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    _drawText(canvas, title, Offset(W / 2, H / 2 - 50),
        min(W * 0.13, 60), color: color, bold: true);
    _drawText(canvas, sub, Offset(W / 2, H / 2 + 14),
        min(W * 0.048, 20), color: Colors.white);

    final pulse = 0.85 + sin(animTime * 2) * 0.15;
    _drawText(canvas, '▶  TAP ANYWHERE TO START',
        Offset(W / 2, H / 2 + 62),
        min(W * 0.042, 18) * pulse,
        color: Colors.white54, bold: true);
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize, {
    Color color = Colors.white,
    bool bold = false,
    TextAlign align = TextAlign.center,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();

    Offset offset;
    if (align == TextAlign.left) {
      offset = Offset(center.dx, center.dy - tp.height / 2);
    } else if (align == TextAlign.right) {
      offset = Offset(center.dx - tp.width, center.dy - tp.height / 2);
    } else {
      offset = Offset(center.dx - tp.width / 2, center.dy - tp.height / 2);
    }
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
