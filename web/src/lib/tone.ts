const TONE_MAP: Record<string, number> = {
  ā: 1, ē: 1, ī: 1, ō: 1, ū: 1, ǖ: 1,
  á: 2, é: 2, í: 2, ó: 2, ú: 2, ǘ: 2,
  ǎ: 3, ě: 3, ǐ: 3, ǒ: 3, ǔ: 3, ǚ: 3,
  à: 4, è: 4, ì: 4, ò: 4, ù: 4, ǜ: 4,
};

/** Tone of a single pinyin syllable: 1-4, or 5 for neutral tone. */
export function toneOfSyllable(syllable: string): number {
  for (const ch of syllable) {
    const tone = TONE_MAP[ch];
    if (tone) return tone;
  }
  return 5;
}

export const TONE_COLOR_CLASS: Record<number, string> = {
  1: 'text-tone1',
  2: 'text-tone2',
  3: 'text-tone3',
  4: 'text-tone4',
  5: 'text-tone5',
};

/** Strips tone diacritics, e.g. "nǐ hǎo" -> "ni hao" (for loose pinyin input matching). */
export function stripTones(pinyin: string): string {
  return pinyin
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();
}
