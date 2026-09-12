import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/speak_button.dart';
import '../data/dialects.dart';
import '../services/dialect_progress_service.dart';
import 'dialect_complete_screen.dart';

/// A short scripted exchange, revealed one line at a time — a read-along,
/// not a graded conversation. Only reachable for dialects with a
/// [DialectInfo.dialogue] (today, just Mandarin), so every line shown here
/// is real vocabulary the app can also pronounce.
class DialectPracticeScreen extends StatefulWidget {
  final String dialectId;

  const DialectPracticeScreen({super.key, required this.dialectId});

  @override
  State<DialectPracticeScreen> createState() => _DialectPracticeScreenState();
}

class _DialectPracticeScreenState extends State<DialectPracticeScreen> {
  int _shown = 1;

  DialectInfo get _dialect => kDialects.firstWhere((d) => d.id == widget.dialectId);

  Future<void> _next() async {
    final lines = _dialect.dialogue!;
    if (_shown < lines.length) {
      setState(() => _shown++);
      return;
    }
    await DialectProgressService.markDone(_dialect.id, DialectLessonKind.practice);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DialectCompleteScreen(
          dialectId: _dialect.id,
          phrasesCovered: lines.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final dialect = _dialect;
    final lines = dialect.dialogue!;
    final isLast = _shown >= lines.length;

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('dialectLessonPractice'))),
      body: SafeArea(
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _shown / lines.length,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(dialect.color),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [for (var i = 0; i < _shown; i++) _LineBubble(line: lines[i], color: dialect.color)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: dialect.color),
                  onPressed: _next,
                  child: Text(isLast ? settings.t('continueLabel') : settings.t('dialectPracticeNext')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineBubble extends StatelessWidget {
  final PracticeLine line;
  final Color color;

  const _LineBubble({required this.line, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMascot = line.speaker == PracticeSpeaker.mascot;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isMascot ? theme.colorScheme.surface : color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isMascot
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  line.hanzi,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isMascot ? null : Colors.white,
                  ),
                ),
              ),
              if (isMascot) ...[
                const SizedBox(width: 4),
                SpeakButton(text: line.hanzi, size: 18),
              ],
            ],
          ),
          if (line.reading != null) ...[
            const SizedBox(height: 2),
            Text(
              line.reading!,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isMascot
                    ? theme.colorScheme.onSurfaceVariant
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            line.ru,
            style: TextStyle(
              fontSize: 13,
              color: isMascot ? theme.colorScheme.onSurfaceVariant : Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );

    return Row(
      mainAxisAlignment: isMascot ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (isMascot) ...[
          const CircleAvatar(radius: 16, child: Text('🐼')),
          const SizedBox(width: 8),
        ],
        Flexible(child: bubble),
        if (!isMascot) ...[
          const SizedBox(width: 8),
          const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
        ],
      ],
    );
  }
}
