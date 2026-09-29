/// Read-only: what a cached narration actually sounds like, measured.
///
/// Two complaints about the Gemini voice — the level drifts between
/// paragraphs, and there is no pause at a paragraph break — are both claims
/// about the waveform, and both are answerable without listening again. This
/// decodes a cached chunk and reports:
///
///   * loudness in dBFS per second, so drift is visible as a number
///   * every silent gap over 150 ms, so paragraph pauses can be counted
///     against the paragraphs in the text that produced it
///
/// Neither is a matter of taste once measured: if the file has three silences
/// and the chapter has nine paragraphs, the pauses are missing.
///
///     dart run tool/audio_shape.dart                 # the largest cached file
///     dart run tool/audio_shape.dart <cache-key>
///     dart run tool/audio_shape.dart --all           # summary of every file
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:moonloom/adapters/tts/audio_compression.dart';

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

class _Wav {
  _Wav(this.rate, this.channels, this.samples);
  final int rate;
  final int channels;
  final Int16List samples;
  double get seconds => samples.length / (rate * channels);
}

_Wav _parse(Uint8List wav) {
  if (wav.length < 44) throw StateError('too short to be a WAV');
  final view = ByteData.sublistView(wav);
  final channels = view.getUint16(22, Endian.little);
  final rate = view.getUint32(24, Endian.little);
  final count = (wav.length - 44) ~/ 2;
  final samples = Int16List(count);
  for (var i = 0; i < count; i++) {
    samples[i] = view.getInt16(44 + i * 2, Endian.little);
  }
  return _Wav(rate, channels == 0 ? 1 : channels, samples);
}

/// Root-mean-square of a window, as dB below full scale.
double _dbfs(Int16List s, int from, int to) {
  var sum = 0.0;
  for (var i = from; i < to && i < s.length; i++) {
    final v = s[i] / 32768.0;
    sum += v * v;
  }
  final n = min(to, s.length) - from;
  if (n <= 0) return -120;
  final rms = sqrt(sum / n);
  return rms <= 1e-6 ? -120 : 20 * (log(rms) / ln10);
}

void main(List<String> args) {
  final dir = _cacheDir();
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
  if (files.isEmpty) {
    stdout.writeln('Cache is empty.');
    return;
  }

  if (args.contains('--all')) {
    stdout.writeln('key                              secs   mean dB   range');
    for (final f in files.take(25)) {
      try {
        final w = _parse(decompressAudio(f.readAsBytesSync()));
        final perSec = <double>[];
        final step = w.rate * w.channels;
        for (var i = 0; i < w.samples.length; i += step) {
          perSec.add(_dbfs(w.samples, i, i + step));
        }
        final voiced = perSec.where((d) => d > -45).toList();
        if (voiced.isEmpty) continue;
        final mean = voiced.reduce((a, b) => a + b) / voiced.length;
        final spread = voiced.reduce(max) - voiced.reduce(min);
        stdout.writeln(
          '${f.uri.pathSegments.last.padRight(32)} '
          '${w.seconds.toStringAsFixed(0).padLeft(4)}   '
          '${mean.toStringAsFixed(1).padLeft(6)}   '
          '${spread.toStringAsFixed(1).padLeft(5)} dB',
        );
      } catch (_) {
        /* not a WAV we can read */
      }
    }
    return;
  }

  final file = args.isEmpty ? files.first : File('${dir.path}\\${args.first}');
  final wav = _parse(decompressAudio(file.readAsBytesSync()));
  stdout.writeln('file     ${file.uri.pathSegments.last}');
  stdout.writeln(
    'format   ${wav.rate} Hz, ${wav.channels} ch, '
    '${wav.seconds.toStringAsFixed(1)} s',
  );

  // Loudness per second, so drift over the chunk is visible.
  final step = wav.rate * wav.channels;
  final perSec = <double>[];
  for (var i = 0; i < wav.samples.length; i += step) {
    perSec.add(_dbfs(wav.samples, i, i + step));
  }
  final voiced = perSec.where((d) => d > -45).toList();
  if (voiced.isNotEmpty) {
    final mean = voiced.reduce((a, b) => a + b) / voiced.length;
    stdout.writeln(
      '\nloudness  mean ${mean.toStringAsFixed(1)} dBFS, '
      'quietest ${voiced.reduce(min).toStringAsFixed(1)}, '
      'loudest ${voiced.reduce(max).toStringAsFixed(1)} '
      '— spread ${(voiced.reduce(max) - voiced.reduce(min)).toStringAsFixed(1)} dB',
    );
    stdout.write('curve     ');
    for (final d in perSec) {
      stdout.write(
        d < -45 ? '.' : '▁▂▃▄▅▆▇█'[((d + 45) / 45 * 7).clamp(0, 7).round()],
      );
    }
    stdout.writeln('   (each mark = 1 s, "." = silence)');
  }

  // Silent gaps, which is where a paragraph pause would be.
  const floor = -50.0;
  final window = wav.rate ~/ 50; // 20 ms
  var runStart = -1;
  final gaps = <(double, double)>[];
  for (var i = 0; i + window < wav.samples.length; i += window) {
    final quiet = _dbfs(wav.samples, i, i + window) < floor;
    if (quiet && runStart < 0) runStart = i;
    if (!quiet && runStart >= 0) {
      final ms = (i - runStart) / wav.rate * 1000;
      if (ms >= 150) {
        gaps.add((runStart / wav.rate, ms));
      }
      runStart = -1;
    }
  }
  stdout.writeln('\npauses over 150 ms: ${gaps.length}');
  for (final (at, ms) in gaps.take(20)) {
    stdout.writeln(
      '  at ${at.toStringAsFixed(1).padLeft(6)} s   '
      '${ms.toStringAsFixed(0).padLeft(4)} ms',
    );
  }
  if (gaps.length > 20) stdout.writeln('  … and ${gaps.length - 20} more');
}
