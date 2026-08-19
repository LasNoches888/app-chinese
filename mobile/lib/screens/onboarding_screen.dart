import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import 'placement_test_screen.dart';

/// First-launch welcome screen. There was no onboarding at all before this
/// — the app opened straight into the lesson list, with no explanation of
/// what makes it different (offline SRS, a local on-device tutor) and no
/// path into the placement test, which existed but was buried three taps
/// deep in the Practice tab with nothing pointing new users at it.
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  Future<void> _finish(BuildContext context) async {
    await context.read<AppSettings>().setOnboarded();
    onDone();
  }

  Future<void> _startPlacementTest(BuildContext context) async {
    await context.read<AppSettings>().setOnboarded();
    if (!context.mounted) return;
    onDone();
    // Pushed after onDone() swaps in HomeShell, so "back" from the test
    // lands on the lesson list rather than looping back to onboarding.
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlacementTestScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/onboarding_bg.jpg', fit: BoxFit.cover),
          // The art is bright top-to-bottom, so text needs a scrim behind
          // it rather than relying on contrast with the painting itself.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                children: [
                  const Spacer(),
                  const Text(
                    'Uchi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    settings.t('onboardingPitch'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6C5CE7),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _startPlacementTest(context),
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: Text(settings.t('onboardingPlacementCta')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => _finish(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.9),
                    ),
                    child: Text(settings.t('onboardingSkipCta')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
