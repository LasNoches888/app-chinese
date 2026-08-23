import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../components/app_background.dart';

/// Roleplay runs on the Tutor persona (see buildScenarioSystemPrompt),
/// which is currently paused while it moves to run server-side — see
/// isChatModeComingSoon. So this always shows the same coming-soon card
/// the chat screen shows for Tutor, rather than picking scenarios that
/// would have nothing to talk to.
class ScenarioListScreen extends StatelessWidget {
  const ScenarioListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('scenariosTitle'))),
      body: AppBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/mascot/panda_25.png', height: 140),
                const SizedBox(height: 20),
                Text(
                  settings.t('tutorInDevTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  settings.t('scenariosNeedLocalModel'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
