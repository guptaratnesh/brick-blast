import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game_controller.dart';
import 'game_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _game;
  late final Ticker _ticker;
  double _animTime = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _game = GameController();

    // Game loop via Ticker (synced to display refresh rate)
    _ticker = createTicker((elapsed) {
      _animTime = elapsed.inMilliseconds / 1000.0;
      _game.update();
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _game.dispose();
    super.dispose();
  }

  void _handleTap(Offset pos) {
    if (_game.state == GameState.menu || _game.state == GameState.dead) {
      _game.startGame();
    }
  }

  void _handleDrag(Offset pos) {
    if (_game.state == GameState.playing) {
      _game.movePaddle(pos.dx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Initialize once we know screen size
          if (!_initialized && w > 0 && h > 0) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _game.init(w, h);
            });
          }

          return GestureDetector(
            // Tap to start / retry
            onTapDown: (d) => _handleTap(d.localPosition),

            // Drag to move paddle — horizontal pan anywhere on screen
            onHorizontalDragStart: (d) => _handleDrag(d.localPosition),
            onHorizontalDragUpdate: (d) => _handleDrag(d.localPosition),

            // Also handle vertical drag start so it doesn't get ignored
            onPanStart: (d) => _handleDrag(d.localPosition),
            onPanUpdate: (d) => _handleDrag(d.localPosition),

            child: AnimatedBuilder(
              animation: _game,
              builder: (context, _) {
                return CustomPaint(
                  painter: GamePainter(_game, _animTime),
                  size: Size(w, h),
                  child: const SizedBox.expand(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
