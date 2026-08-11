import { WORDS } from '../data/words';
import { ACHIEVEMENTS } from '../lib/achievements';
import { useProgress } from '../state/ProgressContext';
import { ToneText } from '../components/ToneText';

function StatTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-gray-200 p-3 text-center dark:border-gray-700">
      <div className="text-xl font-bold">{value}</div>
      <div className="text-xs text-gray-500">{label}</div>
    </div>
  );
}

export function ProfileScreen({ onBack }: { onBack: () => void }) {
  const { state, streakDays, xpTotal, level, learnedWordIds, unlockedAchievements } = useProgress();

  const days = Array.from({ length: 35 }, (_, i) => {
    const d = new Date();
    d.setDate(d.getDate() - (34 - i));
    const key = d.toISOString().slice(0, 10);
    return { key, xp: state.xpByDate[key] ?? 0 };
  });

  const learnedWords = WORDS.filter((w) => learnedWordIds.includes(w.id));

  return (
    <div className="mx-auto min-h-screen max-w-lg px-4 py-6">
      <button onClick={onBack} className="mb-4 text-sm text-gray-500 hover:text-gray-700">
        ← Назад
      </button>
      <h1 className="mb-4 text-2xl font-bold">Профиль</h1>

      <div className="mb-6 grid grid-cols-2 gap-3">
        <StatTile label="Уровень" value={String(level)} />
        <StatTile label="Всего XP" value={String(xpTotal)} />
        <StatTile label="Серия дней" value={String(streakDays)} />
        <StatTile label="Слов выучено" value={`${learnedWordIds.length}/${WORDS.length}`} />
      </div>

      <h2 className="mb-2 font-semibold">Календарь серии</h2>
      <div className="mb-6 grid grid-cols-7 gap-1">
        {days.map((d) => (
          <div
            key={d.key}
            title={d.key}
            className={`h-6 w-6 rounded ${d.xp > 0 ? 'bg-green-500' : 'bg-gray-200 dark:bg-gray-700'}`}
          />
        ))}
      </div>

      <h2 className="mb-2 font-semibold">Достижения</h2>
      <div className="mb-6 flex flex-wrap gap-2">
        {ACHIEVEMENTS.map((a) => {
          const unlocked = unlockedAchievements.includes(a.id);
          return (
            <div
              key={a.id}
              className={`flex items-center gap-1 rounded-full px-3 py-1 text-sm ${
                unlocked
                  ? 'bg-amber-500 text-white'
                  : 'bg-gray-100 text-gray-400 dark:bg-gray-800 dark:text-gray-600'
              }`}
            >
              <span>{a.icon}</span>
              <span>{a.label}</span>
            </div>
          );
        })}
      </div>

      <h2 className="mb-2 font-semibold">Выученные слова</h2>
      <ul className="flex flex-col gap-1">
        {learnedWords.map((w) => (
          <li
            key={w.id}
            className="flex items-center justify-between gap-2 rounded-lg border border-gray-100 px-3 py-2 text-sm dark:border-gray-800"
          >
            <span className="text-lg">{w.hanzi}</span>
            <ToneText pinyin={w.pinyin} className="text-gray-500" />
            <span>{w.translation}</span>
          </li>
        ))}
        {learnedWords.length === 0 && <li className="text-sm text-gray-400">Пока ничего не выучено</li>}
      </ul>
    </div>
  );
}
