import 'dart:math';
import 'package:flutter/material.dart';
import 'game_models.dart';
import 'sound_manager.dart';

enum GameState { menu, playing, dead, clear }

class GameController extends ChangeNotifier {
  // Screen dimensions (set on first layout)
  double screenW = 0;
  double screenH = 0;

  GameState state = GameState.menu;
  int score = 0;
  int best = 0;
  int lives = 3;
  int level = 1;
  int combo = 0;
  int comboTimer = 0;

  // Powerup state
  
  bool puFire = false, puBig = false, puMulti = false, puWide = false, puLaser = false;
int puFireT = 0, puBigT = 0, puMultiT = 0, puWideT = 0, puLaserT = 0;
List<Map<String, double>> laserRays = [];
double laserSpinAngle = 0.0;
bool laserUsedThisLevel = false;

// Powerup collect counts
int countFire = 0, countBig = 0, countMulti = 0, countWide = 0, countLaser = 0;

// Laser beams for animation
List<Map<String, double>> laserBeams = [];
int laserAnimT = 0;

  // Game objects
  List<Ball> balls = [];
  List<Brick> bricks = [];
  List<Particle> particles = [];
  List<PowerupDrop> drops = [];

  // Paddle
  double padX = 0, padY = 0, padW = 0;
  final double padH = 14;

  void init(double w, double h) {
    screenW = w;
    screenH = h;
    _resetPaddle();
    bricks = makeBricks(screenW: w, screenH: h, level: 1);
  }

void _resetPaddle() {
  padW = min(screenW * 0.28, 120);
  padX = screenW / 2 - padW / 2;
  padY = screenH - 160; // moved up so fingers don't cover it
}

  void startGame() {
    score = 0; lives = 3; level = 1;
    combo = 0; comboTimer = 0;
    puFire = puBig = puMulti = puWide = false;
puFireT = puBigT = puMultiT = puWideT = 0;
 countFire = countBig = countMulti = countWide = countLaser = 0;
  puLaser = false; puLaserT = 0; 
  laserRays.clear();
  laserSpinAngle = 0.0;
  laserUsedThisLevel = false;

    particles.clear(); drops.clear();
    _resetPaddle();
    bricks = makeBricks(screenW: screenW, screenH: screenH, level: level);
    balls = [makeBall(screenW: screenW, padY: padY, level: level)];
    state = GameState.playing;
    notifyListeners();
  }

  void movePaddle(double x) {
    padX = (x - padW / 2).clamp(0, screenW - padW);
  }

  void update() {
    if (state != GameState.playing) return;

    // Powerup timers
    if (puFire  && --puFireT  <= 0) { puFire  = false; for (var b in balls) {
      b.fire = false;
    } }
if (puBig   && --puBigT   <= 0) { puBig   = false; for (var b in balls) {
  b.r = screenW * 0.022;
} }
if (puMulti && --puMultiT <= 0)   puMulti = false;
if (puWide  && --puWideT  <= 0) { puWide  = false; padW = screenW * 0.28; padX = (padX).clamp(0, screenW - padW); }

if (puLaser && --puLaserT <= 0) {
  puLaser = false;
  for (var b in balls) {
    b.laser = false;
    b.r = screenW * 0.022; // back to normal size
  }
}
// Spin the laser angle every frame
if (puLaser) laserSpinAngle += 0.05;

// Fade out laser rays over time
laserRays.removeWhere((r) => r['life']! <= 0);
for (var r in laserRays) { r['life'] = r['life']! - 0.05; }

    // Update balls
    final toRemove = <Ball>[];
    for (final b in balls) {
      b.update();

      // Wall bounces
      if (b.x - b.r < 0)        { b.x = b.r;           b.vx =  b.vx.abs(); }
      if (b.x + b.r > screenW)  { b.x = screenW - b.r; b.vx = -b.vx.abs(); }
     if (b.y - b.r < 135.0) { b.y = 135.0 + b.r; b.vy = b.vy.abs(); }
      // Paddle collision
      if (b.vy > 0 &&
          b.x + b.r > padX && b.x - b.r < padX + padW &&
          b.y + b.r > padY && b.y - b.r < padY + padH) {
        b.vy = -b.vy.abs();
        final hit = (b.x - padX) / padW;
        b.vx = (hit - 0.5) * 12;
        final spd = sqrt(b.vx * b.vx + b.vy * b.vy);
        final target = 6.0 + level * 0.4;
        b.vx = b.vx / spd * target;
        b.vy = b.vy / spd * target;
        spawnParticles(particles, b.x, padY, const Color(0xFF00FFFF), 6);
      SoundManager.instance.playPaddleHit(); 
      }

// Laser ray brick detection — check if any ray intersects each brick
if (b.laser) {
  const rayCount = 1;
  final spinAngle = laserSpinAngle;
  for (final br in bricks) {
    if (!br.alive) continue;
    // Check if ball ray passes through brick
    for (int i = 0; i < rayCount; i++) {
      final angle = spinAngle + (i / rayCount) * 3.14159 * 2;
      // Check multiple points along the ray
      for (double dist = b.r; dist < 800; dist += 20) {
        final rx = b.x + cos(angle) * dist;
        final ry = b.y + sin(angle) * dist;
        if (rx >= br.x && rx <= br.x + br.w &&
            ry >= br.y && ry <= br.y + br.h) {
          // Ray hit this brick!
          br.hp--;
          br.shakeFrames = 5;
          laserRays.add({
            'x1': b.x, 'y1': b.y,
            'x2': br.x + br.w / 2,
            'y2': br.y + br.h / 2,
            'life': 1.0,
          });
          if (br.hp <= 0) {
            br.alive = false;
            combo++;
            comboTimer = 90;
            score += 10 * level + combo * 5;
            spawnParticles(particles, br.x + br.w / 2,
                br.y + br.h / 2, br.color, 16);
            SoundManager.instance.playBrickDestroy();
          }
          break; // one ray hits one brick once per frame
        }
      }
    }
  }
}

      // Brick collisions
      for (final br in bricks) {
        if (!br.alive) continue;
        if (b.x + b.r < br.x || b.x - b.r > br.x + br.w) continue;
        if (b.y + b.r < br.y || b.y - b.r > br.y + br.h) continue;

        if (!b.fire) {
          final oL = (b.x + b.r) - br.x;
          final oR = (br.x + br.w) - (b.x - b.r);
          final oT = (b.y + b.r) - br.y;
          final oB = (br.y + br.h) - (b.y - b.r);
          if (min(oL, oR) < min(oT, oB)) {
            b.vx = -b.vx;
          } else {
            b.vy = -b.vy;
          }
        }

br.hp--;
br.shakeFrames = 5;
SoundManager.instance.playBrickHit();

// Spawn laser rays from ball to brick if laser active
if (b.laser) {
  laserRays.add({
    'x1': b.x, 'y1': b.y,
    'x2': br.x + br.w / 2,
    'y2': br.y + br.h / 2,
    'life': 1.0,
  });
}

if (br.hp <= 0) {
  br.alive = false;
  SoundManager.instance.playBrickDestroy();
  combo++;
  comboTimer = 90;
  score += 10 * level + combo * 5;
  spawnParticles(particles, br.x + br.w / 2, br.y + br.h / 2, br.color, 16);
  final drop = trySpawnDrop(br.x + br.w / 2, br.y + br.h / 2, screenW);
  if (drop != null) drops.add(drop);
        } else {
          spawnParticles(particles, br.x + br.w / 2, br.y + br.h / 2, br.color, 4);
        }
        break;
      }

      if (b.y - b.r > screenH) toRemove.add(b);
    }

    balls.removeWhere((b) => toRemove.contains(b));

    if (balls.isEmpty) {
      lives--;
      SoundManager.instance.playBallLost();
      if (lives <= 0) {
        state = GameState.dead;
        if (score > best) best = score;
      } else {
        balls = [makeBall(screenW: screenW, padY: padY, level: level)];
      }
    }

    // Update drops
    drops.removeWhere((d) {
      d.update();
      if (d.x > padX && d.x < padX + padW &&
          d.y + d.h / 2 > padY && d.y - d.h / 2 < padY + padH) {
        _applyPowerup(d.type);
        SoundManager.instance.playPowerup();
        spawnParticles(particles, d.x, d.y, d.color, 12);
        return true;
      }
      return d.y > screenH + 30;
    });

    // Update particles
    particles.removeWhere((p) => !p.update());

    // Combo timer
    if (comboTimer > 0) {
      comboTimer--;
    } else {
      combo = 0;
    }

    // Shake bricks
    for (final br in bricks) {
      if (br.shakeFrames > 0) br.shakeFrames--;
    }

    // Level clear
    if (bricks.every((b) => !b.alive)) {
      state = GameState.clear;
      SoundManager.instance.playLevelUp();
      Future.delayed(const Duration(milliseconds: 1500), () {
        level++;
        puFire = puBig = puMulti = false;
        puFireT = puBigT = puMultiT = 0;
        drops.clear();
        _resetPaddle();
        laserUsedThisLevel = false;
        bricks = makeBricks(screenW: screenW, screenH: screenH, level: level);
        balls = [makeBall(screenW: screenW, padY: padY, level: level)];
        state = GameState.playing;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  void _applyPowerup(PowerupType type) {
    switch (type) {
      case PowerupType.fire:
        puFire = true; puFireT = puDuration;
        countFire++;
        for (var b in balls) {
          b.fire = true;
        }
      case PowerupType.big:
        puBig = true; puBigT = puDuration;
        countBig++;
        for (var b in balls) {
          b.r = screenW * 0.045;
        }
      case PowerupType.multi:
        puMulti = true; puMultiT = puDuration;
        countMulti++;
        if (balls.isNotEmpty) {
          final orig = balls.first;
          balls.add(makeBall(screenW: screenW, padY: padY, level: level,
              x: orig.x, y: orig.y, vx: orig.vx + 3, vy: orig.vy));
          balls.add(makeBall(screenW: screenW, padY: padY, level: level,
              x: orig.x, y: orig.y, vx: orig.vx - 3, vy: orig.vy));
        }
      case PowerupType.life:
    lives = min(lives + 1, 5);
case PowerupType.wide:
    puWide = true; puWideT = puDuration;
    countWide++;
    padW = min(screenW * 0.55, 220); // paddle becomes wider
    padX = padX.clamp(0, screenW - padW);

    
   case PowerupType.laser:
  // Only allow 1 laser per level
  if (laserUsedThisLevel) break;
  laserUsedThisLevel = true;
  puLaser = true; puLaserT = puDuration;
  countLaser++;
  for (var b in balls) {
    b.laser = true;
    b.r = screenW * 0.03;
  }
    
    }
  }
  
  
}
