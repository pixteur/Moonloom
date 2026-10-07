/// Read-only: which cached narration has Gemini's C2PA manifest baked into it
/// as sound?
///
/// Every WAV the Gemini 3.8 voices return ends with a `C2PA` chunk — a signed
/// Content Credentials manifest, about 6 KB, saying the audio is AI-made. It
/// sits after the `data` chunk, where a RIFF reader skips it. The app's
/// readers did not skip it: each took "everything after byte 44" as samples,
/// so the polish wrote the manifest back into the file as roughly 126 ms of
/// digital noise at the very end — the pop of static at the end of every
/// paragraph, and in the Lunii navigation, which encodes the same audio.
///
/// This finds it two ways, because the polish may have changed the bytes:
///   * the manifest's own ASCII markers (`C2PA`, `jumb`, `c2pa`) still
///     present inside the audio, when the polish left that stretch untouched;
///   * a final stretch that is noise rather than sound — crossing zero far
///     more often than any voice does — when it did not.
///
///     dart run tool/c2pa_scan.dart
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';

int _indexOf(Uint8List hay, List<int> needle, int from) {
  outer:
  for (var i = from; i <= hay.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

/// Zero crossings per second over the last [n] samples.
int _tailZcr(Uint8List wav, int n) {
  final v = ByteData.sublistView(wav);
  final count = (wav.length - 44) ~/ 2;
  final from = (count - n).clamp(0, count);
  var crossings = 0;
  var prev = 0;
  for (var i = from; i < count; i++) {
    final s = v.getInt16(44 + i * 2, Endian.little);
    if (i > from && (prev < 0) != (s < 0)) crossings++;
    prev = s;
  }
  return (crossings * 24000 / (count - from).clamp(1, 1 << 30)).round();
}

void main() {
  final dir = Directory(
    '${Platform.environment['USERPROFILE']}\\Documents\\Moonloom\\audio',
  );
  var wavs = 0, marked = 0, noisyTail = 0, chunkStill = 0;
  final examples = <String>[];
  for (final f in dir.listSync().whereType<File>()) {
    Uint8List wav;
    try {
      wav = decompressAudio(f.readAsBytesSync());
    } catch (_) {
      continue;
    }
    if (wav.length < 44 || wav[0] != 0x52 || wav[1] != 0x49) continue;
    wavs++;
    final name = f.uri.pathSegments.last;
    final hasChunk = _indexOf(wav, 'C2PA'.codeUnits, 36) >= 0;
    final hasJumbf =
        _indexOf(wav, 'jumb'.codeUnits, 44) >= 0 ||
        _indexOf(wav, 'c2pa'.codeUnits, 44) >= 0;
    // The last 3 000 samples, about the length the manifest occupies.
    final zcr = _tailZcr(wav, 3000);
    if (hasChunk) chunkStill++;
    if (hasJumbf || hasChunk) {
      marked++;
      if (examples.length < 5) examples.add('$name  tail ZCR $zcr');
    } else if (zcr > 6000) {
      noisyTail++;
    }
  }
  stdout.writeln('$wavs cached WAV files');
  stdout.writeln('  $marked carry the manifest\'s own markers inside them');
  stdout.writeln('  $chunkStill still contain a C2PA chunk header');
  stdout.writeln(
    '  $noisyTail more end in noise (tail crossing zero > 6000 times a second)',
  );
  for (final e in examples) {
    stdout.writeln('    e.g. $e');
  }
}
