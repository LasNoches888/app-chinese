import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';
import '../data/scenarios.dart';
import '../services/local_llm_service.dart';
import 'scenario_chat_screen.dart';
import 'settings_screen.dart';

/// Picks one of the fixed roleplay scenarios. Local-only: the server
/// /chat endpoint builds its own fixed tutor persona server-side and has
/// no hook to swap in a scenario's system prompt, while the local model
/// is fully client-controlled (see buildScenarioSystemPrompt).
class ScenarioListScreen extends StatelessWidget {
  const ScenarioListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final ready = LocalLlmService.isModelReady(LocalModelVariant.tutor);

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('scenariosTitle'))),
      body: AppBackground(
        child: !ready
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🚪', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        settings.t('scenariosNeedLocalModel'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                        child: Text(settings.t('settings')),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: kChatScenarios.length,
                itemBuilder: (ctx, i) {
                  final s = kChatScenarios[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Text(
                        s.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(s.titleRu),
                      subtitle: Text(s.descriptionRu),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ScenarioChatScreen(scenario: s),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
