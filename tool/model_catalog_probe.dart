/// Read-only: ask each provider what models the saved key can actually reach,
/// and print how the app classifies them.
///
/// The unit tests parse responses *we wrote*. This one parses the responses the
/// providers actually send, which is the only way to know the field names are
/// right — the same reason `tool/` exists at all. List endpoints are free and
/// change nothing.
///
///     dart run tool/model_catalog_probe.dart            # every saved key
///     dart run tool/model_catalog_probe.dart gemini     # just one
///
/// Keys are decrypted from the app's own store to make the call and are never
/// printed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:moonloom/adapters/ai/model_catalog.dart';
import 'package:moonloom/adapters/ai/provider_exceptions.dart';
import 'package:moonloom/adapters/secrets/dpapi.dart';
import 'package:moonloom/adapters/secrets/secret_store.dart';

/// Reads the app's SharedPreferences file straight off disk — the plugin needs
/// Flutter bindings a `dart run` tool doesn't have, but the file is plain JSON.
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
      return null; // written by another Windows user
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
  final secrets = await _StoredKeys.open();
  final wanted = args.isEmpty ? null : args.first.toLowerCase();

  final directories = <String, ModelDirectory>{
    'claude': AnthropicModelDirectory(secrets: secrets),
    'openai': OpenAiModelDirectory(secrets: secrets),
    'gemini': GoogleModelDirectory(secrets: secrets),
    'elevenlabs': ElevenLabsModelDirectory(secrets: secrets),
  };

  for (final entry in directories.entries) {
    if (wanted != null && entry.key != wanted) continue;
    stdout.writeln('\n── ${entry.key} ${'─' * (60 - entry.key.length)}');
    if (!await secrets.hasKey(entry.key)) {
      stdout.writeln('   no key saved — skipped');
      continue;
    }
    try {
      final models = await entry.value.list();
      for (final kind in [ModelKind.text, ModelKind.audio]) {
        final of = models.where((m) => m.kind == kind).toList();
        stdout.writeln('   ${kind.name}: ${of.length}');
        for (final m in of) {
          stdout.writeln(
            '     ${m.id.padRight(42)}'
            '${m.preview ? '[preview] ' : ''}${m.note}',
          );
        }
      }
      final dropped = models.where((m) => m.kind == ModelKind.other).toList();
      stdout.writeln('   not offered: ${dropped.length}');
      // Printed so a filter that is too eager shows up here rather than as a
      // model quietly missing from the dropdown.
      for (final m in dropped) {
        stdout.writeln('     ${m.id}');
      }
    } on ProviderNotConfigured catch (e) {
      stdout.writeln('   ${e.message}');
    } on ProviderRequestException catch (e) {
      stdout.writeln('   HTTP ${e.statusCode}: ${e.message}');
    } catch (e) {
      stdout.writeln('   failed: $e');
    }
  }
  exit(0); // http clients keep the isolate alive otherwise
}
