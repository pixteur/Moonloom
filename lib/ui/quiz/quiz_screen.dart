import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/quiz_question.dart';
import '../../domain/quiz_service.dart';
import '../home/home_screen.dart';

/// One-question-at-a-time onboarding quiz. Collects answers, then submits to
/// [QuizService] (which derives the seed + seeds interests) and updates the
/// child's detail level. See `build-plan/phase-1-profiles-quiz.md`.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.child});

  final ChildProfile child;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  /// Drawn once when the screen opens, so the questions don't reshuffle
  /// under the child between taps.
  final _questions = QuizService.draw();

  final _answers = <String, String>{};
  final _textController = TextEditingController();
  int _index = 0;
  bool _submitting = false;

  /// What this child said last time, by question id.
  ///
  /// The bank draws a different question per dimension each run, so most of
  /// these will not come up again — but when one does, showing the old answer
  /// is the difference between "answer these again" and "has this changed?".
  /// A five-year-old who wanted the dragon and now wants the puzzle has told
  /// you something; a five-year-old answering a blank form has not.
  ///
  /// Never pre-selected, only marked. The point is to notice a change, and an
  /// answer already filled in is an answer nobody reconsiders.
  Map<String, String> _before = const {};

  @override
  void initState() {
    super.initState();
    _loadPrevious();
  }

  Future<void> _loadPrevious() async {
    final last = await ref
        .read(storageRepoProvider)
        .latestQuizResult(widget.child.id);
    if (!mounted || last == null) return;
    setState(() => _before = last.answers);
  }

  QuizQuestion get _q => _questions[_index];
  bool get _isLast => _index == _questions.length - 1;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _captureText() {
    if (_q.type == QuizAnswerType.freeText) {
      final t = _textController.text.trim();
      if (t.isEmpty) {
        _answers.remove(_q.id);
      } else {
        _answers[_q.id] = t;
      }
    }
  }

  void _goTo(int index) {
    setState(() {
      _index = index;
      _textController.text = _answers[_questions[index].id] ?? '';
    });
  }

  void _choose(String value) {
    _answers[_q.id] = value;
    if (_isLast) {
      _finish();
    } else {
      _goTo(_index + 1);
    }
  }

  void _next() {
    _captureText();
    if (_isLast) {
      _finish();
    } else {
      _goTo(_index + 1);
    }
  }

  void _back() {
    _captureText();
    if (_index == 0) {
      Navigator.pop(context);
    } else {
      _goTo(_index - 1);
    }
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final outcome = await ref
        .read(quizServiceProvider)
        .submit(
          childId: widget.child.id,
          answers: _answers,
          parentBrief: widget.child.parentBrief,
        );
    final updated = widget.child.copyWith(detailLevel: outcome.detailLevel);
    await ref.read(profileServiceProvider).update(updated);
    ref.read(activeChildProvider.notifier).select(updated);
    ref.invalidate(profilesProvider);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Getting to know ${widget.child.displayName}'),
        leading: BackButton(onPressed: _submitting ? null : _back),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_index + 1) / _questions.length,
                ),
                const SizedBox(height: 8),
                Text(
                  'Question ${_index + 1} of ${_questions.length}',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 24),
                Text(_q.prompt, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),
                Expanded(child: SingleChildScrollView(child: _answerArea())),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerArea() {
    if (_q.type == QuizAnswerType.choice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in _q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: _submitting ? null : () => _choose(option),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  // Marked, not selected: a chosen-looking button is a button
                  // nobody reconsiders, and reconsidering is the whole point
                  // of asking again.
                  side: _before[_q.id] == option
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(option)),
                    if (_before[_q.id] == option) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_before.containsKey(_q.id))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last time: ${_before[_q.id]}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          autofocus: true,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Type an answer… (you can skip this one)',
            // Shown, not filled in, for the same reason the buttons are only
            // marked: a box already containing last year's answer is a box
            // that gets tapped past.
            helperText: _before.containsKey(_q.id)
                ? 'Last time: ${_before[_q.id]}'
                : null,
            helperMaxLines: 2,
          ),
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting
                  ? null
                  : () {
                      _answers.remove(_q.id);
                      _textController.clear();
                      _next();
                    },
              child: const Text('Skip'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : _next,
              child: Text(_isLast ? 'Finish' : 'Next'),
            ),
          ],
        ),
      ],
    );
  }
}
