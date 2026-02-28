import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';

import 'game_controller.dart';
import 'game_painter.dart';
import 'sound_manager.dart';

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

  // BASIC AUDIO TEST
  Future.delayed(const Duration(seconds: 3), () async {
    print('=== AUDIO TEST START ===');
    try {
      final player = AudioPlayer();
      await player.setVolume(1.0);
      final result = await player.play(AssetSource('background_music.mp3'));
      print('=== PLAY CALLED ===');
    } catch (e) {
      print('=== AUDIO ERROR: $e ===');
    }
  });

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
    SoundManager.instance.playMusic();
  } else if (_game.state == GameState.paused) {
    _game.togglePause();
  } else if (_game.state == GameState.clear) {
    _game.nextLevel();
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
    return Stack(
      children: [
        // Game canvas
        CustomPaint(
          painter: GamePainter(_game, _animTime),
          size: Size(w, h),
          child: const SizedBox.expand(),
        ),

        // Pause button top right
        if (_game.state == GameState.playing ||
            _game.state == GameState.paused)
          Positioned(
            top: 55,
            right: 12,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    _game.state == GameState.paused ? '▶' : '⏸',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Tap anywhere to resume when paused
        if (_game.state == GameState.paused)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
  _game.togglePause();
  if (_game.state == GameState.paused) {
    SoundManager.instance.pauseMusic();
  } else {
    SoundManager.instance.resumeMusic();
  }
},
              behavior: HitTestBehavior.translucent,
            ),
          ),
      ],
    );
  },
),
          );
        },
      ),
    );
  }
}
