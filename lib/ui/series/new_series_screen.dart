import 'package:flutter/material.dart' hide HeroMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../common/language_choices.dart';
import '../../domain/cast_line.dart';
import '../../domain/models/beat.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/series.dart';
import '../../domain/models/world.dart';
import '../../domain/twist_deck.dart';
import '../story/story_chapters_screen.dart';
import 'theme_picker.dart';
import 'world_cast_strip.dart';
import 'world_voice_picker.dart';

/// How a story handles language, as offered when it is created. Stored on the
/// series as `bilingualEnabled` + `bilingualBlend`; [_LanguageMode.sprinkle]
/// and [_LanguageMode.halfAndHalf] are the two levels worth offering a child
/// at bedtime, and the model's `phrases` level stays reachable for stories
/// already saved with it.
enum _LanguageMode { one, sprinkle, halfAndHalf }

/// The story creator. Reached two ways:
///  * from the bookshelf / home → a fresh story, which can be standalone, start
///    a new world, or join an existing world;
///  * from a world's "New episode" → locked to that world (its characters +
///    premise carry over automatically).
/// Builds the story and opens its chapter list. See `docs/ui-ux.md`.
class NewSeriesScreen extends ConsumerStatefulWidget {
  const NewSeriesScreen({super.key});

  @override
  ConsumerState<NewSeriesScreen> createState() => _NewSeriesScreenState();
}

class _NewSeriesScreenState extends ConsumerState<NewSeriesScreen> {
  /// Placeholder shown until the model names the story from its first chapter.
  static const String _pendingTitle = 'Naming it…';

  /// The most themes a story can blend at once.
  static const int _maxThemes = 3;

  final _title = TextEditingController();
  final _heroName = TextEditingController();
  final _idea = TextEditingController();
  final _worldName = TextEditingController();

  /// The voice a newly created world will use; empty means the parent's setting.
  String _worldVoice = '';

  /// Up to [_maxThemes] flavours, in the order they were picked (the first is
  /// the lead theme).
  final List<StoryTheme> _themes = [StoryTheme.cozy];
  HeroMode _heroMode = HeroMode.childAsHero;

  /// The opening choice: a twist-card id, or 'dice' for a random surprise.
  String _opening = 'dice';

  /// A fresh random hand from the ~50-card deck, drawn once per visit so the
  /// choices don't reshuffle under the child's finger.
  final List<Twist> _openings = const TwistDeck().options();

  /// Where to save it: null = standalone, 'new' = a new world, else a world id.
  String? _worldChoice;

  /// How the story handles language. Maps onto the series' bilingual fields;
  /// the middle option is deliberately a *few words* rather than whole
  /// phrases, because that is the level a child picks up at bedtime.
  _LanguageMode _language = _LanguageMode.one;

  /// The language woven in when [_language] isn't [_LanguageMode.one].
  String _secondLanguage = 'es';

  /// The language this story is told in. Empty means the child's own — the
  /// answer for most homes. A bilingual household needs one child to be able
  /// to have stories in both, which a single setting on the profile can't do.
  String _baseLanguage = '';

  bool _creating = false;

  /// The language the story is actually told in, for keeping the second
  /// language distinct from it.
  String get _mainLanguage => _baseLanguage.isNotEmpty
      ? _baseLanguage
      : (ref.read(activeChildProvider)?.language ?? 'en');

  @override
  void dispose() {
    _title.dispose();
    _heroName.dispose();
    _idea.dispose();
    _worldName.dispose();
    super.dispose();
  }

  void _toggleTheme(StoryTheme t) => setState(() {
    final next = ThemePicker.toggled(_themes, t, maxThemes: _maxThemes);
    _themes
      ..clear()
      ..addAll(next);
  });

  Future<void> _setLength(DetailLevel level) async {
    final child = ref.read(activeChildProvider);
    if (child == null || child.detailLevel == level) return;
    final updated = child.copyWith(detailLevel: level);
    await ref.read(profileServiceProvider).update(updated);
    ref.read(activeChildProvider.notifier).select(updated);
    ref.invalidate(profilesProvider);
  }

  Future<void> _create(World? episodeWorld) async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    setState(() => _creating = true);
    // An empty name means "you name it" — the model titles the story from the
    // chapter it writes, and the placeholder is replaced once it does.
    final named = _title.text.trim();
    final title = named.isEmpty ? _pendingTitle : named;

    // Resolve the world (if any) and the theme it implies.
    String? worldId;
    var theme = _themes.first;
    var extraThemes = _themes.skip(1).toList();
    if (episodeWorld != null) {
      // An episode inherits its world's flavour, so editing the world steers
      // every future episode.
      worldId = episodeWorld.id;
      theme = episodeWorld.theme;
      extraThemes = episodeWorld.extraThemes;
    } else if (_worldChoice == 'new') {
      final name = _worldName.text.trim().isEmpty
          ? title
          : _worldName.text.trim();
      final world = await ref
          .read(worldServiceProvider)
          .create(
            childId: child.id,
            name: name,
            theme: theme,
            extraThemes: extraThemes,
            voiceName: _worldVoice,
          );
      worldId = world.id;
      ref.invalidate(worldsForChildProvider(child.id));
    } else if (_worldChoice != null) {
      worldId = _worldChoice;
    }

    // A hero the world already knows is sent under the world's own spelling.
    // The cast list goes into the prompt verbatim and says these names are
    // fixed facts, so a hero called "PIP" beside a cast entry for "Pip" reads
    // as two characters with similar names — which is exactly how a request
    // for one character came back as a story about another. Tapping a face
    // avoids this; typing is still allowed, and now lands in the same place.
    var heroName = _heroName.text.trim();
    if (worldId != null && heroName.isNotEmpty) {
      final known = await ref.read(characterServiceProvider).forWorld(worldId);
      for (final character in known) {
        if (foldedName(character.name) == foldedName(heroName)) {
          heroName = character.name;
          break;
        }
      }
    }

    final quiz = await ref.read(storageRepoProvider).latestQuizResult(child.id);
    final series = await ref
        .read(seriesServiceProvider)
        .create(
          childId: child.id,
          title: title,
          theme: theme,
          extraThemes: extraThemes,
          autoTitle: named.isEmpty,
          worldId: worldId,
          heroMode: _heroMode,
          heroName: _heroMode == HeroMode.namedHero ? heroName : null,
          seedSummary: quiz?.seedSummary ?? '',
          baseLanguage: _baseLanguage.isEmpty ? null : _baseLanguage,
          bilingualEnabled: _language != _LanguageMode.one,
          secondaryLanguage: _language == _LanguageMode.one
              ? null
              : _secondLanguage,
          detailLevel: child.detailLevel,
          bilingualBlend: switch (_language) {
            _LanguageMode.one => null,
            _LanguageMode.sprinkle => BilingualBlend.sprinkle,
            _LanguageMode.halfAndHalf => BilingualBlend.alternating,
          },
        );

    // Resolve how chapter 1 begins.
    final idea = _idea.text.trim();
    final StoryIntent intent;
    final String? twist;
    if (idea.isNotEmpty) {
      intent = StoryIntent.request;
      twist = idea;
    } else if (_opening == 'dice') {
      intent = StoryIntent.dice;
      twist = const TwistDeck().roll().hint;
    } else {
      intent = StoryIntent.option;
      twist = const TwistDeck().byId(_opening)?.hint;
    }

    ref.invalidate(seriesForChildProvider(child.id));
    ref.read(activeSeriesProvider.notifier).select(series);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StoryChaptersScreen(initialIntent: intent, initialTwist: twist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = ref.watch(activeChildProvider);
    // Locked to a world when we arrived via "New episode".
    final episodeWorld = ref.watch(activeWorldProvider);
    final worlds =
        ref.watch(worldsForChildProvider(child?.id ?? '')).asData?.value ??
        const <World>[];
    // The world this story will belong to, however it was chosen.
    final castWorld =
        episodeWorld ??
        (_worldChoice == null || _worldChoice == 'new'
            ? null
            : worlds.cast<World?>().firstWhere(
                (w) => w!.id == _worldChoice,
                orElse: () => null,
              ));

    return Scaffold(
      appBar: AppBar(
        title: Text(episodeWorld == null ? 'New story' : 'New episode'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (episodeWorld != null)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '✨ New episode in the world of “${episodeWorld.name}”. Its '
                  'characters and premise carry over automatically.',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: episodeWorld == null ? 'Story name' : 'Episode name',
              hintText: 'Leave blank to let the story name itself',
              helperText: 'We\'ll name it from what happens in it ✨',
            ),
          ),

          // Where to save it — only when not already locked to a world.
          if (episodeWorld == null) ...[
            const SizedBox(height: 24),
            Text('Save to…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              // Fills the width it is given and ellipsizes, rather than sizing to
              // its longest label. "Same as the child (English)" is wider than a
              // phone-shaped window, and a debug build paints the overflow as
              // yellow-and-black stripes across the control.
              isExpanded: true,
              initialValue: _worldChoice,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Just this story'),
                ),
                const DropdownMenuItem(
                  value: 'new',
                  child: Text('➕ A new world'),
                ),
                for (final w in worlds)
                  DropdownMenuItem(
                    value: w.id,
                    child: Text(
                      'World: ${w.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _worldChoice = v),
            ),
            if (_worldChoice == 'new') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _worldName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'World name (e.g. Splat the Cat)',
                  helperText: 'Add characters to the world afterwards',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Who tells the stories here?',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Chosen while the world is being made, so every episode in it
              // keeps the same storyteller — which is most of what makes a
              // world feel like a place rather than a folder.
              WorldVoicePicker(
                value: _worldVoice,
                onChanged: (v) => setState(() => _worldVoice = v),
              ),
            ],
          ],

          // Theme + hero: theme only matters for a fresh (non-episode) story;
          // an episode inherits its world's theme.
          if (episodeWorld == null) ...[
            const SizedBox(height: 24),
            ThemePicker(
              selected: _themes,
              maxThemes: _maxThemes,
              onToggle: _toggleTheme,
            ),
          ],

          // Who already lives here, with their faces. The promise above — that
          // the characters carry over — was never shown, so a grown-up had to
          // remember the cast and type a name into the box below. That is how
          // a request for Pip arrived as "PIP" and matched nothing.
          //
          // Shown for a world chosen from "Save to…" as well as for one
          // arrived at through "New episode": the characters carry over just
          // the same, and a screen that said so in one place and not the other
          // would be describing the app rather than what it does.
          if (castWorld != null) ...[
            const SizedBox(height: 24),
            WorldCastStrip(
              worldId: castWorld.id,
              selected: _heroMode == HeroMode.namedHero ? _heroName.text : '',
              onPick: (name) => setState(() {
                if (name == null) {
                  _heroName.clear();
                  _heroMode = HeroMode.childAsHero;
                  return;
                }
                // Spelled as the world spells it, never as it was typed: the
                // cast list is what the prompt carries, and a hero whose name
                // does not match one of its entries reads to the model as a
                // new character with a similar name.
                _heroName.text = name;
                _heroMode = HeroMode.namedHero;
              }),
            ),
          ],

          const SizedBox(height: 24),
          Text('Who is the hero?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<HeroMode>(
            segments: const [
              ButtonSegment(
                value: HeroMode.childAsHero,
                label: Text('The child'),
              ),
              ButtonSegment(
                value: HeroMode.namedHero,
                label: Text('A named hero'),
              ),
              ButtonSegment(value: HeroMode.surprise, label: Text('Surprise')),
            ],
            selected: {_heroMode},
            onSelectionChanged: (s) => setState(() => _heroMode = s.first),
          ),
          if (_heroMode == HeroMode.namedHero) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _heroName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: "Hero's name",
                helperText: episodeWorld == null
                    ? null
                    : 'Someone new is welcome — they join the world for good',
              ),
              // Rebuilt as it is typed so the face above lights up when the
              // name reaches somebody the world knows, which is the only
              // signal that the two fields are the same question.
              onChanged: (_) => setState(() {}),
            ),
          ],

          const SizedBox(height: 24),
          Text('How many nights?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<DetailLevel>(
            segments: const [
              // Chapter counts, not adjectives. "Long" told a grown-up
              // nothing about how many nights it would last, which is the
              // only thing they are actually choosing between.
              ButtonSegment(
                value: DetailLevel.short,
                label: Text('Mini'),
                tooltip: 'One sitting, start to finish',
              ),
              ButtonSegment(
                value: DetailLevel.medium,
                label: Text('A few nights'),
                tooltip: '3 to 4 chapters',
              ),
              ButtonSegment(
                value: DetailLevel.long,
                label: Text('A week'),
                tooltip: '7 chapters — one a night',
              ),
            ],
            selected: {child?.detailLevel ?? DetailLevel.medium},
            onSelectionChanged: _creating ? null : (s) => _setLength(s.first),
          ),

          const SizedBox(height: 24),
          Text('Languages', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // Fills the width it is given and ellipsizes, rather than sizing to
            // its longest label. "Same as the child (English)" is wider than a
            // phone-shaped window, and a debug build paints the overflow as
            // yellow-and-black stripes across the control.
            isExpanded: true,
            initialValue: _baseLanguage,
            decoration: const InputDecoration(
              labelText: 'Told in',
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  'Same as the child'
                  ' (${languageChoices[child?.language ?? 'en'] ?? 'English'})',
                ),
              ),
              for (final entry in languageChoices.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _creating
                ? null
                : (v) => setState(() {
                    _baseLanguage = v ?? '';
                    // Never offer the same language twice.
                    if (_secondLanguage == _mainLanguage) {
                      _secondLanguage = _mainLanguage == 'es' ? 'fr' : 'es';
                    }
                  }),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_LanguageMode>(
            segments: const [
              ButtonSegment(value: _LanguageMode.one, label: Text('One')),
              ButtonSegment(
                value: _LanguageMode.sprinkle,
                label: Text('A few words'),
              ),
              ButtonSegment(
                value: _LanguageMode.halfAndHalf,
                label: Text('Half & half'),
              ),
            ],
            selected: {_language},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _language = s.first;
              // Never offer the language the story is already told in.
              if (_secondLanguage == _mainLanguage) {
                _secondLanguage = _mainLanguage == 'es' ? 'fr' : 'es';
              }
            }),
          ),
          if (_language != _LanguageMode.one) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // Fills the width it is given and ellipsizes, rather than sizing to
              // its longest label. "Same as the child (English)" is wider than a
              // phone-shaped window, and a debug build paints the overflow as
              // yellow-and-black stripes across the control.
              isExpanded: true,
              initialValue: _secondLanguage,
              decoration: const InputDecoration(
                labelText: 'Second language',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in languageChoices.entries)
                  if (entry.key != _mainLanguage)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
              ],
              onChanged: (v) =>
                  setState(() => _secondLanguage = v ?? _secondLanguage),
            ),
            const SizedBox(height: 8),
            Text(switch (_language) {
              _LanguageMode.sprinkle =>
                'A handful of words, repeated through the story so their '
                    'meaning comes from what happens around them.',
              _LanguageMode.halfAndHalf =>
                'Roughly half in each, switching where the story gives a '
                    'reason to. Still followable knowing only the first.',
              _LanguageMode.one => '',
            }, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 24),
          Text('How does it begin?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('🎲 Surprise me'),
                selected: _opening == 'dice',
                onSelected: (_) => setState(() => _opening = 'dice'),
              ),
              for (final t in _openings)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _opening == t.id,
                  onSelected: (_) => setState(() => _opening = t.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idea,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: '…or describe the first scene',
              helperText: 'Overrides the choice above when filled',
            ),
          ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _creating ? null : () => _create(episodeWorld),
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_stories),
            label: Text(
              episodeWorld == null ? 'Create & build story' : 'Build episode',
            ),
          ),
        ],
      ),
    );
  }
}
