import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';
import '../data/dialects.dart';
import '../services/dialect_progress_service.dart';
import 'dialect_culture_screen.dart';
import 'dialect_flashcards_screen.dart';
import 'dialect_practice_screen.dart';

/// The lesson list for one dialect — always "Примеры и фразы" and
/// "Культура", plus a "Мини-диалог" tile only when the dialect actually has
/// a scripted dialogue (today, only Mandarin — see the doc comment on
/// `DialectInfo.dialogue`). Rather than showing a locked, greyed-out tile
/// for the five dialects with no real conversation practice, the tile
/// simply isn't offered — a fake locked feature that will never unlock
/// reads worse than one screen having fewer tiles than another.
class DialectLessonsScreen extends StatefulWidget {
  final String dialectId;

  const DialectLessonsScreen({super.key, required this.dialectId});

  @override
  State<DialectLessonsScreen> createState() => _DialectLessonsScreenState();
}

class _DialectLessonsScreenState extends State<DialectLessonsScreen> {
  Set<DialectLessonKind> _done = {};

  DialectInfo get _dialect => kDialects.firstWhere((d) => d.id == widget.dialectId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final done = await DialectProgressService.doneKinds(widget.dialectId);
    if (!mounted) return;
    setState(() => _done = done);
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final dialect = _dialect;

    return Scaffold(
      appBar: AppBar(title: Text(dialect.nameRu)),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(settings.t('dialectLessonsSubtitle'), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            _LessonTile(
              icon: Icons.chat_bubble_outline_rounded,
              color: dialect.color,
              title: settings.t('dialectLessonExamples'),
              subtitle: '${dialect.examples.length}',
              done: _done.contains(DialectLessonKind.examples),
              onTap: () => _open(DialectFlashcardsScreen(dialectId: dialect.id)),
            ),
            _LessonTile(
              icon: Icons.auto_stories_outlined,
              color: dialect.color,
              title: settings.t('dialectLessonCulture'),
              subtitle: dialect.cultureTitleRu,
              done: _done.contains(DialectLessonKind.culture),
              onTap: () => _open(DialectCultureScreen(dialectId: dialect.id)),
            ),
            if (dialect.dialogue != null)
              _LessonTile(
                icon: Icons.forum_rounded,
                color: dialect.color,
                title: settings.t('dialectLessonPractice'),
                subtitle: '${dialect.dialogue!.length}',
                done: _done.contains(DialectLessonKind.practice),
                onTap: () => _open(DialectPracticeScreen(dialectId: dialect.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  const _LessonTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (done)
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
