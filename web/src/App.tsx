import { useState } from 'react';
import type { Word } from './types';
import { LESSONS } from './data/lessons';
import { ProgressProvider, useProgress } from './state/ProgressContext';
import { HomeScreen } from './screens/HomeScreen';
import { LessonScreen, type LessonResult } from './screens/LessonScreen';
import { ProfileScreen } from './screens/ProfileScreen';
import { ResultsScreen } from './screens/ResultsScreen';
import { SettingsScreen } from './screens/SettingsScreen';

type Screen = 'home' | 'lesson' | 'review' | 'results' | 'profile' | 'settings';

function AppShell() {
  const { dueWordIds, restoreHeartsFully } = useProgress();
  const [screen, setScreen] = useState<Screen>('home');
  const [activeLessonId, setActiveLessonId] = useState<string | null>(null);
  const [lastResult, setLastResult] = useState<LessonResult | null>(null);

  const activeLesson = LESSONS.find((l) => l.id === activeLessonId);

  function handleLessonComplete(result: LessonResult) {
    setLastResult(result);
    setScreen('results');
  }

  function handleReviewComplete(result: LessonResult) {
    setLastResult(result);
    restoreHeartsFully();
    setScreen('results');
  }

  if (screen === 'lesson' && activeLesson) {
    return (
      <LessonScreen
        wordIds={activeLesson.wordIds}
        title={activeLesson.title}
        lessonId={activeLesson.id}
        onExit={() => setScreen('home')}
        onComplete={handleLessonComplete}
      />
    );
  }

  if (screen === 'review') {
    return (
      <LessonScreen
        wordIds={dueWordIds}
        title="Повторение"
        lessonId="review"
        onExit={() => setScreen('home')}
        onComplete={handleReviewComplete}
      />
    );
  }

  if (screen === 'results' && lastResult) {
    return (
      <ResultsScreen
        xpEarned={lastResult.xpEarned}
        mistakes={lastResult.mistakes as Word[]}
        perfect={lastResult.perfect}
        onContinue={() => setScreen('home')}
      />
    );
  }

  if (screen === 'profile') {
    return <ProfileScreen onBack={() => setScreen('home')} />;
  }

  if (screen === 'settings') {
    return <SettingsScreen onBack={() => setScreen('home')} />;
  }

  return (
    <HomeScreen
      onSelectLesson={(lessonId) => {
        setActiveLessonId(lessonId);
        setScreen('lesson');
      }}
      onReview={() => setScreen('review')}
      onProfile={() => setScreen('profile')}
      onSettings={() => setScreen('settings')}
    />
  );
}

export default function App() {
  return (
    <ProgressProvider>
      <AppShell />
    </ProgressProvider>
  );
}
