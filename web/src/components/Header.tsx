import { useProgress } from '../state/ProgressContext';
import { HeartsRow } from './HeartsRow';

export function Header({ onProfile, onSettings }: { onProfile: () => void; onSettings: () => void }) {
  const { streakDays, xpTotal, state } = useProgress();
  return (
    <header className="flex items-center justify-between border-b border-gray-200 px-4 py-3 dark:border-gray-700">
      <div className="flex items-center gap-4 text-sm font-semibold">
        <span className="flex items-center gap-1 text-orange-500">🔥 {streakDays}</span>
        <span className="flex items-center gap-1 text-amber-500">⭐ {xpTotal} XP</span>
        <HeartsRow hearts={state.hearts} />
      </div>
      <div className="flex items-center gap-1">
        <button
          onClick={onProfile}
          className="rounded-lg px-2 py-1 text-lg hover:bg-gray-100 dark:hover:bg-gray-800"
          aria-label="Профиль"
        >
          👤
        </button>
        <button
          onClick={onSettings}
          className="rounded-lg px-2 py-1 text-lg hover:bg-gray-100 dark:hover:bg-gray-800"
          aria-label="Настройки"
        >
          ⚙️
        </button>
      </div>
    </header>
  );
}
