import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';
import '../components/app_bar_actions.dart';
import '../data/dialects.dart';
import 'dialect_compare_screen.dart';
import 'dialect_detail_screen.dart';

/// Entry point of the "Диалекты" tab: what China's major dialect groups
/// are, roughly where they're spoken, and a way into each one.
///
/// There's no literal map graphic here — the app has no illustrated map
/// asset, and faking one with a hand-drawn approximation of China's
/// provincial borders would risk looking like a wrong map rather than a
/// stylized one. The seven colored dots below do the job the mockup's map
/// legend already did: tie a color to each dialect, with the actual
/// navigation happening through the list, exactly as the mockup's own
/// legend rows already worked.
class DialectsMapScreen extends StatelessWidget {
  const DialectsMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('dialectsTitle')),
        actions: [
          IconButton(
            tooltip: settings.t('dialectsCompareTooltip'),
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DialectCompareScreen(),
              ),
            ),
          ),
          const AppBarActions(),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(settings.t('dialectsSubtitle'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final d in kDialects)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
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
                children: [
                  for (var i = 0; i < kDialects.length; i++)
                    _DialectRow(
                      dialect: kDialects[i],
                      showDivider: i != kDialects.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialectRow extends StatelessWidget {
  final DialectInfo dialect;
  final bool showDivider;

  const _DialectRow({required this.dialect, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DialectDetailScreen(dialectId: dialect.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dialect.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    dialect.nameRu,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    dialect.regionRu,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 14, endIndent: 14),
      ],
    );
  }
}
