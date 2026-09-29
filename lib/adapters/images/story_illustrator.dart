/// Drawing a story's pictures.
///
/// Behind the same kind of seam as the voice: the domain asks for a picture of
/// a scene, and an adapter decides which model draws it. See
/// `docs/story-images.md` and `docs/architecture.md`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/story_image.dart';

import '../ai/provider_exceptions.dart';
import '../ai/rate_limit_retry.dart';
import '../ai/story_segment_codec.dart';
import '../secrets/secret_store.dart';

/// One drawn picture and what was asked for.
class DrawnPicture {
  const DrawnPicture({
    required this.bytes,
    required this.prompt,
    required this.model,
    required this.size,
    required this.aspect,
    this.seed,
  });

  final Uint8List bytes;
  final String prompt;
  final String model;
  final String size;
  final String aspect;
  final int? seed;
}

abstract class StoryIllustrator {
  /// [references] are handed to the model as input images, in order. The
  /// prompt names them "the first", "the second" and so on, so this order and
  /// the order in the prompt have to agree — which is why both are built in
  /// one place, by `IllustrationService`.
  Future<DrawnPicture> draw(
    String prompt, {
    StoryImageKind kind,
    int? seed,
    List<Uint8List> references,
  });
}

/// Nano Banana 2 — `gemini-3.1-flash-image`.
class GeminiIllustrator implements StoryIllustrator {
  GeminiIllustrator({
    required SecretStore secrets,
    http.Client? httpClient,
    this.model = defaultModel,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  static const String keyName = 'gemini';

  /// Nano Banana 2: the balance of quality and cost. Pro is roughly double
  /// for a picture this size; Lite is half and loses the detail a cover wants.
  static const String defaultModel = 'gemini-3.1-flash-image';

  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final SecretStore _secrets;
  final http.Client _http;
  final String model;

  /// Portrait for a cover, landscape for a chapter, and landscape for the
  /// storyteller, whose screen is 4:3.
  static String aspectFor(StoryImageKind kind) => switch (kind) {
    StoryImageKind.cover => '3:4',
    StoryImageKind.chapter => '4:3',
    StoryImageKind.lunii => '4:3',
    StoryImageKind.characterSheet => '4:3',
  };

  /// 2K everywhere it might be printed, 1K for the device, which throws away
  /// all but 320×240 of it anyway.
  static String sizeFor(StoryImageKind kind) =>
      kind == StoryImageKind.lunii ? '1K' : '2K';

  @override
  Future<DrawnPicture> draw(
    String prompt, {
    StoryImageKind kind = StoryImageKind.chapter,
    int? seed,
    List<Uint8List> references = const [],
  }) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Gemini API key configured.');
    }
    final size = sizeFor(kind);
    final aspect = aspectFor(kind);
    return retryOnRateLimit(() async {
      final response = await _http.post(
        Uri.parse('$_base/$model:generateContent'),
        headers: {'content-type': 'application/json', 'x-goog-api-key': key},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                // References first, then the instruction, so the instruction
                // reads as being about the pictures above it.
                for (final bytes in references)
                  {
                    'inline_data': {
                      'mime_type': 'image/png',
                      'data': base64.encode(bytes),
                    },
                  },
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseModalities': ['IMAGE'],
            'imageConfig': {'aspectRatio': aspect, 'imageSize': size},
            // Recorded even though the model does not honour it. Keeping it
            // costs nothing and means a later model that does can be told
            // what we meant. See StoryImage.seed.
            'seed': ?seed,
          },
        }),
      );
      if (response.statusCode != 200) {
        throw ProviderRequestException(
          response.statusCode,
          extractApiError(response.body),
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        // A safety filter refuses by returning nothing rather than an error.
        // The caller falls back to the procedural cover, which is why this is
        // a typed exception and not a null.
        throw const ProviderRequestException(200, 'The picture was refused.');
      }
      final parts =
          ((candidates.first as Map)['content'] as Map)['parts'] as List;
      for (final part in parts) {
        final data = ((part as Map)['inlineData'] as Map?)?['data'] as String?;
        if (data == null) continue;
        return DrawnPicture(
          bytes: base64.decode(data),
          prompt: prompt,
          model: model,
          size: size,
          aspect: aspect,
          seed: seed,
        );
      }
      throw const ProviderRequestException(200, 'No image came back.');
    });
  }
}
