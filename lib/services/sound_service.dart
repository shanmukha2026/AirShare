// lib/services/sound_service.dart
// Programmatically generates and plays WAV sound effects.
// No external audio files needed — pure Dart math.

import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  // Generate a WAV file as bytes from a frequency list (for sweep/ding effects)
  static Uint8List _generateWav({
    required List<double> frequencies, // frequencies over time
    int sampleRate = 44100,
    double durationSecs = 0.25,
    double amplitude = 0.4,
  }) {
    final numSamples = (sampleRate * durationSecs).toInt();
    final pcmData = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final freqIndex = (i / numSamples * frequencies.length).toInt().clamp(0, frequencies.length - 1);
      final freq = frequencies[freqIndex];

      // Envelope: attack + decay to prevent clicks
      final envelope = _envelope(i, numSamples);
      pcmData[i] = (sin(2 * pi * freq * t) * amplitude * envelope * 32767).toInt().clamp(-32767, 32767);
    }

    return _buildWavBytes(pcmData, sampleRate);
  }

  static double _envelope(int i, int total) {
    final attack = total * 0.05;
    final decay = total * 0.2;
    if (i < attack) return i / attack;
    if (i > total - decay) return (total - i) / decay;
    return 1.0;
  }

  static Uint8List _buildWavBytes(Int16List samples, int sampleRate) {
    final dataBytes = samples.length * 2;
    final buffer = ByteData(44 + dataBytes);

    // RIFF chunk
    buffer.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    buffer.setUint32(4, 36 + dataBytes, Endian.little);
    buffer.setUint32(8, 0x57415645, Endian.big); // "WAVE"

    // fmt chunk
    buffer.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little);  // PCM format
    buffer.setUint16(22, 1, Endian.little);  // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little);  // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    buffer.setUint32(36, 0x64617461, Endian.big); // "data"
    buffer.setUint32(40, dataBytes, Endian.little);

    for (int i = 0; i < samples.length; i++) {
      buffer.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// Play a "whoosh" sound — upward frequency sweep, used when sending files
  static Future<void> playWhoosh() async {
    try {
      // Sweep from 200Hz to 900Hz quickly — feels like "launching" something
      final freqs = List.generate(20, (i) => 200.0 + i * 35.0);
      final wav = _generateWav(frequencies: freqs, durationSecs: 0.22, amplitude: 0.3);
      await _player.play(BytesSource(wav));
    } catch (_) {}
  }

  /// Play a "ding" sound — two-tone chime, used when transfer completes
  static Future<void> playDing() async {
    try {
      // G5 → C6 major interval chime (musical, pleasant)
      final freqs = [
        ...List.filled(15, 784.0),  // G5
        ...List.filled(5, 0.0),     // tiny gap
        ...List.filled(20, 1047.0), // C6
      ];
      final wav = _generateWav(frequencies: freqs, durationSecs: 0.45, amplitude: 0.35);
      await _player.play(BytesSource(wav));
    } catch (_) {}
  }
}
