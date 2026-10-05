import 'dart:convert';

import '../../domain/models/beat.dart';
import '../../domain/models/narration.dart';
import '../../domain/models/story_segment.dart';

/// The provider-agnostic JSON shape every provider's structured output fills.
/// Property names are shared; each provider encodes the schema in its own
/// dialect (JSON Schema / Gemini Schema). See `docs/ai-providers.md`.
const List<String> storySegmentFields = [
  'story_text',
  'story_title',
  'chapter_title',
  'summary',
  'rating',
  'setting',
  'sensitive_flags',
  'characters',
  'open_threads',
  'is_final',
  'narration_style',
  'character_voices',
  'narration_cues',
  'dialogue_speakers',
];

/// Standard JSON Schema for the story segment — used by Claude (`output_config`)
/// and OpenAI (`response_format.json_schema`). Gemini uses its own dialect.
const Map<String, dynamic> jsonStorySchema = {
  'type': 'object',
  'properties': {
    'story_text': {'type': 'string'},
    'story_title': {'type': 'string'},
    'chapter_title': {'type': 'string'},
    'summary': {'type': 'string'},
    'rating': {
      'type': 'string',
      'enum': ['tiny', 'little', 'big', 'older'],
    },
    'setting': {'type': 'string'},
    'sensitive_flags': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'characters': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'open_threads': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'is_final': {'type': 'boolean'},
    'narration_style': {'type': 'string'},
    'character_voices': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'narration_cues': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'dialogue_speakers': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
  'required': storySegmentFields,
  'additionalProperties': false,
};

/// Parse the model's JSON object into a [StorySegment]. Unknown ratings map to
/// the strictest band so [SafetyGuard] can still reject if it's too high.
StorySegment storySegmentFromJson(Map<String, dynamic> d) => StorySegment(
  storyText: (d['story_text'] as String?) ?? '',
  suggestedTitle: (d['story_title'] as String?)?.trim() ?? '',
  chapterTitle: (d['chapter_title'] as String?)?.trim() ?? '',
  summary: (d['summary'] as String?) ?? '',
  rating: _rating(d['rating'] as String?),
  setting: (d['setting'] as String?) ?? '',
  sensitiveFlags: _strList(d['sensitive_flags']),
  characters: _strList(d['characters']),
  openThreads: _strList(d['open_threads']),
  isFinal: d['is_final'] as bool? ?? false,
  narration: NarrationNotes(
    style: (d['narration_style'] as String?)?.trim() ?? '',
    characterVoices: _strList(d['character_voices']),
    cues: _strList(d['narration_cues']).map(NarrationCue.parse).toList(),
    speakers: _strList(d['dialogue_speakers']),
  ),
);

AgeRating _rating(String? value) => switch (value) {
  'tiny' => AgeRating.tiny,
  'little' => AgeRating.little,
  'big' => AgeRating.big,
  'older' => AgeRating.older,
  _ => AgeRating.older,
};

List<String> _strList(Object? value) =>
    (value as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

/// Pull a human-readable message from an API error body (`{error:{message}}`),
/// falling back to the raw body. Shared by all providers.
String extractApiError(String body) {
  try {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      return (error['message'] as String?) ?? body;
    }
    return body;
  } catch (_) {
    return body;
  }
}
