import 'dart:math';
import 'package:flutter/material.dart';

const int puDuration = 600;

const List<Color> brickColors = [
  Color(0xFFE74C3C), Color(0xFFE67E22), Color(0xFFF1C40F),
  Color(0xFF2ECC71), Color(0xFF3498DB), Color(0xFF9B59B6),
];

enum BulletType { normal, fire, laser, whirlgig }

class Bullet {
  double x, y, vx, vy;
  BulletType type;
  Bullet({required this.x, required this.y, this.vx = 0, required this.vy, this.type = BulletType.normal});
}

enum BrickType { normal, bomb, shield, colorBomb, ice, fountain }

class Brick {
  double x, y, w, h;
  int hp, maxHp;
  Color color;
  bool alive;
  int shakeFrames;
  PowerupType? hiddenPower;
  BrickType brickType;
  bool shieldActive;
  int frozenFrames;

  Brick({required this.x, required this.y, required this.w, required this.h,
    required this.hp, required this.color, this.alive = true, this.shakeFrames = 0,
    this.hiddenPower, this.brickType = BrickType.normal,
    this.shieldActive = false, this.frozenFrames = 0}) : maxHp = hp;

  Rect get rect => Rect.fromLTWH(x, y, w, h);
  bool get isFrozen => frozenFrames > 0;
}

class Particle {
  double x, y, vx, vy, r, life, decay;
  Color color;
  Particle({required this.x, required this.y, required this.vx, required this.vy,
    required this.r, required this.color, this.life = 1.0, required this.decay});
  bool update() {
    x += vx; y += vy; vy += 0.15; life -= decay; return life > 0;
  }
}

enum PowerupType { fire, laser, whirlgig, wide, life }

class PowerupDrop {
  double x, y;
  final double vy, w, h;
  final PowerupType type;
  final String label;
  final Color color;
  PowerupDrop({required this.x, required this.y, required this.type, required this.label,
    required this.color, this.vy = 2.5, this.w = 80, this.h = 28});
  void update() => y += vy;
  Rect get rect => Rect.fromCenter(center: Offset(x, y), width: w, height: h);
}

List<Brick> makeBricks({required double screenW, required double screenH, required int level}) {
  final rng = Random();
  final bricks = <Brick>[];
  final bw = (screenW - 20) / 12;
  final bh = min(30.0, screenH * 0.055);
  final startY = screenH * 0.08;

  // Special brick colors
  const bombColor      = Color(0xFF222222);
  const shieldColor    = Color(0xFF8899BB);
  const colorBombColor = Color(0xFFFFFFFF);
  const iceColor       = Color(0xFFAAEEFF);
  const fountainColor  = Color(0xFF00DDAA);

  void addBrick(int row, int col, int colorIndex, {int hp = 1, BrickType type = BrickType.normal}) {
    Color col2;
    bool shield = false;
    switch (type) {
      case BrickType.bomb:      col2 = bombColor;       break;
      case BrickType.shield:    col2 = shieldColor;     shield = true; break;
      case BrickType.colorBomb: col2 = colorBombColor;  break;
      case BrickType.ice:       col2 = iceColor;        break;
      case BrickType.fountain:  col2 = fountainColor;   break;
      default:                  col2 = brickColors[colorIndex % brickColors.length];
    }
    bricks.add(Brick(
      x: 10 + col * bw + 2, y: startY + row * bh + 2,
      w: bw - 4, h: bh - 4, hp: hp,
      color: col2, brickType: type, shieldActive: shield,
    ));
  }

  // Scatter special bricks randomly across the grid after generation
  void scatterSpecials(int level) {
    if (bricks.isEmpty) return;
    final rng = Random();
    final total = bricks.length;
    // Chance scales with level, capped at 30% special
    final specialChance = level >= 10
        ? (0.10 + level * 0.015).clamp(0.0, 0.50)
        : level >= 5
            ? (0.06 + level * 0.012).clamp(0.0, 0.35)
            : (0.04 + level * 0.01).clamp(0.0, 0.15);
    final types = [BrickType.bomb, BrickType.shield, BrickType.colorBomb,
                   BrickType.ice, BrickType.fountain];
    // Special brick colors
    const cols = {
      BrickType.bomb:      Color(0xFF222222),
      BrickType.shield:    Color(0xFF8899BB),
      BrickType.colorBomb: Color(0xFFFFFFFF),
      BrickType.ice:       Color(0xFFAAEEFF),
      BrickType.fountain:  Color(0xFF00DDAA),
    };
    for (int i = 0; i < total; i++) {
      if (rng.nextDouble() < specialChance) {
        final t = types[rng.nextInt(types.length)];
        bricks[i].brickType = t;
        bricks[i].color = cols[t]!;
        if (t == BrickType.shield) bricks[i].shieldActive = true;
      }
    }
  }

  void addGrid(List<List<int>> grid, {int hpOverride = 0}) {
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        if (grid[r][c] == 1) {
          int hp;
          if (hpOverride > 0) {
            hp = hpOverride;
          } else if (level >= 15) {
            final r = rng.nextDouble();
            hp = r < 0.30 ? 4 : r < 0.70 ? 3 : 2;
          } else if (level >= 10) {
            final r = rng.nextDouble();
            hp = r < 0.20 ? 3 : r < 0.70 ? 2 : 1;
          } else if (level >= 5) {
            hp = rng.nextDouble() < 0.40 ? 2 : 1;
          } else {
            hp = 1;
          }
          addBrick(r, c, r, hp: hp);
        }
      }
    }
  }

  switch ((level - 1) % 100) {
    case 0: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 1: addGrid([[1,0,1,0,1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1,0,1,0,1],[1,0,1,0,1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1,0,1,0,1],[1,0,1,0,1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1,0,1,0,1]]); break;
    case 2: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 3: addGrid([[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,1,0,0,0,0,0,0,1,1,1],[0,1,1,1,0,0,0,0,1,1,1,0],[0,0,1,1,1,0,0,1,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0]]); break;
    case 4: addGrid([[1,1,0,0,0,0,0,0,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,0,0,0,0,0,0,1,1]]); break;
    case 5: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 6: addGrid([[1,1,1,0,0,0,1,1,1,0,0,0],[0,1,1,1,0,0,0,1,1,1,0,0],[0,0,1,1,1,0,0,0,1,1,1,0],[0,0,0,1,1,1,0,0,0,1,1,1],[0,0,1,1,1,0,0,0,1,1,1,0],[0,1,1,1,0,0,0,1,1,1,0,0],[1,1,1,0,0,0,1,1,1,0,0,0]]); break;
    case 7: addGrid([[1,0,1,0,1,0,1,0,1,0,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,0,0,1,1,0,0,1,1,0],[0,1,1,0,0,1,1,0,0,1,1,0]]); break;
    case 8: addGrid([[0,1,1,1,0,0,0,0,1,1,1,0],[1,1,1,1,1,0,0,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 9: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]], hpOverride: 2); break;
    case 10: addGrid([[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,0,0,0,0,0,0,1,1,1]]); break;
    case 11: addGrid([[0,0,1,1,1,1,1,1,1,0,0,0],[0,1,1,1,1,1,1,1,1,1,0,0],[1,1,1,1,1,1,1,1,0,0,0,0],[1,1,1,1,1,1,0,0,0,0,0,0],[1,1,1,1,1,1,0,0,0,0,0,0],[1,1,1,1,1,1,1,1,0,0,0,0],[0,1,1,1,1,1,1,1,1,1,0,0],[0,0,1,1,1,1,1,1,1,0,0,0]]); break;
    case 12: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 13: addGrid([[1,1,1,1,1,1,0,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,0,1,1,1,1,0,0],[0,0,0,0,0,0,0,0,1,1,1,1],[1,1,0,0,0,0,0,0,1,1,1,1],[1,1,1,1,0,0,0,0,1,1,0,0],[0,0,1,1,1,1,0,0,0,0,0,0],[0,0,0,0,1,1,1,1,1,1,1,1]]); break;
    case 14: addGrid([[0,0,1,0,0,1,1,0,0,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,0,0,1,1,0,0,1,0,0],[0,1,0,0,0,1,1,0,0,0,1,0],[1,0,0,0,0,1,1,0,0,0,0,1]]); break;
    case 15: addGrid([[0,1,1,0,0,1,1,0,0,1,1,0],[1,0,0,1,1,0,0,1,1,0,0,1],[1,0,0,1,1,0,0,1,1,0,0,1],[0,1,1,0,0,1,1,0,0,1,1,0],[1,0,0,1,1,0,0,1,1,0,0,1],[1,0,0,1,1,0,0,1,1,0,0,1],[0,1,1,0,0,1,1,0,0,1,1,0]]); break;
    case 16: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[1,1,0,1,1,1,1,1,1,0,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,0,1,1,1,1,1,1,0,1,1],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 17: addGrid([[1,1,1,0,0,0,0,0,0,1,1,1],[0,1,1,1,0,0,0,0,1,1,1,0],[0,0,1,1,1,0,0,1,1,1,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,1,1,1,0,0,1,1,1,0,0],[0,1,1,1,0,0,0,0,1,1,1,0],[1,1,1,0,0,0,0,0,0,1,1,1]]); break;
    case 18: addGrid([[0,1,1,0,0,1,1,0,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,0,1,1,0,1,1,0,1,1,0],[1,1,0,1,1,0,1,1,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,1,1,0,0,1,1,0,0,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 19: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,0,1,0,0,0,0,1,0,1,1],[0,1,1,0,1,1,1,1,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 20: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,0,0,1,1,1,1,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 21: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,0,0,1,0,0,0,0,1,0,0,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,0,0,1,1,1,1,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 22: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,1,1,0,0,0,1,0,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,0,1,0,0,0,0,1,0,1,1],[0,1,1,0,1,1,1,1,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 23: addGrid([[0,1,1,1,1,1,1,1,1,1,1,0],[0,1,0,0,0,0,0,0,0,0,1,0],[0,1,0,1,1,0,0,1,1,0,1,0],[0,1,0,1,1,0,0,1,1,0,1,0],[0,1,0,0,0,0,0,0,0,0,1,0],[0,1,0,1,0,1,1,0,1,0,1,0],[0,1,0,0,1,1,1,1,0,0,1,0],[0,1,1,1,1,1,1,1,1,1,1,0]]); break;
    case 24: addGrid([[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,0,0,1,0,0,1,0,0,1,1],[0,1,1,0,0,1,1,0,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 25: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,0,1,1,1,1,1,1,0,1,1],[1,1,0,1,1,1,1,1,1,0,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,0,1,1,1,1,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 26: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,1,1,0,1,1,0,1,1,0,1]]); break;
    case 27: addGrid([[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,1,1,0,0,1,1,1,1,0],[1,1,0,1,1,1,1,1,1,0,1,1],[1,1,0,1,1,1,1,1,1,0,1,1],[1,1,1,1,0,1,1,0,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,0,0,1,1,1,1,0,0,0,0]]); break;
    case 28: addGrid([[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,1,1,1,1,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,1,0,1,0,0,1,0,1,0,1],[0,0,1,0,0,1,1,0,0,1,0,0]]); break;
    case 29: addGrid([[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,0,0,1,0,0,1,0,0,1,1],[0,1,1,0,0,1,1,0,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 30: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,0,0,0,1,1,1,1,0,0,0,1],[1,0,0,1,1,1,1,1,1,0,0,1],[1,0,0,1,1,1,1,1,1,0,0,1],[1,0,0,0,1,1,1,1,0,0,0,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 31: addGrid([[1,0,0,0,0,1,1,0,0,0,0,1],[0,1,0,0,0,1,1,0,0,0,1,0],[0,0,1,0,0,1,1,0,0,1,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,1,0,0,1,1,0,0,1,0,0],[0,1,0,0,0,1,1,0,0,0,1,0],[1,0,0,0,0,1,1,0,0,0,0,1]]); break;
    case 32: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,0,0,0,1,1,0,0,0,1,1],[1,0,0,0,0,1,1,0,0,0,0,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,0,0,0,1,1,0,0,0,0,1],[1,1,0,0,0,1,1,0,0,0,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 33: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,0,0,0,0,0,0,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,0,0,0,0,0,0,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,0,0,0,0,0,0,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 34: addGrid([[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,1,1,0,1,1,0,1,1,0,0],[0,1,0,1,1,1,1,1,1,0,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,0,1,1,1,1,1,1,0,1,0],[0,0,1,1,0,1,1,0,1,1,0,0],[0,0,0,0,1,1,1,1,0,0,0,0]]); break;
    case 35: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,0,0,0,0,0,0,1,1]]); break;
    case 36: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 37: addGrid([[1,0,1,0,0,0,0,0,0,1,0,1],[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,0,0,1,1,0,0,1,1,0],[0,1,1,0,0,1,1,0,0,1,1,0],[0,1,1,1,1,1,1,1,1,1,1,0]]); break;
    case 38: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,0,1,0,1,1,0,1,0,1,0],[0,1,0,1,0,1,1,0,1,0,1,0],[0,1,0,1,0,1,1,0,1,0,1,0],[0,1,0,1,0,1,1,0,1,0,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,1,1,1,1,1,1,0,0,0]]); break;
    case 39: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 40: addGrid([[0,1,0,0,0,0,0,0,0,0,1,0],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,0,0,1,0,0,0,0,1,0,0,1]]); break;
    case 41: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,1,1,0,0,1,1,0],[1,1,0,0,0,1,1,0,0,0,1,1]]); break;
    case 42: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 43: addGrid([[1,1,0,0,0,0,0,0,0,0,0,0],[1,1,1,0,0,0,0,0,0,0,0,0],[1,1,1,1,1,1,1,1,1,1,0,0],[1,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,0,0],[1,1,1,0,0,0,0,0,0,0,0,0],[1,1,0,0,0,0,0,0,0,0,0,0]]); break;
    case 44: addGrid([[1,1,1,0,0,0,0,0,0,1,1,1],[1,1,1,1,0,0,0,0,1,1,1,1],[0,1,1,1,1,0,0,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,0,0,1,1,1,1,0],[1,1,1,1,0,0,0,0,1,1,1,1],[1,1,1,0,0,0,0,0,0,1,1,1]]); break;
    case 45: addGrid([[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,1,1,0,0,1,1,1,1,0],[1,1,0,1,1,1,1,1,1,0,1,1],[1,0,0,0,1,1,1,1,0,0,0,1],[1,1,0,1,1,1,1,1,1,0,1,1],[0,1,1,1,1,0,0,1,1,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0]]); break;
    case 46: addGrid([[0,1,0,0,0,1,1,0,0,0,1,0],[0,0,1,0,1,1,1,1,0,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,0,1,1,1,1,0,1,0,0],[0,1,0,0,0,1,1,0,0,0,1,0]]); break;
    case 47: addGrid([[0,0,0,1,1,1,1,0,0,0,0,0],[0,0,1,1,1,1,1,1,0,0,0,0],[0,1,1,1,0,0,0,1,1,0,0,0],[0,1,1,0,0,0,0,0,1,0,0,0],[0,1,1,0,0,0,0,0,1,0,0,0],[0,1,1,1,0,0,0,1,1,0,0,0],[0,0,1,1,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,0,0,0,0,0]]); break;
    case 48: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,1,0,0,0,1,1,0,0,0,1,0],[0,0,1,0,1,1,1,1,0,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,0,1,1,1,1,0,1,0,0],[0,1,0,0,0,1,1,0,0,0,1,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 49: addGrid([[1,0,0,0,0,1,1,0,0,0,0,1],[0,1,0,0,1,1,1,1,0,0,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,1,0,1,1,1,1,0,1,0,0],[0,1,1,0,0,1,1,0,0,1,1,0],[1,1,0,0,0,1,1,0,0,0,1,1]]); break;
    case 50: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,0,1,1,1,1,1,1,0,0,1],[0,0,0,0,1,0,0,1,0,0,0,0]]); break;
    case 51: addGrid([[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,0,1,1,1,1,1,1,0,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,0,1,1,1,1,1,1,0,0,0],[1,0,0,0,0,0,0,0,0,0,0,1]]); break;
    case 52: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,0,0,0,0,0,0,1,1]]); break;
    case 53: addGrid([[0,0,0,0,0,0,1,1,1,1,1,1],[0,0,0,0,0,1,1,1,1,1,1,0],[0,0,0,0,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,0,0,0,0,0],[0,1,1,1,1,0,0,0,0,0,0,0],[1,1,1,0,0,0,0,0,0,0,0,0],[1,0,0,0,0,0,0,0,0,0,0,0]]); break;
    case 54: addGrid([[0,1,1,1,0,0,0,1,1,1,0,0],[1,1,1,1,1,0,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,0],[0,1,1,1,1,1,1,1,1,1,0,0],[0,0,1,1,1,1,1,1,1,0,0,0],[0,0,0,1,1,1,1,1,0,0,0,0],[0,0,0,0,1,1,1,0,0,0,0,0],[0,0,0,0,0,1,0,0,0,0,0,0]]); break;
    case 55: addGrid([[1,0,0,1,0,0,0,0,1,0,0,1],[1,1,1,1,1,0,0,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 56: addGrid([[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,1,1,0,0,1,1,0,0,1,1,0],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,0,1,1,0,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0]]); break;
    case 57: addGrid([[0,0,1,1,1,1,0,0,0,0,0,0],[0,1,1,0,0,1,1,0,0,0,0,0],[1,1,0,0,0,0,1,1,0,0,0,0],[0,1,1,0,0,1,1,0,0,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,0,0,0,0,1,0,1,0,0],[0,0,0,0,0,0,0,1,1,1,0,0]]); break;
    case 58: addGrid([[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 59: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 60: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 61: addGrid([[0,0,0,0,1,1,1,1,1,0,0,0],[0,0,0,1,1,1,1,0,0,0,0,0],[0,0,1,1,1,0,0,0,0,0,0,0],[0,1,1,1,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,1,1,0,0,0],[0,0,0,0,0,0,1,1,1,1,0,0],[0,0,0,0,0,0,0,1,1,0,0,0]]); break;
    case 62: addGrid([[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[0,1,1,0,0,0,0,0,0,1,1,0],[0,1,1,0,0,1,1,0,0,1,1,0],[0,1,1,0,0,0,0,0,0,1,1,0],[0,1,1,1,1,1,1,1,1,1,1,0]]); break;
    case 63: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 64: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,0,0,0,0,0,0,0,0,0,1],[1,0,1,1,1,1,1,1,1,1,0,1],[1,0,1,0,0,0,0,0,0,1,0,1],[1,0,1,0,1,1,1,0,0,1,0,1],[1,0,1,0,0,0,1,0,0,1,0,1],[1,0,1,1,1,1,1,0,0,1,0,1],[1,0,0,0,0,0,0,0,0,1,0,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 65: addGrid([[0,0,1,1,1,0,0,1,1,1,0,0],[0,1,1,0,1,1,1,1,0,1,1,0],[1,1,0,0,0,1,1,0,0,0,1,1],[1,1,0,0,0,1,1,0,0,0,1,1],[0,1,1,0,1,1,1,1,0,1,1,0],[0,0,1,1,1,0,0,1,1,1,0,0]]); break;
    case 66: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,1,1,1,1,0,0,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[1,1,0,0,1,1,1,1,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 67: addGrid([[1,1,0,0,0,0,0,0,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,0,0,0,0,0,0,1,1]]); break;
    case 68: addGrid([[1,0,1,0,1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1,0,1,0,1],[1,0,1,0,1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1,0,1,0,1],[1,0,1,0,1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1,0,1,0,1],[1,0,1,0,1,0,1,0,1,0,1,0],[0,1,0,1,0,1,0,1,0,1,0,1]]); break;
    case 69: addGrid([[1,1,0,0,0,0,0,0,0,0,0,0],[1,1,1,1,0,0,0,0,0,0,0,0],[1,1,1,1,1,1,0,0,0,0,0,0],[1,1,1,1,1,1,1,1,0,0,0,0],[1,1,1,1,1,1,1,1,1,1,0,0],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 70: addGrid([[1,1,1,1,0,0,0,0,0,0,0,0],[0,1,1,1,1,0,0,0,0,0,0,0],[0,0,1,1,1,1,0,0,0,0,0,0],[0,0,0,1,1,1,1,1,1,1,1,1],[0,0,0,0,0,0,1,1,1,1,0,0],[0,0,0,0,0,0,0,1,1,1,1,0],[0,0,0,0,0,0,0,0,1,1,1,1],[1,1,1,1,1,1,1,1,0,0,0,0]]); break;
    case 71: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 72: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,0,1,1,0,0,0,1,1],[1,1,0,0,1,1,1,1,0,0,1,1],[1,1,0,1,1,0,0,1,1,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 73: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0]]); break;
    case 74: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,0,1,1,0,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0]]); break;
    case 75: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,1,0,0,1,1,1,1,0,0,1,0],[1,0,1,1,0,1,1,0,1,1,0,1],[1,0,1,1,1,1,1,1,1,1,0,1],[1,0,1,1,0,1,1,0,1,1,0,1],[0,1,0,0,1,1,1,1,0,0,1,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 76: addGrid([[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,1,1,1,1,0,0,1,1,0],[1,1,1,1,1,0,0,0,0,0,1,1],[1,1,1,1,0,1,1,0,0,0,1,1],[1,1,0,0,0,1,1,0,1,1,1,1],[1,1,0,0,0,0,0,1,1,1,1,1],[0,1,1,0,0,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 77: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,0,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,1,1,1,1,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 78: addGrid([[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 79: addGrid([[0,0,0,0,1,1,1,1,1,1,1,0],[0,0,0,0,1,1,0,0,0,1,1,0],[0,0,0,0,1,1,0,0,0,1,1,0],[0,0,0,0,1,1,0,0,0,1,1,0],[0,0,1,1,1,1,0,0,1,1,1,0],[0,1,1,1,1,0,0,1,1,1,0,0],[0,0,0,0,0,0,0,0,0,0,0,0]]); break;
    case 80: addGrid([[1,0,1,0,1,0,1,0,1,0,1,0],[1,0,1,0,1,0,1,0,1,0,1,0],[1,0,1,0,1,0,1,0,1,0,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 81: addGrid([[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,1,1,1,1,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,0,1,0,0,0,0,1,0,1,0]]); break;
    case 82: addGrid([[0,0,0,0,0,1,0,0,0,0,0,0],[0,0,0,0,1,1,0,0,0,0,0,0],[0,0,0,1,1,1,1,1,0,0,0,0],[0,0,1,1,1,1,1,1,1,0,0,0],[0,1,1,1,1,1,1,1,1,1,0,0],[1,1,1,1,1,1,1,1,1,1,1,0],[0,1,1,1,1,1,1,1,1,1,0,0]]); break;
    case 83: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,0,1,0,1,0,1,0,1,0,1]]); break;
    case 84: addGrid([[1,0,0,0,0,0,0,0,0,0,0,1],[1,1,0,0,0,0,0,0,0,0,1,1],[1,1,1,0,1,1,1,1,0,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,0,0,1,1,1,1,0,0,0,0]]); break;
    case 85: addGrid([[1,0,0,1,0,0,0,0,1,0,0,1],[0,1,1,1,1,0,0,1,1,1,1,0],[1,1,0,1,1,1,1,1,1,0,1,1],[1,0,0,0,1,1,1,1,0,0,0,1],[0,1,1,0,1,1,1,1,0,1,1,0],[1,0,0,1,0,0,0,0,1,0,0,1]]); break;
    case 86: addGrid([[0,0,0,0,1,1,1,1,1,0,0,0],[0,0,0,1,1,1,1,1,1,1,0,0],[0,0,1,1,1,0,0,1,1,1,1,0],[0,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,0,1,1,0,1,1,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0]]); break;
    case 87: addGrid([[1,0,0,0,0,1,1,0,0,0,0,1],[1,1,0,0,1,1,1,1,0,0,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,0,0,1,1,0,0,1,0,0]]); break;
    case 88: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,1,0,1,0,0,1,0,1,0,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,0,1,0,1,1,0,1,0,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,1,0,1,0,0,1,0,1,0,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 89: addGrid([[1,1,1,1,1,0,0,1,1,1,1,1],[1,0,0,0,1,0,0,1,0,0,0,1],[1,0,1,0,1,1,1,1,0,1,0,1],[1,0,1,0,0,0,0,0,0,1,0,1],[1,0,1,1,1,1,1,1,1,1,0,1],[1,0,0,0,0,0,0,0,0,0,0,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 90: addGrid([[0,0,0,1,1,1,1,0,0,0,0,0],[0,0,1,1,1,1,1,1,0,0,0,0],[0,1,1,1,1,1,1,1,1,0,0,0],[1,1,1,1,1,0,0,0,0,0,0,0],[1,1,1,1,1,1,0,0,0,0,0,0],[0,1,1,1,1,1,1,1,0,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0]]); break;
    case 91: addGrid([[0,0,0,1,1,0,0,1,1,0,0,0],[0,1,1,1,1,1,1,1,1,1,1,0],[1,1,1,0,1,1,1,1,0,1,1,1],[1,1,0,0,1,1,1,1,0,0,1,1],[1,1,1,0,1,1,1,1,0,1,1,1],[0,1,1,1,1,1,1,1,1,1,1,0],[0,0,0,1,1,0,0,1,1,0,0,0]]); break;
    case 92: addGrid([[1,1,0,0,0,0,0,0,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,0,0,0,0,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 93: addGrid([[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,1,0,1,0,0,1,0,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,1,1,1,1,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[0,1,0,1,0,0,0,0,1,0,1,0],[0,0,1,1,1,1,1,1,1,1,0,0]]); break;
    case 94: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,1,0,1,0,1,1,0,1,0,1,0],[1,1,1,0,0,1,1,0,0,1,1,1],[0,1,0,1,0,1,1,0,1,0,1,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 95: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 96: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,0,0,1,0,0,0,0],[0,0,0,1,0,1,1,0,1,0,0,0],[0,0,1,0,1,0,0,1,0,1,0,0],[0,1,0,1,0,0,0,0,1,0,1,0],[1,0,1,0,0,0,0,0,0,1,0,1],[0,1,0,1,0,0,0,0,1,0,1,0],[0,0,1,0,1,0,0,1,0,1,0,0],[0,0,0,1,0,1,1,0,1,0,0,0],[0,0,0,0,1,0,0,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    case 97: addGrid([[1,1,0,0,0,0,0,0,0,0,1,1],[0,1,1,0,0,0,0,0,0,1,1,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,0,0,1,1,0,0,0],[0,0,1,1,0,0,0,0,1,1,0,0],[0,1,1,0,0,0,0,0,0,1,1,0],[1,1,0,0,0,0,0,0,0,0,1,1]]); break;
    case 98: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,1,0,1,0,0,1,0,1,0,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,0,1,0,1,1,0,1,0,0,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,1,0,1,0,0,1,0,1,0,1],[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,0,1,0,1,1,0,1,0,0,1],[1,1,1,1,1,1,1,1,1,1,1,1]]); break;
    case 99: addGrid([[0,0,0,0,0,1,1,0,0,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,1,1,0,1,1,0,1,1,0,0],[0,1,1,0,1,1,1,1,0,1,1,0],[1,1,1,1,1,1,1,1,1,1,1,1],[0,1,1,0,1,1,1,1,0,1,1,0],[0,0,1,1,0,1,1,0,1,1,0,0],[0,0,0,1,1,1,1,1,1,0,0,0],[0,0,0,0,1,1,1,1,0,0,0,0],[0,0,0,0,0,1,1,0,0,0,0,0]]); break;
    default: addGrid([[1,1,1,1,1,1,1,1,1,1,1,1],[1,0,1,0,1,0,0,1,0,1,0,1],[1,1,0,1,0,1,1,0,1,0,1,1],[1,1,1,1,1,1,1,1,1,1,1,1]], hpOverride: 2); break;
  }
  // From level 5: add extra dense rows to force more shooting
  if (level >= 20) {
    for (int r = 0; r < 3; r++)
      for (int c = 0; c < 12; c++)
        addBrick(r + 8, c, r + 4, hp: 3 + rng.nextInt(2));
  } else if (level >= 10) {
    for (int r = 0; r < 2; r++)
      for (int c = 0; c < 12; c++)
        addBrick(r + 8, c, r + 3, hp: 2 + rng.nextInt(2));
  } else if (level >= 5) {
    for (int c = 0; c < 12; c++)
      addBrick(8, c, 5, hp: 2);
  }

  scatterSpecials(level);
  return bricks;
}

PowerupDrop? trySpawnDrop(double x, double y, double screenW, {int level = 1}) {
  final rng = Random();
  if (rng.nextDouble() > 0.30) return null;
  final types = <PowerupDrop>[
    PowerupDrop(x: x, y: y, type: PowerupType.wide,     label: '↔', color: const Color(0xFF00FF88), w: 18, h: 18),
    if (level >= 5)
      PowerupDrop(x: x, y: y, type: PowerupType.fire,     label: '🔥', color: const Color(0xFFFF4444), w: 18, h: 18),
    if (level >= 10)
      PowerupDrop(x: x, y: y, type: PowerupType.laser,    label: '⚡', color: const Color(0xFFFFE500), w: 18, h: 18),
    if (level >= 25)
      PowerupDrop(x: x, y: y, type: PowerupType.whirlgig, label: '🌀', color: const Color(0xFFCC44FF), w: 18, h: 18),
  ];
  if (types.isEmpty) return null;
  return types[rng.nextInt(types.length)];
}

void spawnParticles(List<Particle> list, double x, double y, Color color, int n) {
  final rng = Random();
  for (int i = 0; i < n; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final s = 1 + rng.nextDouble() * 6;
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 2 + rng.nextDouble() * 5, color: color, decay: 0.025 + rng.nextDouble() * 0.04));
  }
}

// ── Typed explosion spawners ───────────────────────────────────────────────

// Normal bullet: clean white/cyan shards — sharp radial burst
void spawnNormalExplosion(List<Particle> list, double x, double y, Color brickColor) {
  final rng = Random();
  // Brick color chunks
  for (int i = 0; i < 6; i++) {
    final a = (i / 6) * pi * 2 + rng.nextDouble() * 0.3;
    final s = 3.5 + rng.nextDouble() * 5.0;
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s - 1,
      r: 3 + rng.nextDouble() * 3, color: brickColor, decay: 0.022 + rng.nextDouble() * 0.02));
  }
  // Cyan sparks
  for (int i = 0; i < 3; i++) {
    final a = rng.nextDouble() * pi * 2;
    final s = 5 + rng.nextDouble() * 4;
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 1.5 + rng.nextDouble() * 1.5, color: const Color(0xFF00FFFF), decay: 0.035 + rng.nextDouble() * 0.03));
  }
}

// Fire bullet: blazing orange/red/yellow burst + ember shower
void spawnFireExplosion(List<Particle> list, double x, double y, Color brickColor) {
  final rng = Random();
  // Big hot core flash
  for (int i = 0; i < 8; i++) {
    final a = rng.nextDouble() * pi * 2;
    final s = 4 + rng.nextDouble() * 9;
    final colors = [const Color(0xFFFF2200), const Color(0xFFFF6600), const Color(0xFFFFAA00), const Color(0xFFFFFF88)];
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s - 2,
      r: 4 + rng.nextDouble() * 5, color: colors[i % colors.length], decay: 0.018 + rng.nextDouble() * 0.025));
  }
  // Ember shower — small slow upward
  for (int i = 0; i < 5; i++) {
    final a = -pi * 0.5 + (rng.nextDouble() - 0.5) * pi * 1.4;
    final s = 2 + rng.nextDouble() * 5;
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s - 1,
      r: 1.5 + rng.nextDouble() * 2, color: const Color(0xFFFF8800).withOpacity(0.9), decay: 0.012 + rng.nextDouble() * 0.018));
  }
  // Brick color shards
  for (int i = 0; i < 8; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (3 + rng.nextDouble() * 4), vy: sin(a) * (3 + rng.nextDouble() * 4),
      r: 3 + rng.nextDouble() * 3, color: brickColor, decay: 0.02 + rng.nextDouble() * 0.02));
  }
}

// Laser bullet: electric yellow/white spike burst — sharp, fast, linear
void spawnLaserExplosion(List<Particle> list, double x, double y, Color brickColor) {
  final rng = Random();
  // Tight vertical spike beams
  for (int i = 0; i < 4; i++) {
    final a = -pi * 0.5 + (rng.nextDouble() - 0.5) * 0.7;
    final s = 8 + rng.nextDouble() * 10;
    list.add(Particle(x: x, y: y, vx: cos(a) * s * 0.3, vy: sin(a) * s,
      r: 1.5 + rng.nextDouble() * 1.5, color: const Color(0xFFFFFF00), decay: 0.04 + rng.nextDouble() * 0.03));
  }
  // Wide electric shards
  for (int i = 0; i < 7; i++) {
    final a = rng.nextDouble() * pi * 2;
    final s = 5 + rng.nextDouble() * 8;
    final colors = [const Color(0xFFFFFF00), const Color(0xFFFFFFAA), const Color(0xFFAAFFFF), Colors.white];
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 2 + rng.nextDouble() * 2.5, color: colors[i % colors.length], decay: 0.03 + rng.nextDouble() * 0.025));
  }
  // Brick color dust
  for (int i = 0; i < 3; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (2 + rng.nextDouble() * 3), vy: sin(a) * (2 + rng.nextDouble() * 3),
      r: 2.5 + rng.nextDouble() * 2, color: brickColor, decay: 0.018 + rng.nextDouble() * 0.02));
  }
}

// Whirlgig bullet: swirling purple/pink/violet rings
void spawnWhirlgigExplosion(List<Particle> list, double x, double y, Color brickColor) {
  final rng = Random();
  // Spiral outward in rings
  for (int ring = 0; ring < 3; ring++) {
    final count = 4 + ring * 2;
    for (int i = 0; i < count; i++) {
      final a = (i / count) * pi * 2 + ring * 0.4;
      final s = 3.0 + ring * 2.5 + rng.nextDouble() * 2;
      final colors = [const Color(0xFFCC44FF), const Color(0xFFFF44CC), const Color(0xFF8844FF), const Color(0xFFFF88FF)];
      list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
        r: 2.5 + rng.nextDouble() * 2.5, color: colors[(ring + i) % colors.length],
        decay: 0.015 + rng.nextDouble() * 0.02 - ring * 0.003));
    }
  }
  // White glitter center pop
  for (int i = 0; i < 4; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (6 + rng.nextDouble() * 5), vy: sin(a) * (6 + rng.nextDouble() * 5),
      r: 1.5 + rng.nextDouble() * 1.5, color: Colors.white, decay: 0.04 + rng.nextDouble() * 0.03));
  }
  // Brick shards
  for (int i = 0; i < 4; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (2 + rng.nextDouble() * 4), vy: sin(a) * (2 + rng.nextDouble() * 4),
      r: 3 + rng.nextDouble() * 2, color: brickColor, decay: 0.02 + rng.nextDouble() * 0.02));
  }
}

// ── Special brick explosion spawners ──────────────────────────────────────

// Bomb: dark fiery shockwave + debris
void spawnBombExplosion(List<Particle> list, double x, double y) {
  final rng = Random();
  // Shockwave ring — many fast dark/orange particles
  for (int i = 0; i < 10; i++) {
    final a = (i / 10) * pi * 2;
    final s = 8 + rng.nextDouble() * 8;
    final colors = [const Color(0xFFFF2200), const Color(0xFFFF6600), const Color(0xFF222222), const Color(0xFFFFAA00)];
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 4 + rng.nextDouble() * 5, color: colors[i % colors.length], decay: 0.012 + rng.nextDouble() * 0.015));
  }
  // Smoke puffs — slow dark blobs
  for (int i = 0; i < 5; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (1 + rng.nextDouble() * 3), vy: sin(a) * (1 + rng.nextDouble() * 3) - 2,
      r: 6 + rng.nextDouble() * 7, color: const Color(0xFF444444).withOpacity(0.7), decay: 0.008 + rng.nextDouble() * 0.01));
  }
  // White flash center
  for (int i = 0; i < 3; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (10 + rng.nextDouble() * 5), vy: sin(a) * (10 + rng.nextDouble() * 5),
      r: 2 + rng.nextDouble() * 2, color: Colors.white, decay: 0.06 + rng.nextDouble() * 0.04));
  }
}

// Shield break: metallic silver/blue shards sparkling outward
void spawnShieldBreak(List<Particle> list, double x, double y) {
  final rng = Random();
  for (int i = 0; i < 18; i++) {
    final a = (i / 18) * pi * 2 + rng.nextDouble() * 0.2;
    final s = 4 + rng.nextDouble() * 6;
    final colors = [const Color(0xFF8899BB), const Color(0xFFCCDDFF), const Color(0xFFAABBDD), Colors.white];
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 2 + rng.nextDouble() * 4, color: colors[i % colors.length], decay: 0.018 + rng.nextDouble() * 0.02));
  }
  // Sparkle flash
  for (int i = 0; i < 8; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (8 + rng.nextDouble() * 6), vy: sin(a) * (8 + rng.nextDouble() * 6),
      r: 1.5, color: Colors.white, decay: 0.05 + rng.nextDouble() * 0.04));
  }
}

// Color bomb: rainbow confetti explosion
void spawnColorBombExplosion(List<Particle> list, double x, double y) {
  final rng = Random();
  final rainbow = [
    const Color(0xFFFF0000), const Color(0xFFFF8800), const Color(0xFFFFFF00),
    const Color(0xFF00FF00), const Color(0xFF0088FF), const Color(0xFF8800FF),
    const Color(0xFFFF00FF), Colors.white,
  ];
  for (int i = 0; i < 36; i++) {
    final a = (i / 36) * pi * 2 + rng.nextDouble() * 0.15;
    final s = 5 + rng.nextDouble() * 10;
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 3 + rng.nextDouble() * 4, color: rainbow[i % rainbow.length], decay: 0.012 + rng.nextDouble() * 0.018));
  }
}

// Ice: crystalline blue/white shards + freeze sparkles
void spawnIceShatter(List<Particle> list, double x, double y) {
  final rng = Random();
  // Crystal shards — angular fast
  for (int i = 0; i < 20; i++) {
    final a = (i / 20) * pi * 2;
    final s = 5 + rng.nextDouble() * 7;
    final blues = [const Color(0xFFAAEEFF), const Color(0xFF66CCFF), const Color(0xFFDDFFFF), Colors.white];
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 2 + rng.nextDouble() * 3.5, color: blues[i % blues.length], decay: 0.02 + rng.nextDouble() * 0.022));
  }
  // Freeze sparkles — tiny white dots drifting slowly
  for (int i = 0; i < 12; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (1 + rng.nextDouble() * 3), vy: sin(a) * (1 + rng.nextDouble() * 3) - 1,
      r: 1.2 + rng.nextDouble() * 1.5, color: Colors.white, decay: 0.008 + rng.nextDouble() * 0.01));
  }
}

// Fountain: upward water/sparkle geyser
void spawnFountainBurst(List<Particle> list, double x, double y) {
  final rng = Random();
  // Upward geyser jet
  for (int i = 0; i < 20; i++) {
    final a = -pi * 0.5 + (rng.nextDouble() - 0.5) * pi * 0.9;
    final s = 6 + rng.nextDouble() * 10;
    final cols = [const Color(0xFF00DDAA), const Color(0xFF00FFCC), const Color(0xFF44FFDD), const Color(0xFFAAFFEE)];
    list.add(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
      r: 2.5 + rng.nextDouble() * 3.5, color: cols[i % cols.length], decay: 0.013 + rng.nextDouble() * 0.018));
  }
  // Glittering mist — tiny slow particles all directions
  for (int i = 0; i < 14; i++) {
    final a = rng.nextDouble() * pi * 2;
    list.add(Particle(x: x, y: y, vx: cos(a) * (1 + rng.nextDouble() * 2.5), vy: sin(a) * (1 + rng.nextDouble() * 2.5) - 1.5,
      r: 1.5 + rng.nextDouble() * 2, color: const Color(0xFFAAFFEE).withOpacity(0.8), decay: 0.01 + rng.nextDouble() * 0.012));
  }
}
