import { useProgress } from '../state/ProgressContext';
import { Header } from '../components/Header';
import { ProgressBar } from '../components/ProgressBar';
import { SkillTree } from '../components/SkillTree';

export function HomeScreen({
  onSelectLesson,
  onReview,
  onProfile,
  onSettings,
}: {
  onSelectLesson: (lessonId: string) => void;
  onReview: () => void;
  onProfile: () => void;
  onSettings: () => void;
}) {
  const { xpToday, state, dueWordIds } = useProgress();
  const goalPct = state.dailyGoalXp > 0 ? xpToday / state.dailyGoalXp : 0;

  return (
    <div className="min-h-screen pb-10">
      <Header onProfile={onProfile} onSettings={onSettings} />
      <div className="mx-auto max-w-md px-4 py-4">
        <div className="mb-4 rounded-2xl border border-gray-200 p-4 dark:border-gray-700">
          <div className="mb-1 flex justify-between text-sm font-medium">
            <span>Дневная цель</span>
            <span>
              {xpToday}/{state.dailyGoalXp} XP
            </span>
          </div>
          <ProgressBar value={goalPct} />
        </div>
        {dueWordIds.length > 0 && (
          <button
            onClick={onReview}
            className="mb-2 flex w-full items-center justify-between rounded-2xl bg-purple-100 px-4 py-3 font-semibold text-purple-700 dark:bg-purple-900/30 dark:text-purple-300"
          >
            <span>🔁 Повторить слова</span>
            <span className="rounded-full bg-purple-500 px-2 py-0.5 text-xs text-white">{dueWordIds.length}</span>
          </button>
        )}
      </div>
      <SkillTree onSelectLesson={onSelectLesson} />
    </div>
  );
}
