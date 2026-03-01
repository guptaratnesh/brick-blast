import 'dart:math';
import 'package:flutter/material.dart';

// ── Constants ──────────────────────────────────────────────────────────────
const int puDuration = 600; // frames

// ── Colors ─────────────────────────────────────────────────────────────────
const List<Color> brickColors = [
  Color(0xFFE74C3C),
  Color(0xFFE67E22),
  Color(0xFFF1C40F),
  Color(0xFF2ECC71),
  Color(0xFF3498DB),
  Color(0xFF9B59B6),
];

// ── Ball ───────────────────────────────────────────────────────────────────
class Ball {
  double x, y, vx, vy, r;
  bool fire;
  bool laser;
  final List<Offset> trail = [];

  Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    this.fire = false,
    this.laser = false,
  });

  void update() {
    trail.add(Offset(x, y));
    if (trail.length > 10) trail.removeAt(0);
    x += vx;
    y += vy;
  }
}

// ── Brick ──────────────────────────────────────────────────────────────────
class Brick {
  double x, y, w, h;
  int hp, maxHp;
  Color color;
  bool alive;
  int shakeFrames;
  PowerupType? hiddenPower; // null means no hidden power

  
  Brick({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.hp,
    required this.color,
    this.alive = true,
    this.shakeFrames = 0,
    this.hiddenPower,
  }) : maxHp = hp;

  Rect get rect => Rect.fromLTWH(x, y, w, h);
}

// ── Particle ───────────────────────────────────────────────────────────────
class Particle {
  double x, y, vx, vy, r, life, decay;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.color,
    this.life = 1.0,
    required this.decay,
  });

  bool update() {
    x += vx;
    y += vy;
    vy += 0.15;
    life -= decay;
    return life > 0;
  }
}

// ── Powerup drop ───────────────────────────────────────────────────────────
enum PowerupType { fire, big, multi, life, wide, laser, whirlgig, flowerpot, magnet, gun }
class PowerupDrop {
  double x, y;
  final double vy;
  final double w, h;
  final PowerupType type;
  final String label;
  final Color color;

  PowerupDrop({
    required this.x,
    required this.y,
    required this.type,
    required this.label,
    required this.color,
    this.vy = 2.5,
    this.w = 80,
    this.h = 28,
  });

  void update() => y += vy;

  Rect get rect => Rect.fromCenter(
        center: Offset(x, y),
        width: w,
        height: h,
      );
}

// ── Factory helpers ────────────────────────────────────────────────────────
Ball makeBall({
  required double screenW,
  required double padY,
  double? x,
  double? y,
  double? vx,
  double? vy,
  required int level,
  bool big = false,
  bool fire = false,
}) {
  final rng = Random();
  final speed = 6.0 + level * 0.4;
  final angle = -pi / 2 + (rng.nextDouble() - 0.5) * 0.8;
  return Ball(
    x: x ?? screenW / 2,
    y: y ?? padY - 14,
    vx: vx ?? cos(angle) * speed,
    vy: vy ?? sin(angle) * speed,
    r: big ? screenW * 0.045 : screenW * 0.022,
    fire: fire,
  );
}


List<Brick> makeBricks({
  required double screenW,
  required double screenH,
  required int level,
}) {
  final rng = Random();
  final bricks = <Brick>[];
  final bw = (screenW - 20) / 12;
  final bh = min(30.0, screenH * 0.055);
  final startY = screenH * 0.18;

  void addBrick(int row, int col, int colorIndex, {int hp = 1}) {
    bricks.add(Brick(
      x: 10 + col * bw + 2,
      y: startY + row * bh + 2,
      w: bw - 4,
      h: bh - 4,
      hp: hp,
      color: brickColors[colorIndex % brickColors.length],
    ));
  }

  void addGrid(List<List<int>> grid, {int hpOverride = 0}) {
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        if (grid[r][c] == 1) {
          final hp = hpOverride > 0
              ? hpOverride
              : (level > 3 && rng.nextDouble() < 0.25 ? 2 : 1);
          addBrick(r, c, r, hp: hp);
        }
      }
    }
  }

  
  switch ((level - 1) % 30) {

    case 0: // Level 1 — Classic full rows
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ]);
      break;

    case 1: // Level 2 — Checkerboard
      addGrid([
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1,0,1,0,1],
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [0,1,0,1,0,1,0,1,0,1,0,1],
      ]);
      break;

    case 2: // Level 3 — Diamond
      addGrid([
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
      ]);
      break;

    case 3: // Level 4 — V shape
      addGrid([
        [1,1,0,0,0,0,0,0,0,0,1,1],
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [0,1,1,1,0,0,0,0,1,1,1,0],
        [0,0,1,1,1,0,0,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
      ]);
      break;

    case 4: // Level 5 — X cross
      addGrid([
        [1,1,0,0,0,0,0,0,0,0,1,1],
        [0,1,1,0,0,0,0,0,0,1,1,0],
        [0,0,1,1,0,0,0,0,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,0,0,0,0,1,1,0,0],
        [0,1,1,0,0,0,0,0,0,1,1,0],
        [1,1,0,0,0,0,0,0,0,0,1,1],
      ]);
      break;

    case 5: // Level 6 — Pyramid
      addGrid([
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ]);
      break;

    case 6: // Level 7 — Zigzag
      addGrid([
        [1,1,1,0,0,0,1,1,1,0,0,0],
        [0,1,1,1,0,0,0,1,1,1,0,0],
        [0,0,1,1,1,0,0,0,1,1,1,0],
        [0,0,0,1,1,1,0,0,0,1,1,1],
        [0,0,1,1,1,0,0,0,1,1,1,0],
        [0,1,1,1,0,0,0,1,1,1,0,0],
        [1,1,1,0,0,0,1,1,1,0,0,0],
      ]);
      break;

    case 7: // Level 8 — Castle
      addGrid([
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,0,0,1,1,0,0,1,1,0],
        [0,1,1,0,0,1,1,0,0,1,1,0],
        [0,1,1,0,0,1,1,0,0,1,1,0],
      ]);
      break;

    case 8: // Level 9 — Heart
      addGrid([
        [0,1,1,1,0,0,0,0,1,1,1,0],
        [1,1,1,1,1,0,0,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
      ]);
      break;

    case 9: // Level 10 — Full hard bricks
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ], hpOverride: 2);
      break;

    case 10: // Level 11 — Two columns
      addGrid([
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [1,1,1,0,0,0,0,0,0,1,1,1],
      ]);
      break;

    case 11: // Level 12 — Arrow up
      addGrid([
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,0,0,1,1,0,0,0],
        [0,0,1,1,0,0,0,0,1,1,0,0],
        [0,1,1,0,0,0,0,0,0,1,1,0],
        [1,1,0,0,0,0,0,0,0,0,1,1],
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
      ]);
      break;

    case 12: // Level 13 — Hourglass
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ]);
      break;

    case 13: // Level 14 — Cross plus
      addGrid([
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
      ]);
      break;

    case 14: // Level 15 — Spiral
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,0,0,0,0,0,0,0,0,0,1],
        [1,0,1,1,1,1,1,1,1,1,0,1],
        [1,0,1,0,0,0,0,0,0,1,0,1],
        [1,0,1,0,1,1,1,1,0,1,0,1],
        [1,0,1,0,1,0,0,1,0,1,0,1],
        [1,0,1,0,1,1,1,1,0,1,0,1],
        [1,0,1,0,0,0,0,0,0,1,0,1],
        [1,0,1,1,1,1,1,1,1,1,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ]);
      break;

    case 15: // Level 16 — Vertical stripes
      addGrid([
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [1,0,1,0,1,0,1,0,1,0,1,0],
        [1,0,1,0,1,0,1,0,1,0,1,0],
      ]);
      break;

    case 16: // Level 17 — Diagonal
      addGrid([
        [1,1,0,0,0,0,0,0,0,0,0,0],
        [1,1,1,1,0,0,0,0,0,0,0,0],
        [0,0,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0],
        [0,0,0,0,0,0,0,0,1,1,1,1],
        [0,0,0,0,0,0,1,1,1,1,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,1,1,1,1,0,0,0,0,0,0],
        [1,1,1,1,0,0,0,0,0,0,0,0],
        [1,1,0,0,0,0,0,0,0,0,0,0],
      ]);
      break;

    case 17: // Level 18 — Double diagonal
      addGrid([
        [1,1,0,0,0,0,0,0,0,0,1,1],
        [0,1,1,0,0,0,0,0,0,1,1,0],
        [0,0,1,1,0,0,0,0,1,1,0,0],
        [0,0,0,1,1,0,0,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,0,0,1,1,0,0,0],
        [0,0,1,1,0,0,0,0,1,1,0,0],
        [0,1,1,0,0,0,0,0,0,1,1,0],
        [1,1,0,0,0,0,0,0,0,0,1,1],
      ]);
      break;

    case 18: // Level 19 — Star
      addGrid([
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [1,0,0,0,1,1,1,1,0,0,0,1],
        [0,1,0,1,1,1,1,1,1,0,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,0,1,1,1,1,1,1,0,1,0],
        [1,0,0,0,1,1,1,1,0,0,0,1],
        [0,0,0,0,0,1,1,0,0,0,0,0],
      ]);
      break;

    case 19: // Level 20 — Full hard double layer
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ], hpOverride: 2);
      break;

    case 20: // Level 21 — Scattered islands
      addGrid([
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [1,1,1,0,1,1,1,1,0,1,1,1],
        [1,1,1,0,1,1,1,1,0,1,1,1],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,1,1,0,0,0,0,0,0,1,1,0],
        [0,1,1,1,0,0,0,0,1,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
      ]);
      break;

    case 21: // Level 22 — Snake
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,0,0,0,0,0,0,0,0,1,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,1,0,0,0,0,0,0,0,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,0,0,0,0,0,0,0,0,1,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,1,0,0,0,0,0,0,0,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
      ]);
      break;

    case 22: // Level 23 — Wings
      addGrid([
        [1,1,1,0,0,0,0,0,0,1,1,1],
        [1,1,1,1,0,0,0,0,1,1,1,1],
        [0,1,1,1,1,0,0,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,0,0,1,1,1,1,0],
        [1,1,1,1,0,0,0,0,1,1,1,1],
        [1,1,1,0,0,0,0,0,0,1,1,1],
      ]);
      break;

    case 23: // Level 24 — Grid holes
      addGrid([
        [1,1,1,0,1,1,1,1,0,1,1,1],
        [1,0,1,0,1,0,0,1,0,1,0,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,1,0,1,0,0,1,0,1,0,1],
        [1,1,1,0,1,1,1,1,0,1,1,1],
      ]);
      break;

    case 24: // Level 25 — Crown
      addGrid([
        [1,0,1,0,1,0,0,1,0,1,0,1],
        [1,0,1,0,1,0,0,1,0,1,0,1],
        [1,0,1,0,1,0,0,1,0,1,0,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
      ]);
      break;

    case 25: // Level 26 — Two triangles
      addGrid([
        [1,1,1,1,1,1,0,0,0,0,0,0],
        [0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,0,0,0,0],
        [0,1,1,1,1,1,1,0,0,0,0,0],
        [1,1,1,1,1,1,0,0,0,0,0,0],
      ]);
      break;

    case 26: // Level 27 — Crosshair
      addGrid([
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,1,0,0,0,1,1,0,0,0,1,0],
        [0,0,1,0,0,1,1,0,0,1,0,0],
        [0,0,0,1,0,1,1,0,1,0,0,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,0,0,1,0,1,1,0,1,0,0,0],
        [0,0,1,0,0,1,1,0,0,1,0,0],
        [0,1,0,0,0,1,1,0,0,0,1,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
      ]);
      break;

    case 27: // Level 28 — Inverted pyramid
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ]);
      break;

    case 28: // Level 29 — Maze
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,0,0,1,0,0,0,0,0,0,1],
        [1,0,1,0,1,0,1,1,1,1,0,1],
        [1,0,1,0,0,0,1,0,0,1,0,1],
        [1,0,1,1,1,0,1,0,1,1,0,1],
        [1,0,0,0,1,0,1,0,0,0,0,1],
        [1,1,1,0,1,0,1,1,1,1,0,1],
        [1,0,0,0,1,0,0,0,0,1,0,1],
        [1,0,1,1,1,1,1,1,0,1,0,1],
        [1,0,0,0,0,0,0,0,0,0,0,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ]);
      break;

    case 29: // Level 30 — Full chaos hard
      addGrid([
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [1,0,1,0,1,0,0,1,0,1,0,1],
        [1,1,0,1,0,1,1,0,1,0,1,1],
        [1,0,1,1,1,0,0,1,1,1,0,1],
        [1,1,1,0,1,1,1,1,0,1,1,1],
        [1,0,1,1,0,1,1,0,1,1,0,1],
        [1,1,0,1,1,0,0,1,1,0,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
      ], hpOverride: 2);
      break;   
  }
/* FLOWERPOT BRICK ASSIGNMENT DISABLED
  final rng2 = Random();
  ...
  bricks[i].hiddenPower = PowerupType.flowerpot;
*/

  return bricks;
}


PowerupDrop? trySpawnDrop(double x, double y, double screenW, {
  int countFire = 10,
  int countBig = 10,
  int countMulti = 10,
  int countWide = 10,
  int countLaser = 1,
  // int countFlowerpot = 50, // flowerpot disabled
  int countGun = 1,
}) {
  final rng = Random();
  if (rng.nextDouble() > 0.25) return null;

  final types = <PowerupDrop>[];

  if (countFire > 0) {
    types.add(PowerupDrop(x: x, y: y, type: PowerupType.fire,      label: '🔥 FIRE',   color: const Color(0xFFFF4444), w: screenW * 0.22, h: 28));
  }
  if (countBig > 0) {
    types.add(PowerupDrop(x: x, y: y, type: PowerupType.big,       label: '⬛ BIG',    color: const Color(0xFF00E5FF), w: screenW * 0.22, h: 28));
  }
  if (countMulti > 0) {
    types.add(PowerupDrop(x: x, y: y, type: PowerupType.multi,     label: '✦ MULTI',   color: const Color(0xFFFFE135), w: screenW * 0.22, h: 28));
  }
  //types.add(PowerupDrop(x: x, y: y, type: PowerupType.life,        label: '❤ LIFE',   color: const Color(0xFFFF88AA), w: screenW * 0.22, h: 28));
  if (countWide > 0) {
    types.add(PowerupDrop(x: x, y: y, type: PowerupType.wide,      label: '↔ WIDE',   color: const Color(0xFF00FF88), w: screenW * 0.22, h: 28));
  }
  if (countLaser > 0) {
    types.add(PowerupDrop(x: x, y: y, type: PowerupType.laser,     label: '⚡ LASER',  color: const Color(0xFFFFE500), w: screenW * 0.22, h: 28));
  }
  if (countGun > 0) {
    types.add(PowerupDrop(x: x, y: y, type: PowerupType.gun,       label: '🔫 GUN',    color: const Color(0xFFFFDD00), w: screenW * 0.22, h: 28));
  }
  //if (countFlowerpot > 0)
    //types.add(PowerupDrop(x: x, y: y, type: PowerupType.flowerpot, label: '🌸 FLOWER', color: const Color(0xFFFF69B4), w: screenW * 0.22, h: 28));

  if (types.isEmpty) return null;
  return types[rng.nextInt(types.length)];
}

void spawnParticles(
  List<Particle> list,
  double x,
  double y,
  Color color,
  int n,
) {
  final rng = Random();
  for (int i = 0; i < n; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final s = 1 + rng.nextDouble() * 6;
    list.add(Particle(
      x: x, y: y,
      vx: cos(a) * s, vy: sin(a) * s,
      r: 2 + rng.nextDouble() * 5,
      color: color,
      decay: 0.025 + rng.nextDouble() * 0.04,
    ));
  }
}
