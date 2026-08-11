export function HeartsRow({ hearts, max = 5 }: { hearts: number; max?: number }) {
  return (
    <div className="flex gap-0.5 text-lg leading-none">
      {Array.from({ length: max }).map((_, i) => (
        <span key={i} className={i < hearts ? 'text-red-500' : 'text-gray-300 dark:text-gray-600'}>
          ♥
        </span>
      ))}
    </div>
  );
}
