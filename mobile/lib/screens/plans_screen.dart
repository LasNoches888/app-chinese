import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/app_bar_actions.dart';
import '../services/study_plan_service.dart';
import 'plan_detail_screen.dart';

const _brandStart = Color(0xFFFF7A59);
const _brandEnd = Color(0xFF6C5CE7);

/// Goal-shaped routes through the material.
///
/// The deck list answers "what is there"; this answers "what should I do
/// next, and where does it get me" — the thing self-study plans exist to
/// provide. Progress is read off what the learner has actually done, so
/// there's nothing to tick manually and nothing that can drift out of
/// sync with reality.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<PlanProgress>? _plans;

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
      _plans = StudyPlanService.evaluateAll(
        stats: stats,
        completedDeckIds: completed,
        knownWordCount: known,
      );
    });
  }

  Future<void> _open(PlanProgress progress) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailScreen(planId: progress.plan.id),
      ),
    );
    // Coming back from a plan's exercises, the numbers have moved.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final plans = _plans;
    final recommended = plans == null
        ? null
        : StudyPlanService.recommended(plans);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('plansTitle')),
        actions: const [AppBarActions()],
      ),
      body: AppBackground(
        child: plans == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (recommended != null) ...[
                      _RecommendedCard(
                        progress: recommended,
                        settings: settings,
                        onTap: () => _open(recommended),
                      ),
                      const SizedBox(height: 22),
                    ],
                    for (final stage in [1, 2, 3]) ...[
                      if (plans.any((p) => p.plan.stage == stage)) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Text(
                            settings.t('planStage$stage'),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        for (final p in plans.where(
                          (p) => p.plan.stage == stage,
                        ))
                          _PlanCard(
                            progress: p,
                            settings: settings,
                            onTap: () => _open(p),
                          ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// The "do this next" card — a plan list where everything looks equally
/// available is just another menu.
class _RecommendedCard extends StatelessWidget {
  final PlanProgress progress;
  final AppSettings settings;
  final VoidCallback onTap;

  const _RecommendedCard({
    required this.progress,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final step = progress.currentStep;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
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
              color: _brandEnd.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.t('planContinue'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(progress.plan.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.plan.titleRu,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (step != null) ...[
              const SizedBox(height: 10),
              Text(
                '${settings.t('planNextStep')}: ${step.step.titleRu}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 14,
                ),
              ),
            ],
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
              '${progress.doneCount} / ${progress.steps.length} · ${progress.plan.paceRu}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanProgress progress;
  final AppSettings settings;
  final VoidCallback onTap;

  const _PlanCard({
    required this.progress,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = progress.currentStep;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress.fraction,
                      strokeWidth: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                    Text(
                      progress.plan.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            progress.plan.titleRu,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (progress.isComplete)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress.plan.descriptionRu,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.doneCount}/${progress.steps.length} · ${progress.plan.paceRu}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Naming the next step turns a list of topics into a
                    // list of things to actually go and do.
                    if (step != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${settings.t('planNextStep')}: ${step.step.titleRu}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
