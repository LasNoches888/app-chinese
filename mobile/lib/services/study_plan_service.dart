import '../data/study_plans.dart';
import '../models/user_stats.dart';

/// One step's state within a plan.
class StepProgress {
  final PlanStep step;

  /// How far along this step is, in its own units (decks completed,
  /// words learned, days of streak...).
  final int current;
  final int target;

  const StepProgress({
    required this.step,
    required this.current,
    required this.target,
  });

  bool get isDone => current >= target;

  double get fraction => target == 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

class PlanProgress {
  final StudyPlan plan;
  final List<StepProgress> steps;

  const PlanProgress({required this.plan, required this.steps});

  int get doneCount => steps.where((s) => s.isDone).length;

  bool get isComplete => steps.isNotEmpty && doneCount == steps.length;

  bool get isStarted => steps.any((s) => s.current > 0);

  double get fraction => steps.isEmpty ? 0 : doneCount / steps.length;

  /// The step to point the learner at: the first unfinished one. Null once
  /// the plan is done.
  StepProgress? get currentStep {
    for (final s in steps) {
      if (!s.isDone) return s;
    }
    return null;
  }
}

/// Turns raw progress records into plan/step completion.
///
/// Kept as a pure function of (plan, stats, completed decks, known words)
/// so the rules are testable without a database or a widget tree — the
/// plans screen is otherwise the only place they'd live.
class StudyPlanService {
  static PlanProgress evaluate({
    required StudyPlan plan,
    required UserStats stats,
    required Set<String> completedDeckIds,
    required int knownWordCount,
  }) {
    return PlanProgress(
      plan: plan,
      steps: [
        for (final step in plan.steps)
          StepProgress(
            step: step,
            current: _currentFor(step, stats, completedDeckIds, knownWordCount),
            target: step.target,
          ),
      ],
    );
  }

  static List<PlanProgress> evaluateAll({
    required UserStats stats,
    required Set<String> completedDeckIds,
    required int knownWordCount,
    List<StudyPlan> plans = kStudyPlans,
  }) => [
    for (final plan in plans)
      evaluate(
        plan: plan,
        stats: stats,
        completedDeckIds: completedDeckIds,
        knownWordCount: knownWordCount,
      ),
  ];

  /// The plan worth showing at the top: the one already in progress and
  /// closest to finishing, otherwise the earliest untouched plan. A
  /// finished plan never gets recommended again.
  static PlanProgress? recommended(List<PlanProgress> all) {
    final started = all.where((p) => p.isStarted && !p.isComplete).toList()
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    if (started.isNotEmpty) return started.first;
    for (final p in all) {
      if (!p.isComplete) return p;
    }
    return null;
  }

  static int _currentFor(
    PlanStep step,
    UserStats stats,
    Set<String> completedDeckIds,
    int knownWordCount,
  ) => switch (step.kind) {
    PlanStepKind.deck => completedDeckIds.contains(step.deckId) ? 1 : 0,
    PlanStepKind.words => knownWordCount,
    // The *current* streak, not the record: a plan step asking you to
    // study seven days running shouldn't stay ticked after the streak
    // breaks and you stop showing up.
    PlanStepKind.streak => stats.currentStreak,
    PlanStepKind.dailyChallenge => stats.dailyChallengesCompleted,
    PlanStepKind.perfectLesson => stats.perfectLessonsCount,
    PlanStepKind.listening => stats.listeningCompleted,
    PlanStepKind.pronunciation => stats.pronunciationCompleted,
  };
}
