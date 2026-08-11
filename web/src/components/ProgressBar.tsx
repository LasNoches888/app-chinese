export function ProgressBar({ value, className = '' }: { value: number; className?: string }) {
  const pct = Math.round(Math.min(1, Math.max(0, value)) * 100);
  return (
    <div className={`h-3 w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700 ${className}`}>
      <div className="h-full rounded-full bg-green-500 transition-all duration-300" style={{ width: `${pct}%` }} />
    </div>
  );
}
