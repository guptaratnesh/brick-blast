import 'dart:typed_data';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager instance = SoundManager._();
  SoundManager._();

  bool muted = false;

  Future<void> init() async {}

  void playPaddleHit()    => _beep(440,  80);
  void playBrickHit()     => _beep(600,  50);
  void playBrickDestroy() => _beep(300, 120);
  void playPowerup()      => _beep(800, 200);
  void playBallLost()     => _beep(150, 400);
  void playCombo()        => _beep(900,  80);

  Future<void> playLevelUp() async {
    _beep(523, 100);
    await Future.delayed(const Duration(milliseconds: 120));
    _beep(659, 100);
    await Future.delayed(const Duration(milliseconds: 120));
    _beep(784, 250);
  }

  void toggleMute() => muted = !muted;

  void dispose() {}

  void _beep(int frequency, int durationMs) {
    if (muted) return;
    try {
      final player = AudioPlayer();
      final bytes = _generateWav(frequency, durationMs);
      player.play(BytesSource(bytes));
      Future.delayed(
        Duration(milliseconds: durationMs + 200),
        () => player.dispose(),
      );
    } catch (_) {}
  }

  Uint8List _generateWav(int frequency, int durationMs) {
    const sampleRate = 44100;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2;

    final buffer = ByteData(44 + dataSize);
    int offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, 36 + dataSize, Endian.little); offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // space
    buffer.setUint32(offset, 16, Endian.little); offset += 4;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;  // PCM
    buffer.setUint16(offset, 1, Endian.little); offset += 2;  // Mono
    buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
    buffer.setUint32(offset, sampleRate * 2, Endian.little); offset += 4;
    buffer.setUint16(offset, 2, Endian.little); offset += 2;
    buffer.setUint16(offset, 16, Endian.little); offset += 2;

    // data chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

    // PCM samples
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final fade = 1.0 - (i / numSamples);
      final sample = (sin(2 * pi * frequency * t) * 32767 * fade).round().clamp(-32768, 32767);
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}