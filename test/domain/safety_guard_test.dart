import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/beat.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/story_segment.dart';
import 'package:moonloom/domain/safety_guard.dart';

void main() {
  const guard = SafetyGuard();

  StorySegment seg({
    String text = 'A cozy, gentle tale that ends calm and safe.',
    String summary = 'cozy tale',
    AgeRating rating = AgeRating.tiny,
    List<String> flags = const [],
  }) => StorySegment(
    storyText: text,
    summary: summary,
    rating: rating,
    sensitiveFlags: flags,
  );

  test('passes a calm, in-band segment', () {
    expect(guard.review(seg(), band: AgeBand.tiny).ok, isTrue);
  });

  test('rejects a rating above the band', () {
    final v = guard.review(seg(rating: AgeRating.big), band: AgeBand.tiny);
    expect(v.ok, isFalse);
    expect(v.reasons.join(), contains('exceeds'));
  });

  test('allows a rating below the band', () {
    expect(
      guard.review(seg(rating: AgeRating.tiny), band: AgeBand.big).ok,
      isTrue,
    );
  });

  test('rejects empty story text', () {
    expect(guard.review(seg(text: '   '), band: AgeBand.tiny).ok, isFalse);
  });

  test('rejects a banned theme (whole word, case-insensitive)', () {
    final v = guard.review(
      seg(text: 'They celebrated Christmas with joy.'),
      band: AgeBand.big,
    );
    expect(v.ok, isFalse);
    expect(v.reasons.join(), contains('Christmas'));
  });

  test('does not false-positive on substrings', () {
    // "religion" is banned; "religious" should not whole-word match it, and an
    // unrelated word like "grapes" must never trip a banned term.
    final v = guard.review(
      seg(text: 'We ate grapes in the sunshine.'),
      band: AgeBand.little,
    );
    expect(v.ok, isTrue);
  });

  test('honours a custom banned-themes list', () {
    final v = guard.review(
      seg(text: 'A spooky spider crawled by.'),
      band: AgeBand.big,
      bannedThemes: const ['spider'],
    );
    expect(v.ok, isFalse);
  });

  test('rejects model-flagged sensitive content', () {
    final v = guard.review(seg(flags: ['mild peril']), band: AgeBand.older);
    expect(v.ok, isFalse);
  });
}
