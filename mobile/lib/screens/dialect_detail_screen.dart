import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../data/dialects.dart';
import 'dialect_culture_screen.dart';
import 'dialect_lessons_screen.dart';

/// What a dialect is, in broad strokes, and a way into its lessons.
///
/// Ordered like `plan_detail_screen.dart`: the header names it, features
/// say what makes it distinct, examples make that concrete, and the
/// culture teaser and study button are what to actually do next.
class DialectDetailScreen extends StatelessWidget {
  final String dialectId;

  const DialectDetailScreen({super.key, required this.dialectId});

  DialectInfo get _dialect => kDialects.firstWhere((d) => d.id == dialectId);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final dialect = _dialect;

    return Scaffold(
      appBar: AppBar(title: Text(dialect.nameRu)),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _DialectHeader(dialect: dialect),
            const SizedBox(height: 22),

            _SectionTitle(settings.t('dialectFeatures')),
            const SizedBox(height: 8),
            for (final f in dialect.featuresRu) _FeatureLine(text: f),
            const SizedBox(height: 22),

            _SectionTitle(settings.t('dialectExamples')),
            const SizedBox(height: 8),
            for (final e in dialect.examples)
              _ExampleCard(example: e, hasAudio: dialect.hasAudio),
            const SizedBox(height: 14),

            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DialectCultureScreen(dialectId: dialect.id),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: dialect.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.auto_stories_rounded, color: dialect.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        settings.t('dialectCultureTeaser'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: dialect.color),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DialectLessonsScreen(dialectId: dialect.id),
                  ),
                ),
                child: Text(settings.t('dialectStudyButton')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialectHeader extends StatelessWidget {
  final DialectInfo dialect;

  const _DialectHeader({required this.dialect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dialect.color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: dialect.color.withValues(alpha: 0.32),
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
              Expanded(
                child: Text(
                  dialect.nameRu,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${dialect.nativeName} · ${dialect.romanization}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dialect.regionRu,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            dialect.descriptionRu,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.35,
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
    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _FeatureLine extends StatelessWidget {
  final String text;

  const _FeatureLine({required this.text});

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
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3)),
        ),
      ],
    ),
  );
}

/// A single word/phrase card — [reading] only renders when the dialect has
/// one the app can vouch for, and the speaker button only when [hasAudio]
/// says the device can actually pronounce it (see `data/dialects.dart`).
class _ExampleCard extends StatelessWidget {
  final DialectExample example;
  final bool hasAudio;

  const _ExampleCard({required this.example, required this.hasAudio});

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
                    example.hanzi,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                  if (example.reading != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      example.reading!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(example.ru, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            if (hasAudio) SpeakButton(text: example.hanzi, size: 22),
          ],
        ),
      ),
    );
  }
}
