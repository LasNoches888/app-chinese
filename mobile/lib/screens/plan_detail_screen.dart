import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../data/study_plans.dart';
import '../services/speech_service.dart';
import '../services/study_plan_service.dart';
import 'lesson_session_screen.dart';
import 'listening_list_screen.dart';
import 'practice_hub_screen.dart';
import 'pronunciation_check_screen.dart';

const _brandStart = Color(0xFFFF7A59);
const _brandEnd = Color(0xFF6C5CE7);

/// One plan, laid out as a promise and then a route to it.
///
/// The order is deliberate: what you'll be able to do, three sentences
/// proving it, then the steps. A plan that opens on a checklist reads
/// like homework; the point of a plan is the destination.
///
/// Every step is tappable and lands on the screen that actually advances
/// it — a plan that tells you what to do next but leaves you to find it
/// yourself is just a longer list.
class PlanDetailScreen extends StatefulWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen>
    with StopSpeechOnDispose {
  PlanProgress? _progress;

  StudyPlan get _plan => kStudyPlans.firstWhere((p) => p.id == widget.planId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final stats = await repos.stats.getStats();
    final completed = await repos.srs.getCompletedLessonIds();
    final known = await repos.srs.countLearnedWords();
    if (!mounted) return;
    setState(() {
      _progress = StudyPlanService.evaluate(
        plan: _plan,
        stats: stats,
        completedDeckIds: completed,
        knownWordCount: known,
      );
    });
  }

  Future<void> _startStep(StepProgress step) async {
    final repos = context.read<AppRepositories>();
    final settings = context.read<AppSettings>();

    Widget? destination;
    switch (step.step.kind) {
      case PlanStepKind.deck:
        final deckId = step.step.deckId!;
        final words = await repos.words.getWordsForDeck(deckId);
        final deck = await repos.words.getDeck(deckId);
        if (words.isEmpty || !mounted) return;
        destination = LessonSessionScreen(
          wordIds: words.map((w) => w.id).toList(),
          title: deck?.title ?? settings.t('lessons'),
          deckIdToComplete: deckId,
        );
      case PlanStepKind.listening:
        destination = const ListeningListScreen();
      case PlanStepKind.pronunciation:
        destination = const PronunciationCheckScreen();
      // Streaks, words learned, daily challenges and perfect lessons are
      // all earned across the app rather than at one screen, so these
      // point at the practice hub instead of pretending to be a single
      // exercise.
      case PlanStepKind.words:
      case PlanStepKind.streak:
      case PlanStepKind.dailyChallenge:
      case PlanStepKind.perfectLesson:
        destination = const PracticeHubScreen();
    }

    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination!));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final progress = _progress;
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: Text(plan.titleRu)),
      body: AppBackground(
        child: progress == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _PlanHeader(plan: plan, progress: progress),
                  const SizedBox(height: 22),

                  _SectionTitle(settings.t('planOutcomes')),
                  const SizedBox(height: 8),
                  for (final outcome in plan.outcomesRu)
                    _OutcomeLine(text: outcome),
                  const SizedBox(height: 22),

                  _SectionTitle(settings.t('planSamples')),
                  const SizedBox(height: 8),
                  for (final sample in plan.samples)
                    _SampleCard(sample: sample),
                  const SizedBox(height: 22),

                  _SectionTitle(settings.t('planSteps')),
                  const SizedBox(height: 8),
                  for (var i = 0; i < progress.steps.length; i++)
                    _StepTile(
                      step: progress.steps[i],
                      index: i + 1,
                      isCurrent: identical(
                        progress.steps[i],
                        progress.currentStep,
                      ),
                      onTap: () => _startStep(progress.steps[i]),
                    ),

                  if (progress.isComplete) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/mascot/panda_04.png',
                            height: 110,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.t('planDone'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Emoji, description, pace and the overall bar, on the brand gradient.
class _PlanHeader extends StatelessWidget {
  final StudyPlan plan;
  final PlanProgress progress;

  const _PlanHeader({required this.plan, required this.progress});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final left = progress.steps.length - progress.doneCount;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [_brandStart, _brandEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _brandEnd.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan.titleRu,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.descriptionRu,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  plan.paceRu,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            left == 0
                ? '${progress.steps.length} / ${progress.steps.length}'
                : '${progress.doneCount} / ${progress.steps.length} · '
                      '$left ${settings.t('planStepsLeft')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _OutcomeLine extends StatelessWidget {
  final String text;

  const _OutcomeLine({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline,
            size: 17,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.3),
          ),
        ),
      ],
    ),
  );
}

/// A sentence the plan unlocks, with a speaker button — hearing it is
/// half the point of being shown it.
class _SampleCard extends StatelessWidget {
  final PlanSample sample;

  const _SampleCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sample.hanzi,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sample.pinyin,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(sample.ru, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            SpeakButton(text: sample.hanzi, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final StepProgress step;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  const _StepTile({
    required this.step,
    required this.index,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = step.isDone;
    // Counting steps show how far along they are; a deck step is binary,
    // so a "0/1" would be noise.
    final showsCount = step.target > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrent
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: done ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? Colors.green
                      : theme.colorScheme.surfaceContainerHighest,
                ),
                alignment: Alignment.center,
                child: done
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text(
                        '$index',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.step.titleRu,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? theme.colorScheme.outline : null,
                      ),
                    ),
                    if (!done) ...[
                      const SizedBox(height: 3),
                      Text(
                        step.step.detailRu,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (showsCount && !done) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: step.fraction,
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${step.current} / ${step.target}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (!done)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
