import { toneOfSyllable, TONE_COLOR_CLASS } from '../lib/tone';

export function ToneText({ pinyin, className = '' }: { pinyin: string; className?: string }) {
  const syllables = pinyin.split(' ');
  return (
    <span className={className}>
      {syllables.map((syl, i) => (
        <span key={i} className={TONE_COLOR_CLASS[toneOfSyllable(syl)]}>
          {syl}
          {i < syllables.length - 1 ? ' ' : ''}
        </span>
      ))}
    </span>
  );
}
