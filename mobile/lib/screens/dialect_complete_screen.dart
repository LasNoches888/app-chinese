import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../data/dialects.dart';

/// Shown after finishing a dialect's flashcards or practice dialogue.
/// [phrasesCovered] is the actual count of items just reviewed — not a
/// fabricated "time studied" figure the app has no way to measure for a
/// self-paced read-along.
class DialectCompleteScreen extends StatelessWidget {
  final String dialectId;
  final int phrasesCovered;

  const DialectCompleteScreen({
    super.key,
    required this.dialectId,
    required this.phrasesCovered,
  });

  DialectInfo get _dialect => kDialects.firstWhere((d) => d.id == dialectId);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final dialect = _dialect;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/mascot/panda_04.png', height: 130),
                const SizedBox(height: 16),
                Text(
                  settings.t('dialectCompleteTitle'),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  settings.t('dialectCompleteSubtitle'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: dialect.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(dialect.nameRu, style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(settings.t('dialectCompletePhrases'), style: theme.textTheme.bodyMedium),
                          Text(
                            '$phrasesCovered',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: dialect.color),
                    // Back to the lessons list one level up, where the tile
                    // just finished now shows a checkmark.
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(settings.t('continueLabel')),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: Text(settings.t('dialectBackToList')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
