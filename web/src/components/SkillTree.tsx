import { LESSONS } from '../data/lessons';
import { useProgress } from '../state/ProgressContext';

export function SkillTree({ onSelectLesson }: { onSelectLesson: (lessonId: string) => void }) {
  const { state } = useProgress();
  return (
    <div className="mx-auto flex max-w-md flex-col items-center gap-6 py-8">
      {LESSONS.map((lesson, i) => {
        const completed = state.completedLessons.includes(lesson.id);
        const unlocked = i === 0 || state.completedLessons.includes(LESSONS[i - 1].id);
        return (
          <button
            key={lesson.id}
            disabled={!unlocked}
            onClick={() => onSelectLesson(lesson.id)}
            className={[
              'flex h-20 w-20 flex-col items-center justify-center rounded-full border-4 text-center text-xs font-bold shadow-md transition',
              completed
                ? 'border-green-500 bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300'
                : unlocked
                  ? 'border-sky-500 bg-sky-100 text-sky-700 hover:scale-105 dark:bg-sky-900/40 dark:text-sky-300'
                  : 'border-gray-300 bg-gray-100 text-gray-400 dark:border-gray-700 dark:bg-gray-800',
            ].join(' ')}
          >
            <span className="text-xl">{completed ? '✓' : unlocked ? '文' : '🔒'}</span>
            <span className="mt-1 px-1 leading-tight">{lesson.title}</span>
          </button>
        );
      })}
    </div>
  );
}
