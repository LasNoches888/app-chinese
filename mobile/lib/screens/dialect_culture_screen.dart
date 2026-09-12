import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';
import '../data/dialects.dart';
import '../services/dialect_progress_service.dart';

/// A short, factual article about the dialect's history/culture, plus a
/// couple of real vocabulary items. Marked done on open — there's nothing
/// to grade here, it's reading, so "opened it" is the honest definition of
/// "done" (same idea as `_load` marking a step seen rather than tested).
class DialectCultureScreen extends StatefulWidget {
  final String dialectId;

  const DialectCultureScreen({super.key, required this.dialectId});

  @override
  State<DialectCultureScreen> createState() => _DialectCultureScreenState();
}

class _DialectCultureScreenState extends State<DialectCultureScreen> {
  DialectInfo get _dialect => kDialects.firstWhere((d) => d.id == widget.dialectId);

  @override
  void initState() {
    super.initState();
    unawaited(
      DialectProgressService.markDone(widget.dialectId, DialectLessonKind.culture),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final dialect = _dialect;

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('dialectCultureTeaser'))),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dialect.color,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    dialect.cultureTitleRu,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              dialect.cultureBodyRu,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 22),
            Text(
              settings.t('dialectCultureVocab'),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final v in dialect.cultureVocab)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text(v.hanzi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      if (v.reading != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          v.reading!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          v.ru,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
