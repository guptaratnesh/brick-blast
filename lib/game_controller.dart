import 'dart:math';
import 'package:flutter/material.dart';
import 'game_models.dart';
import 'sound_manager.dart';

enum GameState { menu, playing, paused, dead, clear }

class GameController extends ChangeNotifier {
  double screenW = 0;
  double screenH = 0;

  GameState state = GameState.menu;
  int score = 0;
  int best = 0;
  int lives = 3;
  int level = 1;
  int combo = 0;
  int comboTimer = 0;

  // Active bullet type
  BulletType activeBulletType = BulletType.normal;
  int normalBullets = 200;        // single shared bullet pool
  int lifeFlashTimer = 0;         // frames to flash screen when life lost
  bool gameOverByBullets = false; // true if game ended due to bullet exhaustion



  // Wide paddle powerup
  bool puWide = false;
  int puWideT = 0;

  // Brick descent
  double brickDescentY = 0.0; // cumulative Y offset added to all bricks
  double brickDescentSpeed = 0.36; // pixels per frame — 2x speed

  // Firing
  bool isTouching = false;
  int gunFireCooldown = 0;
  List<Bullet> bullets = [];

  // Laser pierce visuals
  List<Map<String, double>> laserRays = [];

  // Score popups
  List<Map<String, dynamic>> scorePopups = [];

  // Stars / level tracking
  Map<int, int> levelStars = {};
  int livesAtLevelStart = 3;
  int levelFrameCount = 0;
  bool perfectClear = false;
  int lastLevelStars = 0;
  bool showStarAnimation = false;
  int starAnimT = 0;

  // Boss countdown
  bool bossCountdownActive = false;
  int bossCountdownT = 0;

  // Game objects
  List<Brick> bricks = [];
  List<Particle> particles = [];
  List<PowerupDrop> drops = [];
  // Drop caps per level — max 4 of each type per level
  Map<PowerupType, int> levelDropCount = {
    PowerupType.fire: 0, PowerupType.laser: 0,
    PowerupType.whirlgig: 0, PowerupType.wide: 0,
  };

  // Paddle
  double padX = 0, padY = 0, padW = 0;
  final double padH = 14;
  int paddleSkin = 0;

  void init(double w, double h) {
    screenW = w; screenH = h;
    _resetPaddle();
    bricks = makeBricks(screenW: w, screenH: h, level: 1);
  }

  void _resetPaddle() {
    padW = min(screenW * 0.28, 120);
    padX = screenW / 2 - padW / 2;
    padY = screenH - 210;
  }

  void startGame() {
    score = 0; lives = 3; level = 1;
    combo = 0; comboTimer = 0;
    activeBulletType = BulletType.normal;
    normalBullets = 200;
    lifeFlashTimer = 0;
    gameOverByBullets = false;
    puWide = false; puWideT = 0;
    brickDescentY = 0.0;
    gunFireCooldown = 0;
    isTouching = false;
    bullets.clear();
    laserRays.clear();
    particles.clear();
    drops.clear();
    scorePopups.clear();
    levelStars.clear();
    livesAtLevelStart = 3;
    levelFrameCount = 0;
    perfectClear = true;
    showStarAnimation = false;
    starAnimT = 0;
    bossCountdownActive = false;
    bossCountdownT = 0;
    _resetPaddle();
    bricks = makeBricks(screenW: screenW, screenH: screenH, level: level);
    state = GameState.playing;
    notifyListeners();
  }

  void selectBulletType(BulletType type) {
    // Strip tap: only allow if type is unlocked for current level
    bool unlocked = type == BulletType.normal
        || (type == BulletType.fire     && level >= 5)
        || (type == BulletType.laser    && level >= 10)
        || (type == BulletType.whirlgig && level >= 25);
    if (unlocked && normalBullets > 0) {
      activeBulletType = type;
      notifyListeners();
    }
  }

  void movePaddle(double x) {
    padX = (x - padW / 2).clamp(0, screenW - padW);
  }

  void cyclePaddleSkin() {
    paddleSkin = (paddleSkin + 1) % 4;
    notifyListeners();
  }

  void togglePause() {
    if (state == GameState.playing) {
      state = GameState.paused;
    } else if (state == GameState.paused) state = GameState.playing;
    notifyListeners();
  }

  void update() {
    if (state == GameState.clear) {
      if (starAnimT > 1) { starAnimT--; notifyListeners(); }
      return;
    }
    if (bossCountdownActive) {
      bossCountdownT--;
      if (bossCountdownT <= 0) { bossCountdownActive = false; state = GameState.playing; }
      notifyListeners();
      return;
    }
    if (state != GameState.playing) return;

    // Powerup timers
    // No bullets left — force back to normal
    if (normalBullets <= 0 && activeBulletType != BulletType.normal) {
      activeBulletType = BulletType.normal;
    }
    if (puWide && --puWideT <= 0) {
      puWide = false;
      padW = min(screenW * 0.28, 120);
      padX = padX.clamp(0, screenW - padW);
    }

    // ── Firing ──────────────────────────────────────────────────────────────
    if (isTouching) {
      if (gunFireCooldown > 0) {
        gunFireCooldown--;
      } else {
        gunFireCooldown = 8;
        _spawnBullets();
      }
    } else {
      gunFireCooldown = 0;
    }

    // ── Move bullets ────────────────────────────────────────────────────────
    for (final b in bullets) { b.x += b.vx; b.y += b.vy; }
    bullets.removeWhere((b) => b.y < 0 || b.x < 0 || b.x > screenW);

    // ── Bullet-brick collision ───────────────────────────────────────────────
    final toRemoveBullets = <Bullet>{};
    for (final b in List<Bullet>.from(bullets)) {
      if (toRemoveBullets.contains(b)) continue;
      bool hitAny = false;
      for (final br in bricks) {
        if (!br.alive) continue;
        final bry = br.y + brickDescentY;
        if (b.x < br.x || b.x > br.x + br.w) continue;
        if (b.y < bry || b.y > bry + br.h) continue;

        // Hit!
        // Shield: absorb first hit completely
        if (br.brickType == BrickType.shield && br.shieldActive) {
          br.shieldActive = false;
          br.color = const Color(0xFF556677); // dulled — shield broken
          br.shakeFrames = 6;
          spawnShieldBreak(particles, br.x + br.w / 2, br.y + brickDescentY + br.h / 2);
          if (b.type != BulletType.laser) { toRemoveBullets.add(b); hitAny = true; break; }
          continue;
        }
        final dmg = (b.type == BulletType.fire) ? 2 : 1;
        br.hp -= dmg;
        br.shakeFrames = 4;
        if (br.hp <= 0) _destroyBrick(br, b.type);

        if (b.type == BulletType.laser) {
          // Laser: pierce — keep going, add visual ray
          if (laserRays.length < 20) {
            laserRays.add({'x1': b.x, 'y1': b.y + 20, 'x2': b.x, 'y2': bry, 'life': 1.0});
          }
          // Don't remove bullet — it keeps going through
        } else if (b.type == BulletType.whirlgig) {
          // Whirlgig: split into 3 on first impact
          toRemoveBullets.add(b);
          _spawnWhirlgigSplit(b.x, b.y);
          hitAny = true;
          break;
        } else {
          toRemoveBullets.add(b);
          hitAny = true;
          break;
        }
      }
    }
    bullets.removeWhere((b) => toRemoveBullets.contains(b));

    // ── Laser ray fade ───────────────────────────────────────────────────────
    for (var r in laserRays) { r['life'] = r['life']! - 0.08; }
    laserRays.removeWhere((r) => r['life']! <= 0);

    // ── Brick descent ────────────────────────────────────────────────────────
    final descentThisFrame = brickDescentSpeed + level * 0.008;
    brickDescentY += descentThisFrame;
    // Frozen bricks: counteract descent by pushing their base Y up
    for (final br in bricks) {
      if (br.alive && br.isFrozen) {
        br.y -= descentThisFrame; // cancel this frame's descent — they appear frozen
      }
    }

    // Check if any brick has crossed past the paddle (lose a life)
    bool brickPassed = false;
    for (final br in bricks) {
      if (!br.alive) continue;
      if (br.y + brickDescentY + br.h > padY) {
        br.alive = false; // remove that brick
        brickPassed = true;
      }
    }
    if (brickPassed) {
      lives--;
      perfectClear = false;
      SoundManager.instance.playBallLost();
      if (lives <= 0) {
        state = GameState.dead;
        if (score > best) best = score;
      }
    }

    // ── Update drops ─────────────────────────────────────────────────────────
    if (drops.length > 8) drops.removeRange(0, drops.length - 8);
    drops.removeWhere((d) {
      d.update();
      // Adjust drop y for descent (drops spawn at brick position which already includes descent)
      if (d.x > padX && d.x < padX + padW &&
          d.y + d.h / 2 > padY && d.y - d.h / 2 < padY + padH) {
        _applyPowerup(d.type);
        SoundManager.instance.playPowerup();
        spawnParticles(particles, d.x, d.y, d.color, 12);
        return true;
      }
      return d.y > screenH + 30;
    });

    // ── Particles (capped at 200 for performance) ───────────────────────────
    if (particles.length > 80) particles.removeRange(0, particles.length - 80);
    particles.removeWhere((p) => !p.update());

    // ── Score popups ─────────────────────────────────────────────────────────
    if (scorePopups.length > 15) scorePopups.removeRange(0, scorePopups.length - 15);
    for (final p in scorePopups) {
      p['age'] = (p['age'] as double) + 1.0;
      p['y'] = (p['y'] as double) + (p['vy'] as double);
      p['vy'] = (p['vy'] as double) * 0.92;
      p['life'] = (p['life'] as double) - 0.022;
    }
    scorePopups.removeWhere((p) => (p['life'] as double) <= 0);

    // ── Shake bricks + tick frozen frames ─────────────────────────────────────
    for (final br in bricks) {
      if (br.shakeFrames > 0) br.shakeFrames--;
      if (br.frozenFrames > 0) br.frozenFrames--;
    }

    // ── Life flash timer ──────────────────────────────────────────────────────
    if (lifeFlashTimer > 0) lifeFlashTimer--;

    // ── Combo timer ──────────────────────────────────────────────────────────
    if (comboTimer > 0) {
      comboTimer--;
    } else {
      combo = 0;
    }

    levelFrameCount++;
    if (starAnimT > 0) starAnimT--;

    // ── Level clear ──────────────────────────────────────────────────────────
    if (bricks.every((b) => !b.alive)) {
      state = GameState.clear;
      SoundManager.instance.playLevelUp();
      int stars = 1;
      if (perfectClear) stars++;
      if (levelFrameCount < 30 * 60) stars++;
      lastLevelStars = stars;
      if ((levelStars[level] ?? 0) < stars) levelStars[level] = stars;
      showStarAnimation = true;
      starAnimT = 120;
    }

    notifyListeners();
  }

  void _spawnBullets() {
    final type = activeBulletType;

    // All bullet types share the same normalBullets pool
    if (normalBullets <= 0) {
      lives--;
      lifeFlashTimer = 60;
      if (lives <= 0) {
        lives = 0;
        gameOverByBullets = true;
        state = GameState.dead;
        if (score > best) best = score;
        SoundManager.instance.stopMusic();
        notifyListeners();
      } else {
        normalBullets = 200; // refill for next life
        activeBulletType = BulletType.normal;
        notifyListeners();
      }
      return;
    }
    normalBullets -= 2; // deduct 2 per shot (left + right)

    final left  = Bullet(x: padX + 6,        y: padY - 8, vy: -16.0, type: type);
    final right = Bullet(x: padX + padW - 6, y: padY - 8, vy: -16.0, type: type);
    if (bullets.length < 16) {
      bullets.add(left);
      bullets.add(right);
    }
  }

  void _spawnWhirlgigSplit(double x, double y) {
    // Only 2 split bullets, lower speed — no further splitting
    for (final angle in [-0.4, 0.4]) {
      const spd = 10.0;
      bullets.add(Bullet(
        x: x, y: y,
        vx: sin(angle) * spd,
        vy: -cos(angle) * spd,
        type: BulletType.normal, // use normal type so splits don't chain-split
      ));
    }
  }

  void _destroyBrick(Brick br, [BulletType bulletType = BulletType.normal]) {
    br.alive = false;
    combo++;
    comboTimer = 90;
    final points = 10 * level + combo * 5;
    score += points;
    final cx = br.x + br.w / 2;
    final cy = br.y + brickDescentY + br.h / 2;

    // ── Special brick effects ──────────────────────────────────────
    switch (br.brickType) {
      case BrickType.bomb:
        spawnBombExplosion(particles, cx, cy);
        SoundManager.instance.playWhirlgig(); // reuse big boom sound
        // Destroy all bricks within blast radius (cap at 10 for performance)
        final blastR = screenW * 0.35;
        int blastCount = 0;
        for (final other in bricks) {
          if (!other.alive || other == br || blastCount >= 10) continue;
          final ox = other.x + other.w / 2;
          final oy = other.y + brickDescentY + other.h / 2;
          final dist = sqrt((ox - cx) * (ox - cx) + (oy - cy) * (oy - cy));
          if (dist < blastR) {
            other.alive = false;
            score += 10 * level;
            blastCount++;
            spawnNormalExplosion(particles, ox, oy, other.color); // lighter explosion per brick
          }
        }
      case BrickType.shield:
        spawnShieldBreak(particles, cx, cy);
      case BrickType.colorBomb:
        spawnColorBombExplosion(particles, cx, cy);
        SoundManager.instance.playMultiPower();
        // Destroy all bricks of same color
        final targetColor = br.color.value;
        // Store original colors to compare (colorBomb is white, compare previously assigned)
        // Instead destroy all bricks sharing the same original brickColors index
        // We'll destroy all normal-colored bricks with matching color
        for (final other in bricks) {
          if (!other.alive || other == br) continue;
          if (other.brickType == BrickType.normal || other.brickType == BrickType.colorBomb) {
            // destroy random ~1/3 of bricks as "color wave"
            // Actually: destroy all bricks in same row
          }
        }
        // Simpler: destroy all bricks sharing same row Y position
        int rowCount = 0;
        for (final other in bricks) {
          if (!other.alive || other == br || rowCount >= 12) continue;
          if ((other.y - br.y).abs() < 5) { // same row
            other.alive = false;
            score += 10 * level;
            rowCount++;
            spawnNormalExplosion(particles, other.x + other.w / 2, other.y + brickDescentY + other.h / 2, other.color);
          }
        }
      case BrickType.ice:
        spawnIceShatter(particles, cx, cy);
        // Freeze nearby bricks — pause their descent
        final freezeR = screenW * 0.30;
        for (final other in bricks) {
          if (!other.alive || other == br) continue;
          final ox = other.x + other.w / 2;
          final oy = other.y + brickDescentY + other.h / 2;
          final dist = sqrt((ox - cx) * (ox - cx) + (oy - cy) * (oy - cy));
          if (dist < freezeR) {
            other.frozenFrames = 180; // 3 seconds frozen
          }
        }
      case BrickType.fountain:
        spawnFountainBurst(particles, cx, cy);
        SoundManager.instance.playWidePower();
        // Spray 6 bonus bullets upward from the brick position
        for (int i = 0; i < 4; i++) {
          final angle = -pi * 0.5 + (i - 1.5) * 0.25;
          bullets.add(Bullet(
            x: cx, y: cy,
            vx: cos(angle) * 10, vy: sin(angle) * 10,
            type: activeBulletType,
          ));
        }
      case BrickType.normal:
        // Per bullet-type explosion
        switch (bulletType) {
          case BulletType.fire:     spawnFireExplosion(particles, cx, cy, br.color);
          case BulletType.laser:    spawnLaserExplosion(particles, cx, cy, br.color);
          case BulletType.whirlgig: spawnWhirlgigExplosion(particles, cx, cy, br.color);
          case BulletType.normal:   spawnNormalExplosion(particles, cx, cy, br.color);
        }
    }

    // Normal bullet explosion for all non-normal types too (layered on top)
    if (br.brickType != BrickType.normal) {
      spawnNormalExplosion(particles, cx, cy, br.color);
    }

    _addScorePopup(cx, cy, points, br.color);
    SoundManager.instance.playBrickDestroy();
    final drop = trySpawnDrop(cx, br.y + brickDescentY + br.h / 2, screenW, level: level);
    if (drop != null) {
      final currentCount = levelDropCount[drop.type] ?? 0;
      // Block if this type already hit 4 drops this level
      // Also block bullet powers if their pool is empty
      bool blocked = currentCount >= 1;
      if (!blocked) {
        levelDropCount[drop.type] = currentCount + 1;
        drops.add(drop);
      }
    }
  }

  void nextLevel() {
    if (state != GameState.clear) return;
    level++;
    activeBulletType = BulletType.normal;
    normalBullets = 200;
    lifeFlashTimer = 0;
    gameOverByBullets = false;
    puWide = false; puWideT = 0;
    brickDescentY = 0.0;
    bullets.clear();
    laserRays.clear();
    drops.clear();
    levelDropCount = {PowerupType.fire: 0, PowerupType.laser: 0, PowerupType.whirlgig: 0, PowerupType.wide: 0};
    scorePopups.clear();
    gunFireCooldown = 0;
    livesAtLevelStart = lives;
    levelFrameCount = 0;
    perfectClear = true;
    showStarAnimation = false;
    starAnimT = 0;
    _resetPaddle();
    bricks = makeBricks(screenW: screenW, screenH: screenH, level: level);
    if (level % 5 == 0) {
      bossCountdownActive = true;
      bossCountdownT = 180;
      state = GameState.paused;
    } else {
      state = GameState.playing;
    }
    notifyListeners();
  }

  void _addScorePopup(double x, double y, int points, Color brickColor) {
    int color;
    if (points >= 50) {
      color = 0xFFFF00FF;
    } else if (points >= 30) color = 0xFFFFE135;
    else if (points >= 20) color = 0xFF00FF88;
    else color = 0xFF00E5FF;
    scorePopups.add({'x': x, 'y': y, 'vy': -5.0, 'life': 1.0, 'age': 0.0, 'points': points, 'color': color, 'combo': combo});
  }

  void _applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.fire:
        if (level >= 5) {
          activeBulletType = BulletType.fire;
          SoundManager.instance.playFirePower();
        }
      case PowerupType.laser:
        if (level >= 10) {
          activeBulletType = BulletType.laser;
          SoundManager.instance.playLaserPower();
        }
      case PowerupType.whirlgig:
        if (level >= 25) {
          activeBulletType = BulletType.whirlgig;
          SoundManager.instance.playWhirlgig();
        }
      case PowerupType.wide:
        puWide = true;
        puWideT = puDuration;
        padW = min(screenW * 0.55, 220);
        padX = padX.clamp(0, screenW - padW);
        SoundManager.instance.playWidePower();
      case PowerupType.life:
        lives = min(lives + 1, 9);
    }
  }
}