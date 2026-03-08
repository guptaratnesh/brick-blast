import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game_controller.dart';
import 'game_models.dart';
import 'game_painter.dart';
import 'sound_manager.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final GameController _game;
  late final Ticker _ticker;
  late final GamePainter _painter;
  double _animTime = 0;
  bool _initialized = false;
  double _screenW = 0, _screenH = 0;

  @override
  void initState() {
    super.initState();
    _game = GameController();
    _painter = GamePainter(_game, 0);
    _ticker = createTicker((elapsed) {
      _animTime = elapsed.inMilliseconds / 1000.0;
      _game.update();
    });
    _ticker.start();
  }

  @override
  void dispose() { _ticker.dispose(); _game.dispose(); super.dispose(); }

  void _handleStripTap(Offset pos) {
    // Only intercept strip taps during gameplay
    if (_game.state == GameState.playing) {
      final types = [BulletType.normal, BulletType.fire, BulletType.laser, BulletType.whirlgig];
      final rects = _painter.powerStripSlotRects(_screenW, _screenH);
      for (int i = 0; i < rects.length; i++) {
        if (rects[i].contains(pos)) {
          _game.selectBulletType(types[i]);
          return;
        }
      }
    }
    _handleTap(pos); // fall through for menu/dead/clear states
  }

  void _handleTap(Offset pos) {
    if (_game.state == GameState.menu || _game.state == GameState.dead) {
      _game.startGame();
      SoundManager.instance.playMusic();
    } else if (_game.state == GameState.clear) {
      _game.nextLevel();
    } else if (_game.state == GameState.paused && !_game.bossCountdownActive) {
      _game.togglePause();
    }
  }

  void _handleDrag(Offset pos) {
    if (_game.state == GameState.playing) _game.movePaddle(pos.dx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (!_initialized && w > 0 && h > 0) {
            _initialized = true;
            _screenW = w; _screenH = h;
            WidgetsBinding.instance.addPostFrameCallback((_) => _game.init(w, h));
          }
          return GestureDetector(
            onTapDown: (d) => _handleStripTap(d.localPosition),
            onHorizontalDragStart: (d) { _game.isTouching = true; _handleDrag(d.localPosition); },
            onHorizontalDragUpdate: (d) => _handleDrag(d.localPosition),
            onHorizontalDragEnd: (_) => _game.isTouching = false,
            onHorizontalDragCancel: () => _game.isTouching = false,
            onPanStart: (d) { _game.isTouching = true; _handleDrag(d.localPosition); },
            onPanUpdate: (d) => _handleDrag(d.localPosition),
            onPanEnd: (_) => _game.isTouching = false,
            onPanCancel: () => _game.isTouching = false,
            child: AnimatedBuilder(
              animation: _game,
              builder: (context, _) {
                return Stack(children: [
                  CustomPaint(
                    painter: GamePainter(_game, _animTime), // painter instance used for hit-testing
                    size: Size(w, h),
                    child: const SizedBox.expand(),
                  ),
                  if (_game.state == GameState.playing || _game.state == GameState.paused)
                    Positioned(
                      top: 55, right: 12,
                      child: GestureDetector(
                        onTap: () {
                          _game.togglePause();
                          if (_game.state == GameState.paused) {
                            SoundManager.instance.pauseMusic();
                          } else {
                            SoundManager.instance.resumeMusic();
                          }
                        },
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Center(child: Text(
                            _game.state == GameState.paused ? '▶' : '⏸',
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                          )),
                        ),
                      ),
                    ),
                  if (_game.state == GameState.paused && !_game.bossCountdownActive)
                    Positioned.fill(child: GestureDetector(
                      onTap: () {
                        _game.togglePause();
                        if (_game.state == GameState.paused) {
                          SoundManager.instance.pauseMusic();
                        } else {
                          SoundManager.instance.resumeMusic();
                        }
                      },
                      behavior: HitTestBehavior.translucent,
                    )),
                ]);
              },
            ),
          );
        },
      ),
    );
  }
}
