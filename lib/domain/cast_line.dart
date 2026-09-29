/// Reading a character out of the line a model wrote about them.
///
/// Every chapter records its cast, and the model writes that list in whatever
/// shape it fancies. Across one library, all four of these appear:
///
///     Pip, an axolotl
///     Bolt — a small silver robot
///     Pip (axolotl)
///     Lumina: an ocean dragon
///
/// Splitting on only the first two — which is what the first version did —
/// saves "Pip (axolotl)" as somebody's **name**, and then the world has a Pip
/// and a "Pip (axolotl)" and a "Pip: an axolotl", none of whom are each other.
/// A cast list like that is worse than none: it fills the prompt with
/// near-duplicates and teaches the model that the name includes the species.
///
/// So this is one pure function with tests, used by the engine when it saves a
/// chapter's people and by `tool/backfill_cast.dart` when it reads the past.
/// Pure Dart, no Flutter. See `docs/data-model.md`.
library;

/// The separators a description hides behind, in the order they are tried.
/// The bracket form is handled separately because it wraps rather than splits.
final RegExp _separator = RegExp(r'\s*(?:[—–]|:|,|\s-\s)\s*');

/// A name in brackets: `Pip (axolotl)`, `Bolt (robot, Leo's companion)`.
final RegExp _bracketed = RegExp(r'^(.+?)\s*[(\[](.+)[)\]]\s*$');

/// Anything longer than this is prose, not a name. Storing it would put a
/// paragraph into every future prompt and steer nothing.
const int _maxNameLength = 40;

/// The name and the description in [entry].
///
/// A name with nothing after it keeps an empty description: knowing Pip exists
/// is worth more than knowing nothing, and a later chapter usually says more.
/// An entry with no usable name at all returns empty, and callers drop it.
(String name, String description) parseCastEntry(String entry) {
  var trimmed = entry.trim();
  if (trimmed.isEmpty) return ('', '');

  // Brackets first: "Pip (axolotl)" hides its separator inside them, and
  // splitting on the comma in "Bolt (robot, co-pilot)" would cut the
  // description in half rather than finding the name.
  final bracket = _bracketed.firstMatch(trimmed);
  if (bracket != null) {
    final before = bracket.group(1)!;
    final inside = _tidyDescription(bracket.group(2)!);

    // What comes before the bracket may itself be a name AND a description —
    // "Lumina, a young ocean dragon (she/her)" puts the species outside and
    // only the pronoun inside. Taking the whole of it as the name is how a
    // world ends up with somebody called "Lumina, a young ocean dragon".
    final split = _separator.firstMatch(before);
    if (split != null) {
      final name = _tidyName(before.substring(0, split.start));
      if (name.isNotEmpty) {
        final outside = _tidyDescription(before.substring(split.end));
        return (name, [outside, inside].where((s) => s.isNotEmpty).join(', '));
      }
    }

    final name = _tidyName(before);
    if (name.isNotEmpty) return (name, inside);
    // A bracket with no name before it is not a character, it is a note.
    trimmed = bracket.group(2)!;
  }

  final split = _separator.firstMatch(trimmed);
  if (split == null) return (_tidyName(trimmed), '');

  final name = _tidyName(trimmed.substring(0, split.start));
  // "— a small robot" with nothing before the dash names nobody.
  if (name.isEmpty) return ('', '');
  return (name, _tidyDescription(trimmed.substring(split.end)));
}

/// Whether two entries are about the same character.
///
/// Compared on the name alone and case-insensitively, because the same person
/// arrives as "Pip", "pip" and "Pip (axolotl)" across three chapters, and a
/// world with three Pips in it is the bug this whole file exists to prevent.
bool sameCharacter(String a, String b) =>
    parseCastEntry(a).$1.toLowerCase() == parseCastEntry(b).$1.toLowerCase();

String _tidyName(String raw) {
  final name = raw
      // Control characters, which a model occasionally emits and which survive
      // all the way into the database. One world held both "Barnabé" and
      // "Barnab\u0000" — two different characters as far as any comparison
      // goes, and the second impossible to name at a prompt in order to
      // delete it. Stripped here so a name is always something a person could
      // type.
      .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '')
      .trim()
      .replaceAll(RegExp(r'''^["'“]+|["'”]+$'''), '')
      .trim();
  if (name.isEmpty || name.length > _maxNameLength) return '';
  // A "name" holding a sentence's worth of words is a description that lost
  // its separator, not a name.
  if (name.split(RegExp(r'\s+')).length > 5) return '';
  return name;
}

String _tidyDescription(String raw) {
  final description = raw.trim().replaceAll(RegExp(r'[.\s]+$'), '');
  return description.length > 200
      ? '${description.substring(0, 200).trimRight()}…'
      : description;
}
