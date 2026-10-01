import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/story_character.dart';

/// Who already lives in this world, with their faces, and a way to put one of
/// them at the centre of tonight's story.
///
/// "New episode" has always promised that a world's characters carry over
/// automatically, and then shown none of them. A grown-up had to remember who
/// was in it and type a name into a box — which is how a request for Pip
/// arrived as "PIP", matched nothing the world had saved, and came back as a
/// story about somebody else. The names are right here; they should be
/// tappable.
///
/// The faces are the character sheets, already drawn and already paid for, and
/// the same drawings every picture in the world is made against. Showing them
/// costs nothing and is the clearest possible statement of what "carries over"
/// means: that fox, that one, the one you are looking at.
///
/// A character with no sheet yet shows their initial in the world's manner
/// rather than a gap, because a world usually gains its cast before it gains
/// its drawings.
class WorldCastStrip extends ConsumerWidget {
  const WorldCastStrip({
    super.key,
    required this.worldId,
    required this.selected,
    required this.onPick,
  });

  final String worldId;

  /// The name currently in the hero field, matched case-insensitively — a
  /// grown-up typing "pip" has picked Pip.
  final String selected;

  /// Called with the character's name exactly as the world spells it, or null
  /// when the same face is tapped again to unpick it.
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cast =
        ref.watch(charactersForWorldProvider(worldId)).asData?.value ??
        const <StoryCharacter>[];
    if (cast.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who is in this world', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'They all carry over. Tap one to make tonight their story.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _CastFace(
              character: cast[i],
              selected:
                  cast[i].name.toLowerCase() == selected.trim().toLowerCase(),
              onTap: () => onPick(
                cast[i].name.toLowerCase() == selected.trim().toLowerCase()
                    ? null
                    : cast[i].name,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CastFace extends ConsumerWidget {
  const _CastFace({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final StoryCharacter character;
  final bool selected;
  final VoidCallback onTap;

  static const double _size = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(_size * 0.28);

    Widget initial() => Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Text(
        character.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: _size * 0.4,
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    Widget face = character.sheetFileKey.isEmpty
        ? initial()
        : FutureBuilder(
            future: ref
                .read(pictureStoreProvider)
                .fileFor(character.sheetFileKey),
            builder: (context, snapshot) {
              final file = snapshot.data;
              // The initial stands in while the file resolves and for a sheet
              // whose file has gone, so the row never shifts and a missing
              // drawing is never an empty square.
              if (file == null || !file.existsSync()) return initial();
              return ClipRRect(
                borderRadius: radius,
                child: Image.file(
                  file,
                  width: _size,
                  height: _size,
                  // A sheet is three views on a wide cream field, so the
                  // left third — the front view — is the face worth showing.
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.cover,
                ),
              );
            },
          );

    return Semantics(
      button: true,
      selected: selected,
      label: character.description.trim().isEmpty
          ? character.name
          : '${character.name}, ${character.description}',
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_size * 0.28 + 3),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: face,
              ),
              const SizedBox(height: 4),
              Text(
                character.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
