import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager instance = SoundManager._();
  SoundManager._();

  bool muted = false;
  AudioPlayer? _musicPlayer;

  Future<void> init() async {}

  // ── Music ──────────────────────────────────────────────────

  Future<void> playMusic() async {
    if (muted) return;
    try {
      _musicPlayer?.dispose();
      _musicPlayer = AudioPlayer();
      await _musicPlayer!.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.music,
          isSpeakerphoneOn: false,
          stayAwake: true,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
      await _musicPlayer!.setVolume(0.3);
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.play(AssetSource('background_music.mp3'));
    } catch (e) {
      print('Music error: $e');
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer?.stop();
    _musicPlayer?.dispose();
    _musicPlayer = null;
  }

  Future<void> pauseMusic() async => await _musicPlayer?.pause();

  Future<void> resumeMusic() async {
    if (muted) return;
    await _musicPlayer?.resume();
  }

  void toggleMute() {
    muted = !muted;
    _musicPlayer?.setVolume(muted ? 0 : 0.3);
  }

  void dispose() => _musicPlayer?.dispose();

  // ── Sound Effects ──────────────────────────────────────────

  
 void playPaddleHit()    => _play('sfx_paddle.wav');
void playBrickHit()     => _play('sfx_brick.wav');
void playBrickDestroy() => _play('sfx_destroy.wav');
void playPowerup()      => _play('sfx_powerup.wav');
void playBallLost()     => _play('sfx_lost.wav');
void playCombo()        => _play('sfx_combo.wav');
void playLevelUp()      => _play('sfx_levelup.wav');
void playFirePower()    => _play('sfx_fire.wav');
void playLaserPower()   => _play('sfx_laser.wav');
void playBigPower()     => _play('sfx_big.wav');
void playMultiPower()   => _play('sfx_multi.wav');
void playWidePower()    => _play('sfx_wide.wav');
void playFlowerpot()    => _play('sfx_flowerpot.wav');
void playWhirlgig()     => _play('charkhi_firecracker.wav');

  void _play(String asset) {
    if (muted) return;
    try {
      final player = AudioPlayer();
      player.setVolume(1.0);
      player.play(AssetSource(asset));
      Future.delayed(const Duration(milliseconds: 600), () => player.dispose());
    } catch (e) {
      print('SFX error: $e');
    }
  }
}
