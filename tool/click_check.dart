/// Read-only: does the polish leave a click in the audio?
///
/// A pop at the end of a paragraph is a step in the waveform — the signal
/// jumping from one value to a distant one between two adjacent samples. The
/// ear hears that as a click however quiet the surrounding audio is, which is
/// why it was audible in a *pause*.
///
/// This counts those steps rather than listening for them. It runs the real
/// `polishNarration` over the real cached narration and compares the worst
/// sample-to-sample jump before and after, so "fixed" is a number.
///
///     dart run tool/click_check.dart
///     dart run tool/click_check.dart --file <cache key>
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';
import 'package:moonloom/adapters/tts/audio_polish.dart';

/// A jump of more than this between adjacent samples is a step a listener
/// hears as a click. Speech itself moves fast, but not this fast at 24 kHz —
/// and never from inside a silence, which is where these were.
const int _clickThreshold = 2000;

/// Only steps that happen somewhere quiet count. A loud consonant can move
/// the waveform a long way legitimately; silence cannot.
const double _quietFloor = 0.02;

Directory _cacheDir() {
  final appData = Platform.environment['APPDATA'];
  for (final candidate in [
    Directory(
      '$appData'
      r'\com.pixteur\Moonloom\audio_cache',
    ),
    Directory(
      '${Platform.environment['USERPROFILE']}'
      r'\Documents\Moonloom\audio',
    ),
  ]) {
    if (candidate.existsSync()) return candidate;
  }
  throw StateError('No narration cache found');
}

Int16List _samples(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  final count = (wav.length - 44) ~/ 2;
  final out = Int16List(count);
  for (var i = 0; i < count; i++) {
    out[i] = view.getInt16(44 + i * 2, Endian.little);
  }
  return out;
}

/// Where the audible steps are, in samples, with how far each one jumped.
List<(int, int)> _clicks(Int16List s) {
  final out = <(int, int)>[];
  for (var i = 1; i < s.length; i++) {
    final jump = (s[i] - s[i - 1]).abs();
    if (jump < _clickThreshold) continue;
    // Quiet on one side of the jump is what makes it a click rather than a
    // transient: a step out of, or into, near-silence.
    final before = _localPeak(s, i - 240, i);
    final after = _localPeak(s, i, i + 240);
    if (before > _quietFloor && after > _quietFloor) continue;
    out.add((i, jump));
  }
  return out;
}

double _localPeak(Int16List s, int from, int to) {
  var peak = 0;
  for (var i = max(0, from); i < min(to, s.length); i++) {
    peak = max(peak, s[i].abs());
  }
  return peak / 32768.0;
}

bool _isPcmWav(Uint8List b) =>
    b.length > 44 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46;

Future<void> main(List<String> args) async {
  final at = args.indexOf('--file');
  final dir = _cacheDir();
  final files = at >= 0 && at + 1 < args.length
      ? [File('${dir.path}\\${args[at + 1]}')]
      : (dir.listSync().whereType<File>().toList()
          ..sort((a, b) => b.lengthSync().compareTo(a.lengthSync())));

  stdout.writeln('cache: ${dir.path}\n');
  stdout.writeln('key                        raw   after polish   worst jump');

  var rawTotal = 0;
  var polishedTotal = 0;
  var looked = 0;

  for (final file in files.take(20)) {
    Uint8List wav;
    try {
      wav = decompressAudio(file.readAsBytesSync());
    } catch (_) {
      continue;
    }
    if (!_isPcmWav(wav)) continue;

    final before = _clicks(_samples(wav));
    final polished = _samples(polishNarration(wav));
    final after = _clicks(polished);
    rawTotal += before.length;
    polishedTotal += after.length;
    looked++;

    stdout.writeln(
      '${file.uri.pathSegments.last.padRight(24)} '
      '${before.length.toString().padLeft(4)} '
      '${after.length.toString().padLeft(13)} '
      '${(after.isEmpty ? 0 : after.map((c) => c.$2).reduce(max)).toString().padLeft(12)}',
    );

    // Where a polished file has more clicks than the original, say where —
    // "the polish adds four" is a fact without a cause, and the cause is
    // always a position.
    if (after.length > before.length) {
      for (final (at, jump) in after.take(6)) {
        stdout.writeln(
          '    at ${(at / 24000).toStringAsFixed(2)}s  jump $jump'
          '${at < 2400 ? '   (near the very start)' : ''}',
        );
      }
    }
  }

  // Where a chunk begins and ends.
  //
  // Playback plays each chunk as its own clip, one after another, so every
  // chunk boundary is a place the waveform can jump. A clip that ends at a
  // sample far from zero steps straight to silence, and the ear hears that
  // step as a tick or a burst of static — at the end of a paragraph, which is
  // exactly where it keeps being reported. Nothing in the polish touches a
  // clip's own edges: it fades the silence it inserts, and leaves the first
  // and last sample of the clip as the model left them. So this measures them.
  stdout.writeln('\nedges              first    last   peak in last 20ms');
  var abrupt = 0;
  var seen = 0;
  for (final file in files.take(20)) {
    Uint8List wav;
    try {
      wav = decompressAudio(file.readAsBytesSync());
    } catch (_) {
      continue;
    }
    if (!_isPcmWav(wav)) continue;
    final s = _samples(polishNarration(wav));
    if (s.isEmpty) continue;
    seen++;
    var peak = 0;
    for (var i = max(0, s.length - 480); i < s.length; i++) {
      peak = max(peak, s[i].abs());
    }
    // A quarter of the click threshold: a step this big out of silence is
    // audible, and a clip ending here has nowhere to go but zero.
    if (s.last.abs() > _clickThreshold ~/ 4) abrupt++;
    stdout.writeln(
      '${file.uri.pathSegments.last.padRight(20)}'
      '${s.first.abs().toString().padLeft(6)}'
      '${s.last.abs().toString().padLeft(8)}'
      '${peak.toString().padLeft(20)}',
    );
  }
  stdout.writeln(
    '\n$abrupt of $seen clips end on a sample far enough from zero to tick.',
  );

  if (looked == 0) {
    stdout.writeln('\nNo readable WAV narration in the cache.');
    return;
  }
  stdout.writeln(
    '\n$looked files: $rawTotal clicks before the polish, '
    '$polishedTotal after.',
  );
  stdout.writeln(
    polishedTotal <= rawTotal
        ? 'The polish adds none.'
        : 'The polish ADDS ${polishedTotal - rawTotal} clicks.',
  );
}
