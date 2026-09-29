import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonloom/domain/models/child_profile.dart';
import 'package:moonloom/domain/models/interest.dart';
import 'package:moonloom/domain/models/quiz_question.dart';
import 'package:moonloom/domain/quiz_bank.dart';
import 'package:moonloom/domain/quiz_service.dart';

import '../support/in_memory_storage_repo.dart';

void main() {
  group('the question bank', () {
    test('covers every dimension the seed reads', () {
      for (final dimension in QuizDimension.values) {
        expect(
          quizBank[dimension],
          isNotEmpty,
          reason: 'no question asks about ${dimension.name}',
        );
      }
    });

    test('every choice says what picking it means', () {
      for (final questions in quizBank.values) {
        for (final q in questions) {
          if (q.type != QuizAnswerType.choice) continue;
          expect(q.choices, isNotEmpty, reason: '${q.id} has no choices');
          for (final c in q.choices) {
            expect(c.trait.trim(), isNotEmpty, reason: '${q.id}: ${c.label}');
          }
        }
      }
    });

    test('no question offers one obviously best answer', () {
      // The first quiz asked "Dragon, Puppy, Robot, Something else" and every
      // child picked the dragon, so the answer told us nothing about any of
      // them. A fork only reveals a preference when both sides are wanted, so
      // no option may name a creature or a treasure — the magnets.
      final magnets = RegExp(
        r'\b(dragon|unicorn|treasure|magic|superhero|puppy|kitten)\b',
        caseSensitive: false,
      );
      for (final questions in quizBank.values) {
        for (final q in questions) {
          for (final c in q.choices) {
            expect(
              magnets.hasMatch(c.label),
              isFalse,
              reason: '${q.id} offers "${c.label}", which wins by default',
            );
          }
        }
      }
    });

    test('a draw asks one question per dimension, in a settled order', () {
      final drawn = drawQuiz(Random(1));
      expect(drawn.map((q) => q.dimension), quizOrder);
      // Ends on the calm one rather than a jolt.
      expect(drawn.last.dimension, QuizDimension.length);
    });

    test('two children are asked differently', () {
      // Not a guarantee for any single pair, but across many draws the set of
      // questions asked has to vary, or the randomness is decorative.
      final seen = <String>{};
      for (var i = 0; i < 40; i++) {
        seen.add(drawQuiz(Random(i)).map((q) => q.id).join(','));
      }
      expect(seen.length, greaterThan(5));
    });
  });

  group('deriveSeed (pure)', () {
    test('describes the child, not the story', () {
      final seed = QuizService.deriveSeed({
        'curiosity_box': 'The locked box',
        'company_role': 'Notice things',
        'humour_kind': 'The joke',
        'intensity_known': 'Be surprised',
        'fascination_hour': 'volcanoes',
        'comfort_weather': 'Rain',
        'avoid_bedtime': 'spiders',
      });
      expect(seed, contains('puzzle'));
      expect(seed, contains('observant'));
      expect(seed, contains('wordplay'));
      expect(seed, contains('volcanoes'));
      expect(seed, contains('rain'));
      expect(seed, contains('Gently avoid: spiders'));
    });

    test('reads the dimension, whichever question was drawn', () {
      // Two different questions about curiosity; both mean "likes exploring",
      // and the premise must not depend on which one came up.
      final a = QuizService.deriveSeed({'curiosity_box': 'The new path'});
      final b = QuizService.deriveSeed({'curiosity_first': 'Touch first'});
      expect(a, contains('exploring'));
      expect(b, contains('hands first'));
    });

    test('is graceful when answers are sparse', () {
      final seed = QuizService.deriveSeed(const {});
      expect(seed, isNotEmpty);
      expect(seed, contains('bedtime story'));
    });

    test('weaves in the parent brief', () {
      final seed = QuizService.deriveSeed(const {}, parentBrief: 'family day');
      expect(seed, contains('family day'));
    });

    test('an unanswered question contributes nothing', () {
      final seed = QuizService.deriveSeed({'curiosity_box': '   '});
      expect(seed, 'A gentle bedtime story.');
    });
  });

  group('detailLevelFor', () {
    test('maps the length answer', () {
      expect(
        QuizService.detailLevelFor({'length': 'Short'}),
        DetailLevel.short,
      );
      expect(QuizService.detailLevelFor({'length': 'Long'}), DetailLevel.long);
      expect(QuizService.detailLevelFor(const {}), DetailLevel.medium);
    });
  });

  group('submit', () {
    test('persists the result and seeds interests', () async {
      final repo = InMemoryStorageRepo();
      final service = QuizService(repo);

      final outcome = await service.submit(
        childId: 'c1',
        answers: {
          'fascination_hour': 'fractals',
          'fascination_best': 'a fossil',
          'length': 'Long',
        },
      );

      expect(outcome.detailLevel, DetailLevel.long);
      expect(await repo.latestQuizResult('c1'), isNotNull);

      final interests = await repo.loadInterests('c1');
      final labels = interests.map((i) => i.label).toSet();
      expect(labels, containsAll(['fractals', 'a fossil']));
      expect(interests.every((i) => i.source == InterestSource.quiz), isTrue);
    });
  });
}
