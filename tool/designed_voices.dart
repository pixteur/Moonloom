/// Read-only: the voices this app has designed in the parent's Google project,
/// through the app's own adapter.
///
///     dart run tool/designed_voices.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';
import 'package:moonloom/adapters/tts/gemini_voice_designer.dart';

class _Keys implements SecretStore {
  _Keys(this._prefs);
  final Map<String, dynamic> _prefs;
  @override
  Future<String?> readKey(String id) async {
    final s = _prefs['flutter.enckey_$id'] as String?;
    return s == null ? null : dpapiUnprotect(base64.decode(s));
  }

  @override
  Future<bool> hasKey(String id) async => _prefs['flutter.enckey_$id'] != null;
  @override
  Future<void> writeKey(String id, String key) async {}
  @override
  Future<void> deleteKey(String id) async {}
}

Future<void> main() async {
  final prefs =
      jsonDecode(
            File(
              '${Platform.environment['APPDATA']}'
              r'\com.pixteur\moonloom\shared_preferences.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final voices = await GeminiVoiceDesigner(secrets: _Keys(prefs)).list();
  stdout.writeln('${voices.length} designed voices');
  for (final v in voices) {
    stdout.writeln('  ${v.name.padRight(20)} ${v.id}');
  }
}
