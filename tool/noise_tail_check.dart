/// Read-only: which cached clips end in the C2PA manifest's noise even though
/// none of the manifest's text survived?
///
/// `tool/strip_c2pa.dart` finds the manifest by its text. When the polish
/// changed the level of the stretch the manifest sat in, every one of its bytes
/// changed and there is no text left to find — but it still plays as static.
/// It is unmistakable by ear and by numbers: a voice's real ending is quiet
/// room tone (about -55 dBFS), while a manifest read as samples is nearly full
/// scale and crosses zero thousands of times a second.
///
/// This reports, for each clip whose last 126 ms (the manifest's length) is
/// loud and noise-like, how loud and how noisy — next to the 126 ms before it,
/// so the difference is visible.
///
///     dart run tool/noise_tail_check.dart
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';

const int _manifestSamples = 6070 ~/ 2;

(double, int) _shape(Int16List s, int from, int to) {
  var sum = 0.0;
  var crossings = 0;
  for (var i = from; i < to; i++) {
    final x = s[i] / 32768;
    sum += x * x;
    if (i > from && (s[i - 1] < 0) != (s[i] < 0)) crossings++;
  }
  final n = max(1, to - from);
  final rms = sqrt(sum / n);
  return (
    rms < 1e-7 ? -140.0 : 20 * log(rms) / ln10,
    (crossings * 24000 / n).round(),
  );
}

void main() {
  final dir = Directory(
    '${Platform.environment['USERPROFILE']}\\Documents\\Moonloom\\audio',
  );
  var looked = 0, noisy = 0;
  for (final f in dir.listSync().whereType<File>()) {
    Uint8List wav;
    try {
      wav = decompressAudio(f.readAsBytesSync());
    } catch (_) {
      continue;
    }
    if (wav.length < 44 + 4 * _manifestSamples ||
        String.fromCharCodes(wav, 0, 4) != 'RIFF') {
      continue;
    }
    looked++;
    final v = ByteData.sublistView(wav);
    final s = Int16List((wav.length - 44) ~/ 2);
    for (var i = 0; i < s.length; i++) {
      s[i] = v.getInt16(44 + i * 2, Endian.little);
    }
    final end = s.length;
    final (lastDb, lastZcr) = _shape(s, end - _manifestSamples, end);
    final (prevDb, prevZcr) = _shape(
      s,
      end - 2 * _manifestSamples,
      end - _manifestSamples,
    );
    if (lastZcr > 6000) {
      noisy++;
      stdout.writeln(
        '${f.uri.pathSegments.last}  last 126 ms: '
        '${lastDb.toStringAsFixed(1)} dBFS, $lastZcr crossings/s   '
        'before it: ${prevDb.toStringAsFixed(1)} dBFS, $prevZcr/s',
      );
    }
  }
  stdout.writeln('\n$noisy of $looked clips end in noise-like sound');
}
