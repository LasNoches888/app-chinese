import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';
import '../data/dialects.dart';
import '../theme/app_theme.dart';

/// Same characters, three real romanizations side by side — Mandarin
/// Pinyin, Cantonese Jyutping, Southern Min POJ. Scoped to just these
/// three because they're the only groups with a standardized romanization
/// system precise enough to print at the single-character level with
/// confidence (see `data/dialects.dart`'s doc comment on
/// [DialectCompareEntry]).
class DialectCompareScreen extends StatelessWidget {
  const DialectCompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('dialectCompareTitle'))),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(settings.t('dialectCompareIntro'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            for (final entry in kDialectCompareEntries) _CompareCard(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  final DialectCompareEntry entry;

  const _CompareCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.ru, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
              _CompareColumn(label: 'Мандарин', hanzi: entry.hanziMandarin, reading: entry.pinyin, color: AppColors.blue),
              _CompareColumn(label: 'Кантонский', hanzi: entry.hanziYue, reading: entry.jyutping, color: AppColors.orange),
              _CompareColumn(label: 'Мин', hanzi: entry.hanziMin, reading: entry.poj, color: AppColors.purple),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.tipRu, style: theme.textTheme.bodySmall?.copyWith(height: 1.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareColumn extends StatelessWidget {
  final String label;
  final String hanzi;
  final String reading;
  final Color color;

  const _CompareColumn({
    required this.label,
    required this.hanzi,
    required this.reading,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(hanzi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            reading,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
