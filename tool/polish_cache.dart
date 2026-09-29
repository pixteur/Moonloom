/// Apply the narration polish to audio already in the cache.
///
/// New audio is polished on its way in, but the library already holds
/// narration that was paid for — and both fixes are arithmetic on the samples,
/// not a different reading, so there is no reason to buy it twice. This
/// rewrites the cached files in place.
///
/// Dry run by default: it measures what would change and prints it, touching
/// nothing. `--write` applies it.
///
///     dart run tool/polish_cache.dart              # measure only
///     dart run tool/polish_cache.dart --write      # rewrite in place
///
/// MP3 caches (ElevenLabs, OpenAI) are skipped — the samples are not readable
/// without decoding first, and this only claims to handle the WAV that Gemini
/// returns.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/audio_polish.dart';

Directory _cacheDir() {
  final appData = Platform.environment['APPDATA'];
  for (final candidate in [
    Directory('$appData\\com.pixteur\\moonloom\\audio_cache'),
    Directory('$appData\\com.pixteur\\moonloom\\library\\audio_cache'),
  ]) {
    if (candidate.existsSync()) return candidate;
  }
  throw StateError('No audio cache found under $appData');
}

/// Loudness spread across the file, in dB — the number the complaint was about.
(double spread, int pauses, double seconds) _shape(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  final rate = view.getUint32(24, Endian.little);
  final channels = max(1, view.getUint16(22, Endian.little));
  final count = (wav.length - 44) ~/ 2;
  if (rate == 0 || count == 0) return (0, 0, 0);
  final s = Int16List(count);
  for (var i = 0; i < count; i++) {
    s[i] = view.getInt16(44 + i * 2, Endian.little);
  }

  double dbfs(int from, int to) {
    var sum = 0.0;
    final end = min(to, s.length);
    for (var i = from; i < end; i++) {
      final v = s[i] / 32768.0;
      sum += v * v;
    }
    final n = end - from;
    if (n <= 0) return -120;
    final rms = sqrt(sum / n);
    return rms <= 1e-6 ? -120 : 20 * (log(rms) / ln10);
  }

  final perSecond = rate * channels;
  final window = max(1, perSecond ~/ 50);

  // Measure loudness per SPEECH RUN, not per fixed second.
  //
  // The first version of this sampled every second and reported the spread,
  // and said the polish made things worse — 16.2 dB to 19.2 dB. It had not:
  // lengthening a pause to 900 ms means a one-second window now straddles
  // silence and speech, reads far quieter than either, and widens the spread
  // on its own. The metric was measuring the fix. Segment loudness is what
  // the levelling actually equalises, and it is comparable either side.
  final loud = <double>[];
  var quietFrom = -1;
  var speechFrom = -1;
  var longPauses = 0;

  void closeSpeech(int at) {
    if (speechFrom >= 0 && at - speechFrom > window) {
      final d = dbfs(speechFrom, at);
      if (d > -45) loud.add(d);
    }
    speechFrom = -1;
  }

  for (var i = 0; i + window <= s.length; i += window) {
    final quiet = dbfs(i, i + window) < -50;
    if (quiet) {
      if (quietFrom < 0) {
        quietFrom = i;
        closeSpeech(i);
      }
      continue;
    }
    if (quietFrom >= 0) {
      if ((i - quietFrom) / perSecond * 1000 >= 800) longPauses++;
      quietFrom = -1;
    }
    if (speechFrom < 0) speechFrom = i;
  }
  closeSpeech(s.length);

  // Drift, not spread.
  //
  // Min-to-max across every speech run was the second metric to measure the
  // wrong thing: it is dominated by how loud the loudest exclamation is
  // against the quietest trailing clause, and that variation is the reading
  // doing its job. What was actually wrong is that the voice gets steadily
  // louder as a request goes on, so the number to watch is how far the second
  // half sits from the first.
  double mean(Iterable<double> xs) =>
      xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
  final half = loud.length ~/ 2;
  final drift = loud.length < 4
      ? 0.0
      : (mean(loud.skip(half)) - mean(loud.take(half))).abs();
  return (drift, longPauses, s.length / perSecond);
}

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final dir = _cacheDir();
  final files = dir.listSync().whereType<File>().toList();

  var touched = 0, skipped = 0;
  var spreadBefore = 0.0, spreadAfter = 0.0;
  var pausesBefore = 0, pausesAfter = 0;
  var bytesBefore = 0, bytesAfter = 0;

  stdout.writeln(write ? 'REWRITING IN PLACE' : 'DRY RUN — nothing written');
  stdout.writeln('${files.length} cached files\n');
  stdout.writeln('key                          secs   drift dB    long pauses');

  for (final file in files) {
    final stored = file.readAsBytesSync();
    final wav = decompressAudio(stored);
    if (wav.length < 45 || wav[0] != 0x52 || wav[1] != 0x49) {
      skipped++;
      continue;
    }
    final polished = polishNarration(wav);
    if (identical(polished, wav)) {
      skipped++;
      continue;
    }

    final before = _shape(wav);
    final after = _shape(polished);
    spreadBefore += before.$1;
    spreadAfter += after.$1;
    pausesBefore += before.$2;
    pausesAfter += after.$2;
    bytesBefore += stored.length;

    final repacked = compressAudio(polished);
    bytesAfter += repacked.length;
    if (write) {
      final tmp = File('${file.path}.tmp');
      tmp.writeAsBytesSync(repacked);
      tmp.renameSync(file.path);
    }
    touched++;

    if (touched <= 12) {
      stdout.writeln(
        '${file.uri.pathSegments.last.padRight(28)} '
        '${before.$3.toStringAsFixed(0).padLeft(4)}  '
        '${before.$1.toStringAsFixed(1).padLeft(5)} → '
        '${after.$1.toStringAsFixed(1).padLeft(5)}   '
        '${before.$2.toString().padLeft(3)} → ${after.$2}',
      );
    }
  }

  if (touched == 0) {
    stdout.writeln('\nNothing to change. ($skipped skipped)');
    return;
  }
  stdout.writeln(
    '\n$touched polished, $skipped skipped (MP3 or single-segment)',
  );
  stdout.writeln(
    'mean drift, half to half  '
    '${(spreadBefore / touched).toStringAsFixed(1)} dB → '
    '${(spreadAfter / touched).toStringAsFixed(1)} dB',
  );
  stdout.writeln('paragraph-length pauses  $pausesBefore → $pausesAfter');
  stdout.writeln(
    'on disk  ${(bytesBefore / 1024 / 1024).toStringAsFixed(1)} MB → '
    '${(bytesAfter / 1024 / 1024).toStringAsFixed(1)} MB',
  );
  if (!write) stdout.writeln('\nRe-run with --write to apply.');
}
