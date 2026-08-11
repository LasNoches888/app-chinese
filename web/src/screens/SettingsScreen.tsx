import { useProgress } from '../state/ProgressContext';

export function SettingsScreen({ onBack }: { onBack: () => void }) {
  const { state, setDirection, setDailyGoalXp, setTheme } = useProgress();

  return (
    <div className="mx-auto min-h-screen max-w-lg px-4 py-6">
      <button onClick={onBack} className="mb-4 text-sm text-gray-500 hover:text-gray-700">
        ← Назад
      </button>
      <h1 className="mb-6 text-2xl font-bold">Настройки</h1>

      <section className="mb-6">
        <h2 className="mb-2 font-semibold">Направление перевода</h2>
        <div className="flex gap-2">
          <button
            onClick={() => setDirection('zh-ru')}
            className={`flex-1 rounded-xl border-2 px-4 py-2 ${
              state.direction === 'zh-ru'
                ? 'border-sky-500 bg-sky-50 dark:bg-sky-900/30'
                : 'border-gray-200 dark:border-gray-700'
            }`}
          >
            中文 → Русский
          </button>
          <button
            onClick={() => setDirection('ru-zh')}
            className={`flex-1 rounded-xl border-2 px-4 py-2 ${
              state.direction === 'ru-zh'
                ? 'border-sky-500 bg-sky-50 dark:bg-sky-900/30'
                : 'border-gray-200 dark:border-gray-700'
            }`}
          >
            Русский → 中文
          </button>
        </div>
      </section>

      <section className="mb-6">
        <h2 className="mb-2 font-semibold">Дневная цель</h2>
        <div className="flex gap-2">
          {[5, 10, 20].map((goal) => (
            <button
              key={goal}
              onClick={() => setDailyGoalXp(goal)}
              className={`flex-1 rounded-xl border-2 px-4 py-2 ${
                state.dailyGoalXp === goal
                  ? 'border-sky-500 bg-sky-50 dark:bg-sky-900/30'
                  : 'border-gray-200 dark:border-gray-700'
              }`}
            >
              {goal} XP
            </button>
          ))}
        </div>
      </section>

      <section className="mb-6">
        <h2 className="mb-2 font-semibold">Тема</h2>
        <div className="flex gap-2">
          <button
            onClick={() => setTheme('light')}
            className={`flex-1 rounded-xl border-2 px-4 py-2 ${
              state.theme === 'light' ? 'border-sky-500 bg-sky-50' : 'border-gray-200 dark:border-gray-700'
            }`}
          >
            ☀️ Светлая
          </button>
          <button
            onClick={() => setTheme('dark')}
            className={`flex-1 rounded-xl border-2 px-4 py-2 ${
              state.theme === 'dark' ? 'border-sky-500 bg-sky-900/30' : 'border-gray-200 dark:border-gray-700'
            }`}
          >
            🌙 Тёмная
          </button>
        </div>
      </section>
    </div>
  );
}
