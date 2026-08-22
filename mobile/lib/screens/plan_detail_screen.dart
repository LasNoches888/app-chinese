import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../data/study_plans.dart';
import '../services/study_plan_service.dart';
import 'lesson_session_screen.dart';
import 'listening_list_screen.dart';
import 'practice_hub_screen.dart';
import 'pronunciation_check_screen.dart';

/// One plan, step by step.
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

class _PlanDetailScreenState extends State<PlanDetailScreen> {
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
    final progress = _progress;
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: Text('${plan.emoji}  ${plan.titleRu}')),
      body: AppBackground(
        child: progress == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    plan.descriptionRu,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan.paceRu,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${progress.doneCount} / ${progress.steps.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < progress.steps.length; i++)
                    _StepTile(
                      step: progress.steps[i],
                      index: i + 1,
                      isCurrent: identical(
                        progress.steps[i],
                        progress.currentStep,
                      ),
                      settings: settings,
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.green),
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

class _StepTile extends StatelessWidget {
  final StepProgress step;
  final int index;
  final bool isCurrent;
  final AppSettings settings;
  final VoidCallback onTap;

  const _StepTile({
    required this.step,
    required this.index,
    required this.isCurrent,
    required this.settings,
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
                    if (showsCount && !done) ...[
                      const SizedBox(height: 6),
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
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
