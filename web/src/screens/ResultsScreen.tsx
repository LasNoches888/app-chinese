import type { Word } from '../types';
import { ToneText } from '../components/ToneText';

export function ResultsScreen({
  xpEarned,
  mistakes,
  perfect,
  onContinue,
}: {
  xpEarned: number;
  mistakes: Word[];
  perfect: boolean;
  onContinue: () => void;
}) {
  return (
    <div className="mx-auto flex min-h-screen max-w-lg flex-col items-center justify-center gap-6 px-4 py-10 text-center">
      <div className="text-6xl">{perfect ? '🏆' : '🎉'}</div>
      <h1 className="text-2xl font-bold">{perfect ? 'Идеальный урок!' : 'Урок завершён!'}</h1>
      <div className="rounded-2xl bg-amber-100 px-6 py-3 text-xl font-bold text-amber-700 dark:bg-amber-900/40 dark:text-amber-300">
        +{xpEarned} XP
      </div>
      {mistakes.length > 0 && (
        <div className="w-full rounded-2xl border border-gray-200 p-4 text-left dark:border-gray-700">
          <div className="mb-2 font-semibold">Повторить позже:</div>
          <ul className="flex flex-col gap-2">
            {mistakes.map((w) => (
              <li key={w.id} className="flex items-center justify-between gap-2 text-sm">
                <span className="text-lg">{w.hanzi}</span>
                <ToneText pinyin={w.pinyin} className="text-gray-500" />
                <span>{w.translation}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
      <button
        onClick={onContinue}
        className="rounded-full bg-green-500 px-10 py-3 font-bold text-white hover:bg-green-600"
      >
        Продолжить
      </button>
    </div>
  );
}
