import 'dart:math';
import 'package:flutter/material.dart';
import 'game_models.dart';
import 'sound_manager.dart';

enum GameState { menu, playing, paused, dead, clear }

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
 // Powerup state
bool puFire = false, puBig = false, puMulti = false, puWide = false, puLaser = false;
int puFireT = 0, puBigT = 0, puMultiT = 0, puWideT = 0, puLaserT = 0;

// Powerup counts (10 each, shared across all levels)
int countFire = 1, countBig = 1, countMulti = 1, countWide = 1, countLaser = 1, countFlowerpot = 1;
int centerBrickIndex = -1; // tracks which brick is the center one
bool whirlgigActive = false;
int whirlgigT = 0;
double whirlgigX = 0, whirlgigY = 0;
List<Map<String, dynamic>> whirlgigParticles = [];

// Flowerpot
bool flowerpotActive = false;
int flowerpotT = 0;
List<Map<String, dynamic>> flowerpotParticles = [];

// Laser
List<Map<String, double>> laserRays = [];
double laserSpinAngle = 0.0;
bool laserUsedThisLevel = false;
bool fireUsedThisLevel = false;
bool bigUsedThisLevel = false;
bool multiUsedThisLevel = false;
bool wideUsedThisLevel = false;
bool flowerpotUsedThisLevel = false;
bool whirlgigUsedThisLevel = false;

// 3-Star system
Map<int, int> levelStars = {}; // level -> best stars earned (1-3)
int livesAtLevelStart = 10;
int levelStartFrame = 0;
int levelFrameCount = 0;
bool perfectClear = false; // no lives lost this level
int lastLevelStars = 0; // stars earned in just-completed level
bool showStarAnimation = false;
int starAnimT = 0;

  // Game objects
  List<Ball> balls = [];
  List<Brick> bricks = [];
  List<Particle> particles = [];
  List<Map<String, dynamic>> scorePopups = [];
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
    padY = screenH - 210;
  }

  void startGame() {
  score = 0; lives = 10; level = 1;
  combo = 0; comboTimer = 0;
  puFire = puBig = puMulti = puWide = puLaser = false;
  puFireT = puBigT = puMultiT = puWideT = puLaserT = 0;
  countFire = 1; countBig = 1; countMulti = 1; countWide = 1; countLaser = 1; countFlowerpot = 1;
  laserRays.clear();
  livesAtLevelStart = lives;
  levelFrameCount = 0;
  perfectClear = true;
  showStarAnimation = false;
  starAnimT = 0; laserSpinAngle = 0.0;
laserUsedThisLevel = false;
fireUsedThisLevel = false;
bigUsedThisLevel = false;
multiUsedThisLevel = false;
wideUsedThisLevel = false;
flowerpotUsedThisLevel = false;
whirlgigUsedThisLevel = false;
whirlgigActive = false; whirlgigT = 0; whirlgigParticles.clear();
flowerpotActive = false; flowerpotT = 0; flowerpotParticles.clear();
countFlowerpot = 50;
  particles.clear(); drops.clear(); scorePopups.clear();
  levelStars.clear();
  livesAtLevelStart = 10;
  levelFrameCount = 0;
  perfectClear = true;
  showStarAnimation = false;
  starAnimT = 0;
  _resetPaddle();
bricks = makeBricks(screenW: screenW, screenH: screenH, level: level);
_markCenterBrick();
  balls = [makeBall(screenW: screenW, padY: padY, level: level)];
  state = GameState.playing;
  notifyListeners();
}

  void movePaddle(double x) {
    padX = (x - padW / 2).clamp(0, screenW - padW);
  }

void togglePause() {
  if (state == GameState.playing) {
    state = GameState.paused;
  } else if (state == GameState.paused) {
    state = GameState.playing;
  }
  notifyListeners();
}
  void update() {
    if (state != GameState.playing) return;

    // Powerup timers
// Powerup timers
if (puFire  && --puFireT  <= 0) { puFire  = false; for (var b in balls) { b.fire = false; } }
if (puBig   && --puBigT   <= 0) { puBig   = false; for (var b in balls) { b.r = screenW * 0.022; } }
if (puMulti && --puMultiT <= 0)   puMulti = false;
if (puWide  && --puWideT  <= 0) { puWide  = false; padW = screenW * 0.28; padX = padX.clamp(0, screenW - padW); }
if (puLaser && --puLaserT <= 0) { puLaser = false; for (var b in balls) { b.laser = false; b.r = screenW * 0.022; } }
laserRays.removeWhere((r) => r['life']! <= 0);
for (var r in laserRays) { r['life'] = r['life']! - 0.05; }
if (puLaser) laserSpinAngle += 0.05;

    // Update balls
    final toRemove = <Ball>[];
    for (final b in balls) {
      b.update();

      // Wall bounces
      if (b.x - b.r < 0)        { b.x = b.r;           b.vx =  b.vx.abs(); }
      if (b.x + b.r > screenW)  { b.x = screenW - b.r; b.vx = -b.vx.abs(); }
      if (b.y - b.r < 0)        { b.y = b.r;            b.vy =  b.vy.abs(); }

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
        // Random chance to trigger flowerpot on paddle hit

      }

// Laser ray collision — optimized, only fires every 10 frames
// Laser ray collision — 8 rays from screen center
if (b.laser && (puLaserT % 10 == 0)) {
  const rayCount = 8;
  final cx = screenW / 2;
  final cy = screenH / 2;
  int bricksHitThisFrame = 0;
  for (int i = 0; i < rayCount; i++) {
    if (bricksHitThisFrame >= 4) break;
    final angle = laserSpinAngle + (i / rayCount) * 3.14159 * 2;
    final dx = cos(angle);
    final dy = sin(angle);
    bool hitBrick = false;
    for (double dist = 20; dist < 900; dist += 25) {
      if (hitBrick) break;
      final rx = cx + dx * dist;
      final ry = cy + dy * dist;
      if (rx < 0 || rx > screenW || ry < 0 || ry > screenH) break;
      for (final br in bricks) {
        if (!br.alive) continue;
        if (rx >= br.x && rx <= br.x + br.w &&
            ry >= br.y && ry <= br.y + br.h) {
          br.hp--;
          br.shakeFrames = 5;
          if (laserRays.length < 30) {
            laserRays.add({'x1': cx, 'y1': cy, 'x2': br.x + br.w / 2, 'y2': br.y + br.h / 2, 'life': 1.0});
          }
          if (br.hp <= 0) {
            br.alive = false;
            combo++;
            comboTimer = 90;
            final points = 10 * level + combo * 5;
            score += points;
            spawnParticles(particles, br.x + br.w / 2, br.y + br.h / 2, br.color, 8);
            _addScorePopup(br.x + br.w / 2, br.y + br.h / 2, points, br.color);
          }
          bricksHitThisFrame++;
          hitBrick = true;
          break;
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
       
   if (br.hp <= 0) {
  br.alive = false;
  combo++;
  comboTimer = 90;
  final points = 10 * level + combo * 5;
  score += points;
  spawnParticles(particles, br.x + br.w / 2, br.y + br.h / 2, br.color, 16);
  _addScorePopup(br.x + br.w / 2, br.y + br.h / 2, points, br.color);
  SoundManager.instance.playBrickDestroy();
  // Check if this was the center brick   
      
  // Check if this was the center brick
  final brIndex = bricks.indexOf(br);
  if (brIndex == centerBrickIndex && !whirlgigActive) {
    _triggerWhirlgig(br.x + br.w / 2, br.y + br.h / 2);
  }
  // Drop hidden power if brick had one
  
  if (br.hiddenPower != null) {
  // Only drop if not already used this level
  bool alreadyUsed = false;
  if (br.hiddenPower == PowerupType.flowerpot && flowerpotUsedThisLevel) alreadyUsed = true;
  if (br.hiddenPower == PowerupType.fire      && fireUsedThisLevel)      alreadyUsed = true;
  if (br.hiddenPower == PowerupType.big       && bigUsedThisLevel)       alreadyUsed = true;
  if (br.hiddenPower == PowerupType.multi     && multiUsedThisLevel)     alreadyUsed = true;
  if (br.hiddenPower == PowerupType.wide      && wideUsedThisLevel)      alreadyUsed = true;
  if (br.hiddenPower == PowerupType.laser     && laserUsedThisLevel)     alreadyUsed = true;

  if (!alreadyUsed) {
    drops.add(PowerupDrop(
      x: br.x + br.w / 2,
      y: br.y + br.h / 2,
      type: br.hiddenPower!,
      label: '🌸 FLOWER',
      color: const Color(0xFFFF69B4),
      w: screenW * 0.22,
      h: 28,
    ));
  }
} else {
    
    final drop = trySpawnDrop(
  br.x + br.w / 2, br.y + br.h / 2, screenW,
  countFire: fireUsedThisLevel ? 0 : countFire,
  countBig: bigUsedThisLevel ? 0 : countBig,
  countMulti: multiUsedThisLevel ? 0 : countMulti,
  countWide: wideUsedThisLevel ? 0 : countWide,
  countLaser: laserUsedThisLevel ? 0 : countLaser,
  countFlowerpot: flowerpotUsedThisLevel ? 0 : countFlowerpot,
);
    
    if (drop != null) drops.add(drop);
  }
        
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
  perfectClear = false;
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


// Update flowerpot
if (flowerpotActive) {
  flowerpotT--;
if (flowerpotT <= 0) {
  flowerpotActive = false;
  flowerpotParticles.clear();
  // Reset paddle to normal width
  padW = min(screenW * 0.28, 120);
  padX = (screenW / 2) - (padW / 2);
}

  final rng = Random();
  // Keep spawning new flower burst particles
  if (flowerpotT % 8 == 0) {
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 3.14159 * 2;
      final speed = 6.0 + rng.nextDouble() * 8;
      flowerpotParticles.add({
        'x': padX + padW / 2,
        'y': padY,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 8, // shoot higher
        'life': 1.0,
        'decay': 0.012 + rng.nextDouble() * 0.008,
        'r': 4.0 + rng.nextDouble() * 5,
        'color': [
          0xFFFF69B4, 0xFFFF4444, 0xFFFFE135,
          0xFF00FF88, 0xFFFF8800, 0xFFFF00FF,
        ][rng.nextInt(6)],
        'active': true,
      });
    }
  }
  
  for (final p in flowerpotParticles) {
  p['x'] = (p['x'] as double) + (p['vx'] as double);
  p['y'] = (p['y'] as double) + (p['vy'] as double);
  p['vy'] = (p['vy'] as double) + 0.08; // less gravity so sparks reach higher
  p['vx'] = (p['vx'] as double) * 0.99;
  p['life'] = (p['life'] as double) - (p['decay'] as double);

  // Check if spark hits any brick
  final px = p['x'] as double;
  final py = p['y'] as double;
  for (final br in bricks) {
    if (!br.alive) continue;
    if (px >= br.x && px <= br.x + br.w &&
        py >= br.y && py <= br.y + br.h) {
      br.hp--;
      br.shakeFrames = 5;
      if (br.hp <= 0) {
        br.alive = false;
        combo++;
        comboTimer = 90;
        score += 10 * level + combo * 5;
        spawnParticles(particles, br.x + br.w / 2, br.y + br.h / 2, br.color, 12);
      }
      p['life'] = 0.0; // spark dies after hitting brick
      break;
    }
  }
}
flowerpotParticles.removeWhere((p) => (p['life'] as double) <= 0);
}

// Update whirlgig
if (whirlgigActive) {
  whirlgigT--;
  if (whirlgigT <= 0) {
    whirlgigActive = false;
    whirlgigParticles.clear();
  }
  for (final p in whirlgigParticles) {
    final delay = p['delay'] as int;
    if (delay > 0) {
      p['delay'] = delay - 1;
      continue;
    }
    p['active'] = true;
    p['x'] = (p['x'] as double) + (p['vx'] as double);
    p['y'] = (p['y'] as double) + (p['vy'] as double);
    p['vy'] = (p['vy'] as double) + 0.05; // gravity
    p['vx'] = (p['vx'] as double) * 0.99; // drag
    p['life'] = (p['life'] as double) - (p['decay'] as double);
  }
  whirlgigParticles.removeWhere((p) => (p['life'] as double) <= 0);
}

// Update score popups
for (final p in scorePopups) {
  p['age'] = (p['age'] as double) + 1.0;
  p['y'] = (p['y'] as double) + (p['vy'] as double);
  p['vy'] = (p['vy'] as double) * 0.92;
  p['life'] = (p['life'] as double) - 0.022;
}
scorePopups.removeWhere((p) => (p['life'] as double) <= 0);
    // Update particles
    particles.removeWhere((p) => !p.update());

    // Level timer
    levelFrameCount++;
    if (starAnimT > 0) starAnimT--;
    if (state == GameState.clear && starAnimT == 0) starAnimT = 1; // freeze on last frame

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
      // Calculate stars
      int stars = 1; // always get 1 star for clearing
      if (perfectClear) stars++; // 2nd star: no lives lost
      if (levelFrameCount < 60 * 60) stars++; // 3rd star: under 60 seconds (60fps)
      lastLevelStars = stars;
      // Save best star count for this level
      if ((levelStars[level] ?? 0) < stars) levelStars[level] = stars;
      showStarAnimation = true;
      starAnimT = 120; // 2 seconds of star animation
      
      // Stay on clear screen — user taps to advance via nextLevel()
    }

    notifyListeners();
  }


void nextLevel() {
  if (state != GameState.clear) return;
  level++;
  puFire = puBig = puMulti = puWide = puLaser = false;
  puFireT = puBigT = puMultiT = puWideT = puLaserT = 0;
  laserUsedThisLevel = false;
  fireUsedThisLevel = false;
  bigUsedThisLevel = false;
  multiUsedThisLevel = false;
  wideUsedThisLevel = false;
  flowerpotUsedThisLevel = false;
  whirlgigUsedThisLevel = false;
  countFire = 1; countBig = 1; countMulti = 1; countWide = 1; countLaser = 1; countFlowerpot = 1;
  laserRays.clear();
  flowerpotActive = false;
  flowerpotT = 0;
  flowerpotParticles.clear();
  drops.clear();
  scorePopups.clear();
  livesAtLevelStart = lives;
  levelFrameCount = 0;
  perfectClear = true;
  showStarAnimation = false;
  starAnimT = 0;
  _resetPaddle();
  bricks = makeBricks(screenW: screenW, screenH: screenH, level: level);
  _markCenterBrick();
  balls = [makeBall(screenW: screenW, padY: padY, level: level)];
  state = GameState.playing;
  notifyListeners();
}

void _markCenterBrick() {
  if (bricks.isEmpty) return;
  // Find brick closest to center of screen
  double centerX = screenW / 2;
  double centerY = screenH / 2;
  double minDist = double.infinity;
  centerBrickIndex = 0;
  for (int i = 0; i < bricks.length; i++) {
    final br = bricks[i];
    final bx = br.x + br.w / 2;
    final by = br.y + br.h / 2;
    final dist = sqrt((bx - centerX) * (bx - centerX) + (by - centerY) * (by - centerY));
    if (dist < minDist) {
      minDist = dist;
      centerBrickIndex = i;
    }
  }
}


void _triggerWhirlgig(double x, double y) {
  if (whirlgigUsedThisLevel) return;
  whirlgigUsedThisLevel = true;
  whirlgigActive = true;
  whirlgigT = 240; // 3 seconds
  SoundManager.instance.playWhirlgig();
  whirlgigX = x;
  whirlgigY = y;
  whirlgigParticles.clear();

  final rng = Random();
  // Spawn spiral firework particles
  for (int ring = 0; ring < 6; ring++) {
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 3.14159 * 2;
      final speed = 2.0 + ring * 1.5;
      final delay = ring * 8; // staggered rings
      whirlgigParticles.add({
        'x': x, 'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 1.0,
        'decay': 0.008 + rng.nextDouble() * 0.005,
        'r': 3.0 + rng.nextDouble() * 4,
        'color': [
          0xFFFF4444, 0xFFFFE135, 0xFF00FF88,
          0xFF00E5FF, 0xFFFF00FF, 0xFFFF8800,
        ][ring % 6],
        'delay': delay,
        'active': false,
      });
    }
  }

  // Also destroy nearby bricks in radius
  for (final br in bricks) {
    if (!br.alive) continue;
    final bx = br.x + br.w / 2;
    final by = br.y + br.h / 2;
    final dist = sqrt((bx - x) * (bx - x) + (by - y) * (by - y));
    if (dist < screenW * 0.4) {
      br.hp = 0;
      br.alive = false;
      score += 10 * level;
      spawnParticles(particles, bx, by, br.color, 12);
    }
  }
}

 
void _addScorePopup(double x, double y, int points, Color brickColor) {
  // Pick color based on points value
  int color;
  if (points >= 50) {
    color = 0xFFFF00FF; // magenta for big scores
  } else if (points >= 30) color = 0xFFFFE135; // yellow for medium
  else if (points >= 20) color = 0xFF00FF88; // green
  else                   color = 0xFF00E5FF; // cyan for small

  scorePopups.add({
    'x': x,
    'y': y,
    'vy': -5.0,       // fast initial upward burst
    'life': 1.0,
    'age': 0.0,
    'points': points,
    'color': color,
    'combo': combo,   // store combo for size scaling
  });
}

 void _applyPowerup(PowerupType type) {
  switch (type) {
    case PowerupType.fire:
      if (countFire <= 0 || fireUsedThisLevel) break;
      fireUsedThisLevel = true;
      puFire = true; puFireT = puDuration;
      countFire--;
      for (var b in balls) {
        b.fire = true;
       }
        SoundManager.instance.playFirePower();
    case PowerupType.big:
      if (countBig <= 0 || bigUsedThisLevel) break;
      bigUsedThisLevel = true;
      puBig = true; puBigT = puDuration;
      countBig--;
      for (var b in balls) {
        b.r = screenW * 0.045;
      }
        SoundManager.instance.playBigPower();

    case PowerupType.multi:
      if (countMulti <= 0 || multiUsedThisLevel) break;
      multiUsedThisLevel = true;
      puMulti = true; puMultiT = puDuration;
      countMulti--;
      if (balls.isNotEmpty) {
        final orig = balls.first;
        balls.add(makeBall(screenW: screenW, padY: padY, level: level,
            x: orig.x, y: orig.y, vx: orig.vx + 3, vy: orig.vy));
        balls.add(makeBall(screenW: screenW, padY: padY, level: level,
            x: orig.x, y: orig.y, vx: orig.vx - 3, vy: orig.vy));
      }
      SoundManager.instance.playMultiPower();
    case PowerupType.life:
      lives = min(lives + 1, 10);
    case PowerupType.wide:
      if (countWide <= 0 || wideUsedThisLevel) break;
      wideUsedThisLevel = true;
      puWide = true; puWideT = puDuration;
      countWide--;
      padW = min(screenW * 0.55, 220);
      padX = padX.clamp(0, screenW - padW);
      SoundManager.instance.playWidePower();
    case PowerupType.laser:
      if (countLaser <= 0 || laserUsedThisLevel) break;
      laserUsedThisLevel = true;
      puLaser = true; puLaserT = puDuration;
      countLaser--;
      for (var b in balls) {
        b.laser = true;
        b.r = screenW * 0.03;
      }
      SoundManager.instance.playLaserPower();
    case PowerupType.flowerpot:
      if (countFlowerpot <= 0 || flowerpotUsedThisLevel) break;
      flowerpotUsedThisLevel = true;
      countFlowerpot--;
      flowerpotActive = true;
      flowerpotT = 300;
      flowerpotParticles.clear();
      padW = screenW * 0.9;
      padX = (screenW / 2) - (padW / 2);
      SoundManager.instance.playFlowerpot();
    case PowerupType.whirlgig:
  break;
    
  }
}
}
