import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/speak_button.dart';
import '../data/dialects.dart';
import '../services/dialect_progress_service.dart';
import 'dialect_complete_screen.dart';

/// Self-rated flashcard loop over one dialect's example phrases.
///
/// Deliberately the lighter "did you know this / knew it" pattern rather
/// than the full `ExerciseGenerator` pipeline the HSK lessons use: that
/// pipeline is built around the SRS word bank, and this content lives
/// outside it by design (see `data/dialects.dart`) — self-rating is
/// honest about what this screen actually is, a quick review, not a
/// graded exercise.
class DialectFlashcardsScreen extends StatefulWidget {
  final String dialectId;

  const DialectFlashcardsScreen({super.key, required this.dialectId});

  @override
  State<DialectFlashcardsScreen> createState() => _DialectFlashcardsScreenState();
}

class _DialectFlashcardsScreenState extends State<DialectFlashcardsScreen> {
  int _index = 0;

  DialectInfo get _dialect => kDialects.firstWhere((d) => d.id == widget.dialectId);

  Future<void> _advance() async {
    final dialect = _dialect;
    if (_index + 1 < dialect.examples.length) {
      setState(() => _index++);
      return;
    }
    await DialectProgressService.markDone(dialect.id, DialectLessonKind.examples);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DialectCompleteScreen(
          dialectId: dialect.id,
          phrasesCovered: dialect.examples.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final dialect = _dialect;
    final example = dialect.examples[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(dialect.nameRu),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_index + 1) / dialect.examples.length,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(dialect.color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_index + 1} / ${dialect.examples.length}',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          example.hanzi,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                        ),
                        if (dialect.hasAudio) ...[
                          const SizedBox(width: 8),
                          SpeakButton(text: example.hanzi, size: 26),
                        ],
                      ],
                    ),
                    if (example.reading != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        example.reading!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      example.ru,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _advance,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(settings.t('dialectDidntKnow')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: dialect.color),
                      onPressed: _advance,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(settings.t('dialectKnew')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
