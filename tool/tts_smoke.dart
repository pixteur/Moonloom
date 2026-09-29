/// Ask a voice model to actually speak a line, through the app's own adapter.
///
/// Same reasoning as `tool/gemini_smoke.dart`: the model list says a voice
/// exists, and only a real request shows whether the body we send is accepted
/// and whether what comes back is audio we can play. Prints the size and the
/// first bytes so a WAV/MP3 header can be eyeballed rather than assumed.
///
///     dart run tool/tts_smoke.dart gemini gemini-3.8-flash-tts
///     dart run tool/tts_smoke.dart gemini            # the app's default
///
/// Costs one short synthesis per run. Writes the audio to the scratch path
/// given by --out, or nowhere.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/tts/gemini_tts_synthesizer.dart';
import 'package:moonloom/domain/models/narration.dart';

class _StoredKeys implements SecretStore {
  _StoredKeys(this._prefs);

  static Future<_StoredKeys> open() async {
    final file = File(
      '${Platform.environment['APPDATA']}'
      r'\com.pixteur\moonloom\shared_preferences.json',
    );
    if (!file.existsSync()) throw StateError('No prefs at ${file.path}');
    return _StoredKeys(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  final Map<String, dynamic> _prefs;

  @override
  Future<String?> readKey(String providerId) async {
    final stored = _prefs['flutter.enckey_$providerId'] as String?;
    if (stored == null) return null;
    try {
      return dpapiUnprotect(base64.decode(stored));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasKey(String providerId) async =>
      _prefs['flutter.enckey_$providerId'] != null;

  @override
  Future<void> writeKey(String providerId, String key) async =>
      throw UnsupportedError('read-only probe');

  @override
  Future<void> deleteKey(String providerId) async =>
      throw UnsupportedError('read-only probe');
}

Future<void> main(List<String> args) async {
  final models = args.isEmpty ? [GeminiTtsSynthesizer.defaultModel] : args;
  final secrets = await _StoredKeys.open();
  final client = http.Client();

  const line =
      'Crystal the fox lifted her lantern, and the whole meadow turned gold.';
  const cue = NarrationCue(pace: 'slow', emotion: 'wistful', volume: 'hushed');

  for (final model in models) {
    stdout.write('${model.padRight(34)} ');
    final started = DateTime.now();
    try {
      final bytes =
          await GeminiTtsSynthesizer(
            secrets: secrets,
            httpClient: client,
            model: model,
          ).synthesize(
            line,
            cue: cue,
            standingDirection: 'Warm, unhurried bedtime narrator.',
          );
      final ms = DateTime.now().difference(started).inMilliseconds;
      final head = bytes
          .take(4)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      stdout.writeln(
        'ok  ${ms}ms  ${(bytes.length / 1024).toStringAsFixed(0)} KB  '
        'starts $head  ${_container(bytes)}',
      );
    } catch (e) {
      stdout.writeln('FAILED');
      stdout.writeln('   $e');
    }
  }
  client.close();
}

String _container(List<int> bytes) {
  if (bytes.length < 12) return 'too short to tell';
  final tag = String.fromCharCodes(bytes.take(4));
  if (tag == 'RIFF') return 'RIFF/WAV';
  if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) return 'MPEG frame';
  if (tag.startsWith('ID3')) return 'MP3 with ID3';
  return 'unrecognised container';
}
