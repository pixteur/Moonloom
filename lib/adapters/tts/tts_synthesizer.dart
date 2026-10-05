import 'dart:typed_data';

import '../../domain/models/narration.dart';
import '../../domain/performance.dart';
import 'tts_provider.dart';

/// Turns text into playable audio bytes (mp3 or wav). Pure I/O — no audio
/// playback — so it's unit-testable with a mock HTTP client. The
/// [CloudTtsProvider] wraps a synthesizer with an audio player.
abstract class TtsSynthesizer {
  /// The audio container the synthesized bytes are in (so the player decodes
  /// correctly), e.g. `audio/mpeg` or `audio/wav`.
  String get mimeType;

  /// A stable id for this engine + voice (e.g. `gemini/Aoede`), mixed into the
  /// audio-cache key so a different voice re-synthesizes instead of replaying
  /// the wrong audio.
  String get voiceSignature;

  /// [cue] is how this passage should be read — pace, feeling, volume. Each
  /// engine renders it in its own dialect, or ignores it. It never reaches the
  /// spoken text: an engine handed direction it doesn't understand would read
  /// it out loud.
  ///
  /// [parts] is the same [text] as a performance — who says each stretch and
  /// how — for an engine that can change speaker and delivery within one
  /// request. Joined, the parts are exactly [text]. An engine that cannot use
  /// them reads [text] as it always has.
  Future<Uint8List> synthesize(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationCue cue = const NarrationCue(),
    String standingDirection = '',
    List<SpeechPart> parts = const [],
  });
}

/// The direction for one passage as a single sentence: the chapter's standing
/// voice plus this passage's own cue. Empty when there is nothing to say, so
/// callers can fall back to their own default.
String narrationDirection(String standing, NarrationCue cue) {
  final parts = [
    if (standing.trim().isNotEmpty) standing.trim(),
    if (!cue.isEmpty) 'For this passage: ${cue.asDirection()}.',
  ];
  return parts.join(' ');
}

/// Wrap raw little-endian PCM (e.g. Gemini's 16-bit mono output) in a minimal
/// WAV container so a standard audio player can decode it.
Uint8List pcmToWav(
  Uint8List pcm, {
  int sampleRate = 24000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final dataLen = pcm.length;
  final buffer = BytesBuilder();

  void str(String s) => buffer.add(s.codeUnits);
  void u32(int v) => buffer.add([
    v & 0xff,
    (v >> 8) & 0xff,
    (v >> 16) & 0xff,
    (v >> 24) & 0xff,
  ]);
  void u16(int v) => buffer.add([v & 0xff, (v >> 8) & 0xff]);

  str('RIFF');
  u32(36 + dataLen);
  str('WAVE');
  str('fmt ');
  u32(16); // PCM fmt chunk size
  u16(1); // audio format = PCM
  u16(channels);
  u32(sampleRate);
  u32(byteRate);
  u16(blockAlign);
  u16(bitsPerSample);
  str('data');
  u32(dataLen);
  buffer.add(pcm);

  return buffer.toBytes();
}
