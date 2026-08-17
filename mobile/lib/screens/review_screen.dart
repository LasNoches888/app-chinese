import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import 'lesson_session_screen.dart';
import 'settings_screen.dart';

/// SRS review tab: shows how many words are due right now and, when
/// tapped, runs them through the same exercise engine as a lesson.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<String>? _dueWordIds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final due = await repos.srs.getDueWordIds();
    if (!mounted) return;
    setState(() => _dueWordIds = due);
  }

  Future<void> _startReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonSessionScreen(
          wordIds: _dueWordIds!,
          title: context.read<AppSettings>().t('review'),
          isReview: true,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('review')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: AppBackground(
        child: _dueWordIds == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _dueWordIds!.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: 400,
                            child: Center(
                                child: Text(settings.t('noReviewDue'),
                                    textAlign: TextAlign.center)),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(Icons.refresh,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${_dueWordIds!.length} ${settings.t('due')}',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: _startReview,
                                    child: Text(settings.t('review')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }
}
