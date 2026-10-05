import 'age_policy.dart';
import 'models/beat.dart';
import 'models/child_profile.dart';
import 'models/series.dart';
import 'models/story_request.dart';
import 'models/story_segment.dart';

/// The assembled prompt handed to an `AiProvider`. The provider only translates
/// this into its wire format (and asks for the structured fields).
class StoryPrompt {
  const StoryPrompt({required this.system, required this.user});

  final String system;
  final String user;
}

/// Turns a [StoryRequest] into a [StoryPrompt]. The ONE place that decides how
/// we prompt — pure and golden-tested. See `docs/architecture.md`, `docs/safety.md`.
class PromptBuilder {
  const PromptBuilder();

  StoryPrompt build(
    StoryRequest req, {
    List<String> bannedThemes = BannedThemes.defaults,
  }) {
    final band = req.child.ageBand;

    final system = StringBuffer()
      ..writeln('You are a warm, imaginative bedtime storyteller for children.')
      ..writeln(AgePolicy.policyFor(band))
      ..writeln('Universal rules:')
      ..writeAll(AgePolicy.universalRules.map((r) => '- $r'), '\n')
      ..writeln()
      ..writeln(
        'Banned themes — never include, even in passing: '
        '${bannedThemes.join(', ')}.',
      )
      ..writeln(_themeGuidance(req.series))
      ..writeln('Write the story in ${_languageName(_baseLanguage(req))}.')
      // A voice reads this text, so markup is not skipped over — it is spoken.
      // Emphasis around a foreign word is the common case: *vélo* comes out as
      // "asterisk vélo asterisk".
      ..writeln(
        'Write "story_text" and "summary" as plain prose. Never use asterisks, '
        'underscores, backticks, brackets, headings, bullet points or any '
        'other formatting — not even to emphasise a word or to mark one that '
        'is in another language. This chapter is read aloud, so anything like '
        'that is spoken to the child character by character.',
      )
      // The rule above cost us the accents. Told to strip formatting and to
      // write symbols out as words, a model reads an acute accent as one more
      // symbol and hands back "les petites etoiles" — which a French voice
      // then mispronounces, because the accent is what tells it how to say
      // the word.
      ..writeln(
        'Accents and other marks inside words are letters, not formatting. '
        'Spell every word the way its own language spells it, accents and '
        'all — é, è, ê, ç, ñ, ü, and so on. They change how a word is '
        'pronounced, so a voice reading the story needs them.',
      )
      ..writeln(
        // The story's own length, as the engine counts chapters by. Reading
        // the child's default here while the engine read the story's would
        // size a week's chapters for a mini whenever the two disagreed.
        'Target length per chapter: '
        '${_lengthFor(req.series.detailLevel ?? req.child.detailLevel)}.',
      )
      ..writeln(
        req.mustConclude
            ? (req.chapterNumber == 1
                  // A mini episode: one sitting, beginning to end. The wording
                  // below would tell the model to wrap up chapters that were
                  // never written, and a model told to conclude a story it has
                  // not begun writes an ending with no middle.
                  ? 'This is a MINI EPISODE: one complete little story told in '
                        'a single sitting, with a beginning, a middle and a '
                        'proper ending. Nothing is left open and there is no '
                        'next chapter. Give it a small, whole shape — one '
                        'problem, one turn, one warm resolution — and end '
                        'peacefully, ready for sleep. Set "is_final" to true.'
                  : 'This is chapter ${req.chapterNumber} and the FINAL chapter '
                        'of the story. Bring everything to a warm, satisfying '
                        'close now, tie off the open threads, end peacefully '
                        'and ready for sleep, and set "is_final" to true.')
            : '${_lengthBrief(req)} Each chapter should end on a gentle, '
                  'calm note.'
                  '${req.mayNotEndYet ? " There are at least "
                            "${req.chaptersRemaining} more to come, so do NOT "
                            "resolve the story here: pace it so the ending has "
                            "somewhere to arrive. Leave the main problem open, "
                            "move it along, and set \"is_final\" to false." : " "
                            "If the story has reached a warm, satisfying "
                            "resolution, set \"is_final\" to true; otherwise "
                            "leave a soft hook for the next chapter and set it "
                            "false."}'
                  ' Always end the FINAL chapter peacefully, ready for sleep.',
      )
      ..writeln(
        'The audience band is "${band.name}". Write strictly within it and set '
        '"rating" to "${band.name}" (never higher).',
      )
      ..writeln(
        'Return: this chapter\'s text, a one-line summary, the rating, the '
        'setting, recurring characters, any open story threads, and is_final '
        '(true on the last chapter).',
      )
      ..writeln(
        'Also return "story_title": a short, warm title for the WHOLE story '
        '(2–6 words, no quotes, no subtitle) drawn from what actually happens '
        'in it — the kind of title a child would recognise on a book spine. '
        'Keep it the same in later chapters of the same story.',
      )
      ..writeln(
        'And return "chapter_title": a title for THIS chapter only (2–5 words, '
        'no quotes, no ending punctuation) naming the one thing that happens '
        'in it. The number is already shown beside it, so this is the part '
        'that comes AFTER it: never "Chapter One", "Chapter 4", "Chapitre 2" '
        'or any numbering, which renders as "Chapter 4 · Chapter 4". Make it '
        'concrete and inviting rather than abstract — "The Lost Mitten", not '
        '"A New Beginning". Never give away the ending, and never reuse an '
        'earlier chapter\'s title.',
      )
      ..writeln(
        'Finally, "narration_style": one line describing the voice this whole '
        'chapter should be read aloud in; and "character_voices": one entry '
        'per speaking character, like "Leo — precise and warm, with a soft '
        'metallic edge". Return "narration_cues" and "dialogue_speakers" as '
        'empty arrays; the editing pass writes those against the finished '
        'prose.',
      );

    final user = StringBuffer();
    if (req.series.autoTitle) {
      user.writeln(
        'This story has no title yet — invent one in "story_title" from what '
        'happens in it.',
      );
    } else {
      user.writeln('Series: "${req.series.title}".');
    }
    user.writeln('Premise: ${req.series.seedSummary}');
    _writeHero(user, req);

    if (req.worldPremise.trim().isNotEmpty) {
      user.writeln(
        'This is a new episode in an ongoing world: ${req.worldPremise.trim()}. '
        'Keep the world, tone, and characters consistent, but tell a fresh, '
        'self-contained adventure.',
      );
    }
    if (req.cast.isNotEmpty) {
      // A HARD CONSTRAINT, not a reminder.
      //
      // "Keep them recognisable" was the old wording, and across one child's
      // library Pip came out a dragon, a star, a fish, a child, an otter, a
      // kitten and a fox. Some of that was an empty cast list — nothing was
      // promoting characters into the world — but the wording invited it too:
      // a model told to keep somebody recognisable will happily decide they
      // are recognisably a penguin this time.
      //
      // These are facts about people who already exist, and the one thing a
      // child notices instantly is a friend turning into a different animal.
      user.writeln(
        'These characters ALREADY EXIST in this world. Their names, species, '
        'appearance and pronouns are fixed facts and must not change — not '
        'for this story, not for any reason. Do not reimagine them, do not '
        'give them a new form, and do not introduce a different character '
        'with the same name:',
      );
      for (final c in req.cast) {
        user.writeln('- $c');
      }
      user.writeln(
        'New characters are welcome, but they must have new names and must '
        'not replace anyone above.',
      );
    }

    _writeCastChanges(user, req);

    if (req.series.storyBible.trim().isNotEmpty) {
      user.writeln('Story so far: ${req.series.storyBible}');
    }

    final loves = req.interests
        .where((i) => i.active)
        .map((i) => i.label)
        .toList();
    if (loves.isNotEmpty) {
      user.writeln('The child currently loves: ${loves.join(', ')}.');
    }

    if (req.recentBeats.isNotEmpty) {
      user.writeln('Recent chapters:');
      for (final b in req.recentBeats) {
        final named = b.title.trim();
        user.writeln('- ${named.isEmpty ? "" : "\"$named\" — "}${b.summary}');
      }
      // Two chapters in a row came back both called "The Whispering Nebula".
      // The rule not to reuse a title was already there; what was missing was
      // the list of titles it must not reuse.
      final used = [
        for (final b in req.recentBeats)
          if (b.title.trim().isNotEmpty) '"${b.title.trim()}"',
      ];
      if (used.isNotEmpty) {
        user.writeln(
          'Chapter titles already used, which this chapter must not repeat or '
          'lightly reword: ${used.join(', ')}.',
        );
      }
    }

    user.writeln(_intentLine(req));

    _writeLanguageMode(user, req);

    return StoryPrompt(
      system: system.toString().trim(),
      user: user.toString().trim(),
    );
  }

  /// The second pass: hand a freshly drafted chapter back to the model as an
  /// editor rather than an author.
  ///
  /// The draft is never shown to the child, so this is not a "would you like
  /// to improve it?" request — it is a copy-edit with a fixed brief. Two
  /// failure modes drive the wording: a model asked to *improve* prose will
  /// rewrite it wholesale and drift off the plot the summary and open threads
  /// already describe, and a model editing for the page will produce sentences
  /// that read well silently but trip a synthetic voice. So the prompt pins
  /// the plot and the length, and treats read-aloud quality as a first-class
  /// goal. See `docs/story-quality.md`.
  StoryPrompt buildRefinement(
    StoryRequest req,
    StorySegment draft, {
    List<String> bannedThemes = BannedThemes.defaults,
  }) {
    final band = req.child.ageBand;
    final words = _wordCount(draft.storyText);
    final low = (words * 0.9).round();
    final high = (words * 1.1).round();
    final language = _languageName(_baseLanguage(req));

    final system = StringBuffer()
      ..writeln(
        'You are an experienced children\'s audiobook writer and story '
        'editor, making a second pass over one chapter of a bedtime story '
        'that has already been drafted. You are not writing a new chapter. '
        'You are turning THIS chapter into a polished narration script.',
      )
      ..writeln()
      ..writeln('Write for this audience, and judge every edit against it:')
      ..writeln(AgePolicy.policyFor(band))
      ..writeln('Universal rules:')
      ..writeAll(AgePolicy.universalRules.map((r) => '- $r'), '\n')
      ..writeln()
      ..writeln('Work in this order of priority:')
      ..writeln()
      ..writeln(
        '1. ERRORS. Grammar, spelling, punctuation, tense, agreement, '
        'broken or half-finished sentences.',
      )
      ..writeln(
        '2. CONTINUITY. Names and their exact spellings, pronouns, ages, '
        'relationships, places, objects, time of day, weather, and '
        'anything established earlier in the story. Where the draft '
        'contradicts the established facts below, the established facts '
        'win. Check the chapter against itself too: a character cannot put '
        'down something they never picked up. Keep every character\'s '
        'species, role and pronouns exactly as the cast list gives them — '
        'a robot is never described as an animal. Keep cause and effect '
        'clear from scene to scene. Cut details introduced and then never '
        'used. Do not re-explain what a listener who has heard the earlier '
        'chapters already knows.',
      )
      ..writeln(
        '3. READ-ALOUD QUALITY. This text will be SPOKEN by a synthetic '
        'voice, never read silently, and that changes what "good" means:',
      )
      ..writeln(
        '   - Every sentence must be speakable in one comfortable breath, '
        'or carry punctuation where the voice should breathe. Break up '
        'sentences past about 25 words.',
      )
      ..writeln(
        '   - Remove tongue-twisters, accidental rhyme, unintended '
        'alliteration pile-ups, and clusters of hissing s-sounds.',
      )
      ..writeln(
        '   - Prefer words a speech engine pronounces reliably. Avoid '
        'invented spellings, unusual proper nouns, and words whose stress '
        'is ambiguous in $language.',
      )
      ..writeln(
        '   - Strip anything that only works on the page: parentheses, '
        'asterisks, emoji, ALL-CAPS, bullet points, headings, stage '
        'directions, footnotes, tables. Write numbers, dates, symbols and '
        'abbreviations out as words.',
      )
      ..writeln(
        '   - Use no em dashes and no semicolons. A speech engine reads '
        'them as an abrupt stop or ignores them entirely, so recast those '
        'sentences with a comma, a full stop, or two sentences.',
      )
      ..writeln(
        '   - Make it obvious who is speaking from the words themselves, '
        'so the narration works without seeing the punctuation, and never '
        'lean on italics or formatting to carry emphasis.',
      )
      ..writeln(
        '4. PROSE. Trade abstraction for concrete, child-scale sensory '
        'detail — what a thing looked, sounded, smelled and felt like. Cut '
        'throat-clearing openings, redundant adverbs, doubled adjectives, '
        'and the reflexes "suddenly", "very", "really", "began to", '
        '"started to". Prefer a strong verb to an adverb propping up a '
        'weak one. Vary sentence length on purpose: a short sentence after '
        'two long ones lands. Show a feeling in behaviour first, then name '
        'it once, plainly. Keep at most one or two stretch words a child '
        'might not know, each recoverable from context. In dialogue, let '
        'the line carry the tone and trim the tags back to "said" and '
        '"asked".',
      )
      ..writeln(
        '5. REPETITION IS OFTEN THE POINT. A returning phrase, a refrain, '
        'a rule of three — these are craft in children\'s writing. Keep '
        'them and sharpen them. Only remove repetition that looks '
        'accidental: the same word or image reused within a few sentences '
        'to no effect.',
      )
      ..writeln(
        '6. BEDTIME FUNCTION. The chapter has to settle a child, not wind '
        'one up. Open with a line that invites a listener in and makes '
        'them curious. Let the characters get through their problem by '
        'noticing things, being kind, working together and being '
        'inventive. Keep any suspense mild, brief and reassuring, and keep '
        'the whole chapter emotionally safe. Then let the energy fall '
        'toward the end: slow the pace, and close on a calm, comforting '
        'image rather than an abrupt cliffhanger. Ease the closing lines '
        'down without changing what actually happens.',
      )
      ..writeln()
      ..writeln(
        'HARD CONSTRAINTS. Breaking any of these makes the result '
        'unusable:',
      )
      ..writeln(
        '- LENGTH: the draft is $words words. Return between $low and '
        '$high words. Do not compress it into a summary and do not pad it.',
      )
      // Buried in the "strip anything that only works on the page" list, this
      // read as one more thing to remove, and the accents kept disappearing.
      // A rule about keeping something has to sit where the model is looking
      // for things it must not touch.
      ..writeln(
        '- KEEP EVERY ACCENT. Accented letters are spelling — not formatting, '
        'not symbols: é, è, ê, ë, à, â, ç, ô, û, ù, î, ï, ñ, ü. Never replace '
        'one with its unaccented letter. They tell the voice how to say the '
        'word, so "etoiles" for "étoiles" is a mispronunciation, and a '
        'chapter that comes back stripped of them is unusable.',
      )
      ..writeln(
        '- DO NOT CHANGE WHAT HAPPENS. No new named characters, no new '
        'places, no new or removed events. Same opening situation, same '
        'closing situation. Another chapter has already been planned '
        'around this one\'s ending.',
      )
      ..writeln(
        '- "is_final" stays ${draft.isFinal}. Do not resolve a story that '
        'was left open, and do not reopen one that was closed.',
      )
      ..writeln(_refinementLanguageRule(req, language))
      ..writeln(
        '- Keep the audience band "${band.name}" and return "rating" as '
        '"${band.name}".',
      )
      ..writeln(
        '- These themes must remain entirely absent: '
        '${bannedThemes.join(', ')}.',
      )
      ..writeln(
        '- Never bolt a moral onto the end. If the draft states its lesson '
        'outright, cut the statement and let the story carry it.',
      )
      ..writeln()
      ..writeln(
        'A LIGHT PASS IS A SUCCESS. If the draft is already good, change '
        'only what genuinely warrants changing and return the rest '
        'untouched. Do not rewrite to show effort, and do not flatten a '
        'voice that is already working.',
      )
      ..writeln()
      ..writeln(
        'KEEP THE PARAGRAPHS. Separate every paragraph in "story_text" '
        'with a blank line, and return about as many paragraphs as the '
        'draft has. The reader speaks one paragraph at a time and matches '
        'the narration cues to them in order, so a chapter returned as one '
        'unbroken block cannot be read aloud at all.',
      )
      ..writeln()
      ..writeln(
        'Return the complete refined chapter in "story_text" — the whole '
        'thing, not a diff or a note. Return "summary", "characters" and '
        '"open_threads" unchanged unless your edits made them inaccurate. '
        'Keep "story_title" and "chapter_title" as they are unless they '
        'misname what actually happens. The one thing to fix even when '
        'passing them through: strip any asterisks, underscores or other '
        'formatting out of them, including emphasis around a word in '
        'another language — those are read out character by character. '
        'Accents within a word stay; they are spelling, not emphasis.',
      )
      // The drafting model keeps returning "Chapter One" for early chapters,
      // where it has not yet decided what the chapter is about. The editor has
      // the finished prose in front of it and is the right one to name it, but
      // "keep it unless it misnames what happens" reads as "keep it".
      ..writeln(
        'One exception to keeping it: if "chapter_title" is empty, or is only '
        'a number — "Chapter One", "Chapter 4", "Chapitre 2" — then it is not '
        'a title at all. Replace it with a real one: 2–5 words naming the one '
        'thing that happens in this chapter, with no number in it, since the '
        'number is already shown beside it.',
      )
      ..writeln()
      ..writeln('DIRECTION FOR THE NARRATOR.')
      ..writeln(
        'A voice model reads this chapter aloud, so also write its '
        'direction. None of it goes in "story_text" — that text is printed '
        'on screen and exported, and a voice engine handed markup it does '
        'not recognise reads the markup out loud.',
      )
      ..writeln(
        '- "narration_style": one line for the whole chapter, e.g. '
        '"unhurried and close, like a parent at the bedside".',
      )
      ..writeln(
        '- "character_voices": one line per speaking character saying how '
        'the SAME narrator should colour their voice, e.g. "Leo — precise '
        'and warm, with a soft metallic edge". One reader plays everyone; '
        'never ask for a different actor, and keep the shifts small enough '
        'not to jolt a child who is settling.',
      )
      ..writeln(
        '- "narration_cues": exactly one entry per paragraph of your '
        'refined chapter, in order. Count your paragraphs and return that '
        'many entries. Each entry is plain "key=value" pairs separated by '
        'semicolons, using only these keys: pace, emotion, volume, note. '
        'For example: "pace=slow; emotion=wistful; volume=hushed; '
        'note=linger on the last line". Leave a paragraph\'s entry as an '
        'empty string when it should simply be read plainly — most of a '
        'story should be.',
      )
      ..writeln(
        '- "dialogue_speakers": exactly one entry per paragraph, in the same '
        'order as "narration_cues". Each entry names who speaks each quoted '
        'line in that paragraph, in the order the quotes appear, separated by '
        'commas — for example "Pip, Barnaby" for a paragraph where Pip speaks '
        "first and Barnaby answers. Use each character's name exactly as it "
        'appears in "character_voices". Leave the entry empty when the '
        'paragraph has no dialogue. Count the quotes: one name per quoted '
        'line, no more and no fewer.',
      )
      ..writeln(
        'Describe the SOUND in ordinary words. Never emit SSML, audio '
        'tags, square brackets, angle brackets, timings, or any engine\'s '
        'markup — different engines take different formats and this '
        'direction is translated for each of them.',
      )
      ..writeln(
        'This is a bedtime story: even the liveliest cue stays gentle, and '
        'the cues should quieten and slow as the chapter ends.',
      );

    final user = StringBuffer()
      ..writeln('Established facts this chapter must respect:');
    if (req.series.title.trim().isNotEmpty && !req.series.autoTitle) {
      user.writeln('- Story title: "${req.series.title}"');
    }
    // The editor is told that established facts beat the draft, so the hero's
    // name belongs among them — otherwise a polish pass is free to rename the
    // lead the drafting pass was just told to use.
    final hero = _heroFact(req);
    if (hero.isNotEmpty) user.writeln('- $hero');
    if (req.worldPremise.trim().isNotEmpty) {
      user.writeln('- World: ${req.worldPremise.trim()}');
    }
    for (final c in req.cast) {
      user.writeln('- Cast: $c');
    }
    if (req.series.storyBible.trim().isNotEmpty) {
      user.writeln('- Story so far: ${req.series.storyBible.trim()}');
    }
    for (final b in req.recentBeats) {
      user.writeln('- Earlier chapter: ${b.summary}');
    }
    user
      ..writeln()
      ..writeln(
        'This is chapter ${req.chapterNumber}'
        '${draft.isFinal ? ', the final chapter' : ''}.',
      )
      ..writeln()
      ..writeln('--- DRAFT CHAPTER TO REFINE ---')
      ..writeln(draft.storyText.trim())
      ..writeln('--- END OF DRAFT ---');

    return StoryPrompt(
      system: system.toString().trim(),
      user: user.toString().trim(),
    );
  }

  static int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// The language this story is told in — the series' own where it has one,
  /// else the child's. A bilingual household can have one child with stories
  /// in both of their languages.
  String _baseLanguage(StoryRequest req) =>
      languageFor(req.series, req.child.language);

  /// What the second pass may do to the language of a chapter.
  ///
  /// This line used to read "Stay in $language. Do not translate any part of
  /// it." unconditionally — which quietly undid bilingual mode. The drafting
  /// pass would write half the chapter in Spanish exactly as asked, and the
  /// editor, told to stay in English, would hand back a chapter with the
  /// Spanish translated away. The story arrived in one language and the
  /// setting looked broken when it was working.
  String _refinementLanguageRule(StoryRequest req, String language) {
    final second = req.series.secondaryLanguage;
    if (!req.series.bilingualEnabled || second == null) {
      return '- Stay in $language. Do not translate any part of it.';
    }
    final other = _languageName(second);
    return '- This chapter is deliberately bilingual: $language and $other. '
        'Keep every $other word and passage in $other. Do not translate them, '
        'do not replace them with $language, and do not add a translation '
        'after them. Preserve the balance the draft already has — correct '
        'errors within each language, and leave the switches where they are.';
  }

  /// How much of a second language to weave in, and how.
  ///
  /// Each level is a different teaching contract, not the same instruction at
  /// three volumes, so they get genuinely different briefs. Two rules run
  /// through all of them: the meaning must be carried by the story rather than
  /// by a translation, and nothing may appear that only works on the page.
  /// This text is read aloud, so a bracketed gloss or a language tag is not
  /// skipped — it is spoken.
  void _writeLanguageMode(StringBuffer user, StoryRequest req) {
    final second = req.series.secondaryLanguage;
    if (!req.series.bilingualEnabled || second == null) return;
    final main = _languageName(_baseLanguage(req));
    final other = _languageName(second);

    switch (req.series.bilingualBlend ?? BilingualBlend.sprinkle) {
      case BilingualBlend.sprinkle:
        user.writeln(
          'Bilingual mode — a few words. Tell the story in $main and fold in '
          'about five to eight $other words in total, no more. Choose concrete '
          'things a child can picture — animals, food, colours, family, '
          'greetings — and make each meaning obvious from the sentence around '
          'it, either by naming the thing in $main immediately afterwards or '
          'by letting the action show it. Reuse that same handful of words '
          'several times through the chapter instead of introducing new ones; '
          'the repetition is what makes them stick.',
        );
      case BilingualBlend.phrases:
        user.writeln(
          'Bilingual mode — phrases. Tell the story in $main and let whole '
          'short $other phrases land where they naturally belong: a greeting, '
          'an exclamation, a line of dialogue from someone who speaks it. Keep '
          'each phrase short, and let what happens next make its meaning plain '
          'so nothing needs translating.',
        );
      case BilingualBlend.alternating:
        // Told to switch "where the story gives you a reason to — crossing
        // into somewhere the other language is spoken", a model invents a
        // border: a French-speaking sector of the lake, a sign at a trench,
        // turtles who only speak French. That is a translated story with a
        // customs post in the middle, not a bilingual one. In a bilingual
        // house nobody crosses anything; the language moves with the feeling
        // and nobody remarks on it.
        user.writeln(
          'Bilingual mode — the way a bilingual family actually talks. Roughly '
          'half this chapter is in $main and half in $other, mixed all the way '
          'through rather than split into two halves. The switching is a way '
          'of telling the story, not an event in it.',
        );
        user.writeln(
          'Nobody ever crosses into "the $other part" of anywhere. Do not '
          'invent a place, a border, a sign, or a character who only speaks '
          '$other as an excuse to change language. Nobody comments on the '
          'change, translates for anyone, or is congratulated for it. It is '
          'simply how these people talk.',
        );
        user.writeln(
          'Switch the way people really do: a character who thinks in one '
          'language and jokes in the other; comfort, counting and pet names in '
          'the one someone grew up with; an exclamation that only comes out '
          'right in $other; a question asked in $main and answered in $other '
          'with nobody noticing; a phrase repeated in both because the speaker '
          'is excited. Switch between sentences, and inside a sentence where '
          'that is how it would really fall. Never alternate paragraph by '
          'paragraph — that is a drill, not a family.',
        );
        user.writeln(
          'Both languages must carry real events. Do not leave $other holding '
          'only greetings and scenery while $main does the plot.',
        );
        // First attempt at this put every French word inside quotation marks:
        // the characters were bilingual and the narrator was not, which caps
        // the second language at whatever share the dialogue happens to be —
        // it came out at 29%, not half.
        user.writeln(
          'The narration switches too, not only the dialogue. Describe what '
          'happens, what a place looks like and what someone is feeling in '
          '$other as readily as in $main. If every $other word in this chapter '
          'sits inside quotation marks, it is not half and half — go back and '
          'tell some of the story itself in $other.',
        );
        user.writeln(
          'Count as you finish: roughly half the sentences should be $other. '
          'If one language is carrying most of them, rewrite some of the '
          'narration in the other before you return the chapter.',
        );
        user.writeln(
          'A child who understands only $main must still follow every event. '
          'Carry the meaning with the action itself, a reply that answers what '
          'was asked, or a phrase already established earlier — never with a '
          'translation. If a $other line matters to the plot, let what happens '
          'next make it plain.',
        );
    }

    user.writeln(
      'Write both languages as ordinary prose in "story_text". Never add a '
      'translation in brackets, a glossary, a language label, or any other '
      'note to the reader — this chapter is read aloud, so anything like that '
      'is spoken to the child word for word.',
    );
  }

  /// Arrivals and departures the grown-up made in the world's cast since the
  /// last story. A removed character must be *written out*, warmly and on the
  /// page — never silently dropped, and never in a way that upsets a child at
  /// bedtime. See `docs/safety.md`.
  void _writeCastChanges(StringBuffer user, StoryRequest req) {
    final changes = req.castChanges;
    if (changes.isEmpty) return;

    if (changes.joined.isNotEmpty) {
      user.writeln(
        'New to this world — introduce them naturally in this chapter with a '
        'warm first meeting, then treat them as part of the group:',
      );
      for (final c in changes.joined) {
        user.writeln('- $c');
      }
    }
    if (changes.left.isNotEmpty) {
      user.writeln(
        'Leaving the story — give each of them a proper send-off in this '
        'chapter, then never mention them again in later chapters:',
      );
      for (final c in changes.left) {
        user.writeln('- $c');
      }
      user.writeln(
        'Make the farewell gentle, hopeful, and interesting: they set off on '
        'an adventure of their own, are called home, sail away to somewhere '
        'wonderful, or go where they are needed. Let the others say a proper '
        'goodbye and feel glad for them. Absolutely never use illness, death, '
        'danger, punishment, an argument, or an unexplained disappearance, and '
        'never make it frightening or sad. Leave the door open for a happy '
        'letter or visit someday.',
      );
    }
  }

  /// Who the story is about.
  ///
  /// The creator has always asked this — "The child", "A named hero", or a
  /// surprise — and the answer has always been saved on the series. It was
  /// never put in the prompt, so a parent who typed "Crystal" got whoever the
  /// model felt like inventing, and no amount of asking again would change it.
  ///
  /// It is written after the premise and before the cast on purpose. An
  /// episode inherits its world's recurring characters, and a model handed a
  /// familiar cast will quietly keep using the hero it already knows — which
  /// is how one invented fox became the lead of every story in a world. The
  /// named hero is therefore stated as the lead *and* the cast list below is
  /// framed as the supporting characters.
  void _writeHero(StringBuffer user, StoryRequest req) {
    final name = req.series.heroName?.trim() ?? '';
    switch (req.series.heroMode) {
      case HeroMode.namedHero when name.isNotEmpty:
        user.writeln(
          'The hero of this story is named $name. This is not a suggestion: '
          '$name is the lead, appears in the first few sentences, and is '
          'called $name throughout — never renamed, never a nickname, never '
          'replaced by another character. Spell it exactly "$name". Anyone '
          'else in the story, including any recurring character listed below, '
          'is part of the supporting cast.',
        );
      case HeroMode.childAsHero:
        final child = req.child.displayName.trim();
        if (child.isEmpty) return;
        user.writeln(
          'The hero of this story is the child listening: $child, aged '
          '${req.child.age}. Write $child as the lead, by that name, and give '
          'them the choices that move the story. Anyone else, including any '
          'recurring character listed below, is part of the supporting cast.',
        );
      case HeroMode.namedHero:
      case HeroMode.surprise:
        // No steer: inventing the lead is the point of "Surprise", and a
        // named hero with a blank name is the same situation.
        return;
    }
  }

  /// The hero as a one-line fact, for the editor's continuity list.
  String _heroFact(StoryRequest req) {
    final name = req.series.heroName?.trim() ?? '';
    return switch (req.series.heroMode) {
      HeroMode.namedHero when name.isNotEmpty =>
        'Hero: $name — the lead of this story, spelled exactly that way. '
            'Never rename or replace them.',
      HeroMode.childAsHero when req.child.displayName.trim().isNotEmpty =>
        'Hero: ${req.child.displayName.trim()} — the lead of this story. '
            'Never rename or replace them.',
      _ => '',
    };
  }

  /// How many chapters this story owes, and why.
  ///
  /// A long story is exactly seven — one for each night of the week — so its
  /// floor and ceiling are the same number, and "across 7–7 short chapters"
  /// reads like a typo rather than an instruction. Worth saying properly,
  /// because the reason is itself useful to the model: a story that must land
  /// on chapter seven can be paced for seven, where a range invites the
  /// shortest thing that satisfies it.
  String _lengthBrief(StoryRequest req) {
    if (req.minChapters == req.maxChapters) {
      return 'Tell ONE complete bedtime story in exactly ${req.maxChapters} '
          'short chapters — one for each night of the week. Pace it for that: '
          'there is room to let things breathe, and the ending must arrive on '
          'chapter ${req.maxChapters}, neither before nor after. This is '
          'chapter ${req.chapterNumber} of ${req.maxChapters}.';
    }
    return 'Tell ONE complete bedtime story across '
        '${req.minChapters}–${req.maxChapters} short chapters. This is '
        'chapter ${req.chapterNumber} of at least ${req.minChapters}.';
  }

  String _intentLine(StoryRequest req) {
    final twist = req.chosenTwist;
    return switch (req.intent) {
      StoryIntent.continued =>
        'Continue the story naturally from where it left off.',
      StoryIntent.dice when twist != null =>
        'Begin a fresh twist for tonight: $twist',
      StoryIntent.option when twist != null => 'Tonight\'s direction: $twist',
      StoryIntent.request when twist != null =>
        'The child asked for a story about: «$twist». Honour the spirit of '
            'this within all the safety rules above.',
      _ => 'Start a gentle new chapter for tonight.',
    };
  }

  String _themeGuidance(Series s) {
    if (s.theme == StoryTheme.custom && (s.customTheme?.isNotEmpty ?? false)) {
      return 'Series flavour (custom): ${s.customTheme}.';
    }
    final phrases = s.allThemes.map(_themePhrase).toList();
    if (phrases.length == 1) {
      return 'Series flavour: lean into ${phrases.single}.';
    }
    return 'Series flavour: blend these into one story — '
        '${phrases.join('; ')}. Lead with the first and let the others colour '
        'it, rather than telling separate stories.';
  }

  String _themePhrase(StoryTheme theme) {
    return switch (theme) {
      StoryTheme.adventure =>
        'quests, exploration, and brave-but-cozy excitement',
      StoryTheme.technical =>
        'how things work — machines, building, simple engineering ideas',
      StoryTheme.nature =>
        'animals, ecosystems, the outdoors, and gentle wonder',
      StoryTheme.documentary =>
        'a friendly narrator explaining real, accurate facts',
      StoryTheme.learning => 'teaching a small concept through the story',
      StoryTheme.cozy => 'slow, soft, sleepy, low-stakes comfort',
      StoryTheme.feelings => 'empathy, big feelings, kindness, and sharing',
      StoryTheme.mystery =>
        'gentle, age-appropriate puzzle-solving (never scary)',
      StoryTheme.silly => 'pure comedy, wordplay, and giggles',
      StoryTheme.fairytale => 'classic "once upon a time" storybook cadence',
      StoryTheme.history => 'a friendly visit to the past',
      StoryTheme.aroundTheWorld =>
        'cultures, geography, and food around the world',
      StoryTheme.superhero =>
        'everyday-hero acts of helping and courage (not combat)',
      StoryTheme.mindfulness => 'breathing, gratitude, and calm imagery',
      StoryTheme.sliceOfLife => 'warm everyday moments and gentle routines',
      StoryTheme.surprise =>
        'any delightful, age-appropriate flavour you choose',
      StoryTheme.custom => 'a delightful, age-appropriate flavour',
    };
  }

  String _lengthFor(DetailLevel level) => switch (level) {
    DetailLevel.short =>
      'a whole little story in one sitting (about 250–350 words)',
    DetailLevel.medium => 'a medium story (about 300–450 words)',
    DetailLevel.long => 'a longer chapter (about 500–700 words)',
  };

  String _languageName(String code) => switch (code) {
    'en' => 'English',
    'fr' => 'French',
    'es' => 'Spanish',
    'ja' => 'Japanese',
    _ => code,
  };
}
