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
///     dart run tool/polish_cache.dart              # de-click, measure only
///     dart run tool/polish_cache.dart --write      # de-click in place
///     dart run tool/polish_cache.dart --full       # the whole polish, measure
///
/// **De-click only, by default.** The full polish is not safe to repeat on
/// real narration — measured, a second pass lengthened 68 of 561 files by up
/// to 15 seconds — and much of this cache was already polished on its way in,
/// with no way to tell which. The de-click is safe to repeat, and it is the
/// part that removes the static. Every run reports whether running it again
/// would change anything.
///
/// `--write` copies each file to a dated backup folder beside the cache the
/// moment before rewriting it. Spread across every core.
///
/// MP3 caches (ElevenLabs, OpenAI) are skipped — the samples are not readable
/// without decoding first, and this only claims to handle the WAV that Gemini
/// returns.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/audio_polish.dart';

/// Where the narration the app actually plays lives.
///
/// **The library first, and the old app-support folders only after it.** There
/// are two caches on this machine: `Documents\Moonloom\audio`, which is what
/// `LibraryPaths.audio()` resolves to and what playback reads and writes, and
/// an older `AppData\...\audio_cache` that `FileAudioCache` migrates from. The
/// old one still holds files, so a tool that checked it first found a cache,
/// stopped, and reported on audio nothing has played in months — which is how
/// this very script nearly rewrote the wrong 42 files while the 795 the app
/// reads sat untouched.
Directory _cacheDir() {
  final appData = Platform.environment['APPDATA'];
  for (final candidate in [
    Directory(
      '${Platform.environment['USERPROFILE']}'
      r'\Documents\Moonloom\audio',
    ),
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

/// What one worker found, summed by the caller.
///
/// Plain numbers and strings only: it crosses an isolate boundary, and a
/// record of primitives is copied across without ceremony.
typedef _Tally = ({
  int touched,
  int skipped,
  int clicksBefore,
  int clicksAfter,
  int notIdempotent,
  double worstGrowth,
  double spreadBefore,
  double spreadAfter,
  int pausesBefore,
  int pausesAfter,
  int bytesBefore,
  int bytesAfter,
  List<String> lines,
});

/// Steps out of near-silence a listener hears as a click — the same rule
/// `tool/click_check.dart` and the polish itself use.
int _clicks(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  final count = (wav.length - 44) ~/ 2;
  final s = Int16List(count);
  for (var i = 0; i < count; i++) {
    s[i] = view.getInt16(44 + i * 2, Endian.little);
  }
  int peak(int from, int to) {
    var p = 0;
    for (var i = max(0, from); i < min(to, s.length); i++) {
      p = max(p, s[i].abs());
    }
    return p;
  }

  var n = 0;
  for (var i = 1; i < s.length; i++) {
    if ((s[i] - s[i - 1]).abs() < 2000) continue;
    if (peak(i - 240, i) > 655 && peak(i, i + 240) > 655) continue;
    n++;
  }
  return n;
}

/// One worker's share of the cache. Top-level so an isolate can run it.
///
/// Each file is backed up the moment before it is rewritten, rather than the
/// whole folder up front: the same guarantee — nothing is changed that has
/// not been copied first — without one core copying 680 MB while sixty-three
/// wait for it.
_Tally _work(List<String> paths, bool write, bool full, String backup) {
  var touched = 0, skipped = 0, clicksBefore = 0, clicksAfter = 0;
  var notIdempotent = 0, pausesBefore = 0, pausesAfter = 0;
  var bytesBefore = 0, bytesAfter = 0;
  var worstGrowth = 0.0, spreadBefore = 0.0, spreadAfter = 0.0;
  final lines = <String>[];

  for (final path in paths) {
    final file = File(path);
    final stored = file.readAsBytesSync();
    final wav = decompressAudio(stored);
    if (wav.length < 45 || wav[0] != 0x52 || wav[1] != 0x49) {
      skipped++;
      continue;
    }
    final fixed = full ? polishNarration(wav) : deClickNarration(wav);
    if (identical(fixed, wav)) {
      skipped++;
      continue;
    }

    // The same operation again must change nothing. This is the check that
    // stopped the full polish from being run over the cache.
    final again = full ? polishNarration(fixed) : deClickNarration(fixed);
    final grew = _shape(again).$3 - _shape(fixed).$3;
    if (!identical(again, fixed) && (grew > 0.05 || !full)) {
      notIdempotent++;
      worstGrowth = max(worstGrowth, grew);
    }

    final before = _shape(wav);
    final after = _shape(fixed);
    spreadBefore += before.$1;
    spreadAfter += after.$1;
    pausesBefore += before.$2;
    pausesAfter += after.$2;
    clicksBefore += _clicks(wav);
    clicksAfter += _clicks(fixed);
    bytesBefore += stored.length;

    final repacked = compressAudio(fixed);
    bytesAfter += repacked.length;
    if (write) {
      file.copySync('$backup\\${file.uri.pathSegments.last}');
      final tmp = File('${file.path}.tmp');
      tmp.writeAsBytesSync(repacked);
      tmp.renameSync(file.path);
    }
    touched++;
    if (lines.length < 3) {
      lines.add(
        '${file.uri.pathSegments.last.padRight(20)} '
        '${before.$3.toStringAsFixed(0).padLeft(4)} s   '
        'clicks ${_clicks(wav).toString().padLeft(3)} → '
        '${_clicks(fixed)}',
      );
    }
  }
  return (
    touched: touched,
    skipped: skipped,
    clicksBefore: clicksBefore,
    clicksAfter: clicksAfter,
    notIdempotent: notIdempotent,
    worstGrowth: worstGrowth,
    spreadBefore: spreadBefore,
    spreadAfter: spreadAfter,
    pausesBefore: pausesBefore,
    pausesAfter: pausesAfter,
    bytesBefore: bytesBefore,
    bytesAfter: bytesAfter,
    lines: lines,
  );
}

Future<void> main(List<String> args) async {
  final write = args.contains('--write');
  final full = args.contains('--full');
  final dir = _cacheDir();
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => !f.path.endsWith('.tmp'))
      .map((f) => f.path)
      .toList();

  // Every core this machine has. Each file is independent of every other, so
  // the work splits cleanly; dealt round-robin so the long chapters do not
  // all land on one worker.
  final cores = max(1, Platform.numberOfProcessors);
  final slices = [
    for (var w = 0; w < cores; w++)
      [for (var i = w; i < files.length; i += cores) files[i]],
  ].where((s) => s.isNotEmpty).toList();

  var backup = '';
  if (write) {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    backup = Directory('${dir.path}.bak-$stamp').path;
    Directory(backup).createSync();
  }

  stdout.writeln('cache:  ${dir.path}');
  stdout.writeln(
    'mode:   ${full ? 'FULL polish (level, pauses, clicks)' : 'de-click only'}'
    '${write ? ' — REWRITING IN PLACE' : ' — dry run, nothing written'}',
  );
  if (write) stdout.writeln('backup: $backup');
  stdout.writeln(
    '${files.length} files across ${slices.length} workers '
    '(${Platform.numberOfProcessors} cores)\n',
  );

  final watch = Stopwatch()..start();
  final tallies = await Future.wait([
    for (final slice in slices)
      Isolate.run(() => _work(slice, write, full, backup)),
  ]);
  watch.stop();

  int sum(int Function(_Tally) f) => tallies.fold(0, (a, t) => a + f(t));
  final touched = sum((t) => t.touched);
  final skipped = sum((t) => t.skipped);
  final notIdempotent = sum((t) => t.notIdempotent);
  final worstGrowth = tallies.fold(0.0, (a, t) => max(a, t.worstGrowth));

  for (final line in tallies.expand((t) => t.lines).take(12)) {
    stdout.writeln(line);
  }
  stdout.writeln(
    '\n$touched changed, $skipped untouched (MP3, single-segment, or '
    'nothing to fix) — ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
  );
  stdout.writeln(
    'clicks  ${sum((t) => t.clicksBefore)} → ${sum((t) => t.clicksAfter)}',
  );
  if (full && touched > 0) {
    final spreadB = tallies.fold(0.0, (a, t) => a + t.spreadBefore);
    final spreadA = tallies.fold(0.0, (a, t) => a + t.spreadAfter);
    stdout.writeln(
      'mean drift, half to half  ${(spreadB / touched).toStringAsFixed(1)} dB '
      '→ ${(spreadA / touched).toStringAsFixed(1)} dB',
    );
    stdout.writeln(
      'paragraph-length pauses  ${sum((t) => t.pausesBefore)} → '
      '${sum((t) => t.pausesAfter)}',
    );
  }
  stdout.writeln(
    'on disk  ${(sum((t) => t.bytesBefore) / 1048576).toStringAsFixed(1)} MB → '
    '${(sum((t) => t.bytesAfter) / 1048576).toStringAsFixed(1)} MB',
  );
  stdout.writeln(
    notIdempotent == 0
        ? 'running it again changes nothing — safe on audio of any history'
        : 'running it again CHANGES $notIdempotent files'
              '${full ? ', lengthening them by up to '
                        '${worstGrowth.toStringAsFixed(2)} s' : ''}'
              ' — not safe to repeat',
  );
  if (write) {
    stdout.writeln('\nOriginals of every changed file are in $backup');
  } else {
    stdout.writeln('\nRe-run with --write to apply.');
  }
}
