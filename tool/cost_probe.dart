/// Measure what one real story actually costs, in tokens the API counted.
///
/// A price per million tokens is useless without knowing how many tokens a
/// bedtime story is, and every estimate of that is a guess until the API
/// reports back. So this runs a genuine long story — the real PromptBuilder,
/// the real two-pass editorial flow, the real growing story bible — and reads
/// `usageMetadata` off each response.
///
/// It also measures the part that is easy to forget: the second pass doubles
/// the call count, and a chapter's prompt grows as the bible and the recent
/// chapters accumulate, so chapter 6 costs more than chapter 1.
///
///     dart run tool/cost_probe.dart                    # 6 chapters, default model
///     dart run tool/cost_probe.dart --model gemini-3.8-flash --chapters 6
///     dart run tool/cost_probe.dart --tts              # also price the narration
///
/// Costs one real story per run. Writes nothing to the library.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sleepytime/adapters/ai/gemini_provider.dart';
import 'package:sleepytime/adapters/secrets/dpapi.dart';
import 'package:sleepytime/domain/models/beat.dart';
import 'package:sleepytime/domain/models/child_profile.dart';
import 'package:sleepytime/domain/models/series.dart';
import 'package:sleepytime/domain/models/story_request.dart';
import 'package:sleepytime/domain/models/story_segment.dart';
import 'package:sleepytime/domain/prompt_builder.dart';

const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

Future<String?> _key(String provider) async {
  final file = File(
    '${Platform.environment['APPDATA']}'
    r'\com.pixteur\sleepytime\shared_preferences.json',
  );
  if (!file.existsSync()) return null;
  final prefs = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final stored = prefs['flutter.enckey_$provider'] as String?;
  if (stored == null) return null;
  try {
    return dpapiUnprotect(base64.decode(stored));
  } catch (_) {
    return null;
  }
}

String? _opt(List<String> args, String name) {
  final at = args.indexOf(name);
  return at >= 0 && at + 1 < args.length ? args[at + 1] : null;
}

class _Usage {
  _Usage(this.input, this.output);
  final int input;
  final int output;
}

Future<void> main(List<String> args) async {
  final model = _opt(args, '--model') ?? GeminiProvider.defaultModel;
  final chapters = int.tryParse(_opt(args, '--chapters') ?? '') ?? 6;
  final key = await _key('gemini');
  if (key == null) {
    stdout.writeln('No Gemini key saved.');
    return;
  }
  final client = http.Client();
  const builder = PromptBuilder();

  // A long story for an eight-year-old: the most expensive normal case.
  const child = ChildProfile(
    id: 'c1',
    displayName: 'Mia',
    age: 8,
    detailLevel: DetailLevel.long,
  );
  var series = const Series(
    id: 's1',
    childId: 'c1',
    title: 'The Lantern That Would Not Sleep',
    theme: StoryTheme.cozy,
    seedSummary:
        'A child who likes quiet puzzles, gentle mysteries and being the one '
        'who notices what everyone else missed.',
    heroMode: HeroMode.namedHero,
    heroName: 'Crystal',
  );

  final recent = <Beat>[];
  var draftIn = 0, draftOut = 0, editIn = 0, editOut = 0, characters = 0;

  stdout.writeln('model: $model   chapters: $chapters   length: long\n');
  stdout.writeln(
    'ch   draft in/out      edit in/out       words   running total tokens',
  );

  for (var n = 1; n <= chapters; n++) {
    final request = StoryRequest(
      child: child,
      series: series,
      intent: n == 1 ? StoryIntent.dice : StoryIntent.continued,
      recentBeats: List.of(recent),
      chapterNumber: n,
      maxChapters: chapters,
      minChapters: chapters,
      chosenTwist: n == 1 ? 'a lantern that will not go out' : null,
      worldPremise: 'A hush-lit forest where small creatures trade riddles.',
      cast: const ['Pip — a small brave fox who leads the way'],
    );

    final (draft, dUse) = await _generate(
      client,
      key,
      model,
      builder.build(request),
    );
    draftIn += dUse.input;
    draftOut += dUse.output;

    // The editorial second pass runs on every chapter before it is saved, so
    // it is not optional overhead — it is half the cost of a story.
    final (edited, eUse) = await _generate(
      client,
      key,
      model,
      builder.buildRefinement(request, draft),
    );
    editIn += eUse.input;
    editOut += eUse.output;

    final text = edited.storyText.isEmpty ? draft.storyText : edited.storyText;
    characters += text.length;
    final words = text.split(RegExp(r'\s+')).length;

    recent.add(
      Beat(
        id: 'b$n',
        seriesId: 's1',
        childId: 'c1',
        seq: n - 1,
        intent: StoryIntent.continued,
        text: text,
        summary: edited.summary.isEmpty ? draft.summary : edited.summary,
        title: edited.chapterTitle,
        rating: draft.rating,
      ),
    );
    // The bible grows with the story, which is why later chapters cost more.
    series = series.copyWith(
      storyBible: '${series.storyBible} ${recent.last.summary}'.trim(),
    );

    final total = draftIn + draftOut + editIn + editOut;
    stdout.writeln(
      '${n.toString().padLeft(2)}   '
      '${'${dUse.input}/${dUse.output}'.padRight(18)}'
      '${'${eUse.input}/${eUse.output}'.padRight(18)}'
      '${words.toString().padLeft(5)}   $total',
    );
  }

  stdout.writeln('\n── one long ${chapters}-chapter story ──');
  stdout.writeln('  draft   in $draftIn  out $draftOut');
  stdout.writeln('  edit    in $editIn  out $editOut');
  stdout.writeln('  TOTAL   in ${draftIn + editIn}  out ${draftOut + editOut}');
  stdout.writeln('  story text: $characters characters');

  if (args.contains('--tts')) {
    stdout.writeln('\n── narration ──');
    final sample = recent.first.text;
    final use = await _speak(client, key, sample);
    if (use != null) {
      final perChar = use.output / sample.length;
      stdout.writeln(
        '  ${sample.length} characters -> ${use.output} audio tokens '
        '(${perChar.toStringAsFixed(2)} per character)',
      );
      stdout.writeln(
        '  whole story would be ~${(characters * perChar).round()} '
        'audio tokens',
      );
    }
  }
  client.close();
}

Future<(StorySegment, _Usage)> _generate(
  http.Client client,
  String key,
  String model,
  StoryPrompt prompt,
) async {
  final response = await client.post(
    Uri.parse('$_base/$model:generateContent'),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': prompt.system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt.user},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'maxOutputTokens': 4096,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    }),
  );
  if (response.statusCode != 200) {
    throw StateError('${response.statusCode}: ${response.body}');
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final usage = decoded['usageMetadata'] as Map<String, dynamic>? ?? const {};
  final text =
      ((((decoded['candidates'] as List).first as Map)['content']
                  as Map)['parts']
              as List)
          .map((p) => (p as Map)['text'] ?? '')
          .join();
  final json = jsonDecode(text) as Map<String, dynamic>;
  return (
    StorySegment(
      storyText: (json['story_text'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      rating: AgeRating.big,
      chapterTitle: (json['chapter_title'] as String?) ?? '',
    ),
    _Usage(
      (usage['promptTokenCount'] as int?) ?? 0,
      (usage['candidatesTokenCount'] as int?) ?? 0,
    ),
  );
}

Future<_Usage?> _speak(http.Client client, String key, String text) async {
  final response = await client.post(
    Uri.parse('$_base/gemini-3.8-flash-tts:generateContent'),
    headers: {'content-type': 'application/json', 'x-goog-api-key': key},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': text},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': 'Kore'},
          },
        },
      },
    }),
  );
  if (response.statusCode != 200) {
    stdout.writeln('  tts ${response.statusCode}: ${response.body}');
    return null;
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final usage = decoded['usageMetadata'] as Map<String, dynamic>? ?? const {};
  return _Usage(
    (usage['promptTokenCount'] as int?) ?? 0,
    (usage['candidatesTokenCount'] as int?) ?? 0,
  );
}
