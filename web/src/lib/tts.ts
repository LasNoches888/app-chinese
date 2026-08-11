let cachedVoice: SpeechSynthesisVoice | null | undefined;

function pickChineseVoice(): SpeechSynthesisVoice | null {
  if (cachedVoice !== undefined) return cachedVoice;
  const voices = window.speechSynthesis?.getVoices() ?? [];
  cachedVoice = voices.find((v) => v.lang.toLowerCase().startsWith('zh')) ?? null;
  return cachedVoice;
}

// Voice lists load asynchronously in some browsers.
if (typeof window !== 'undefined' && window.speechSynthesis) {
  window.speechSynthesis.onvoiceschanged = () => {
    cachedVoice = undefined;
  };
}

export function speakChinese(text: string): void {
  if (typeof window === 'undefined' || !window.speechSynthesis) return;
  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = 'zh-CN';
  utterance.rate = 0.85;
  const voice = pickChineseVoice();
  if (voice) utterance.voice = voice;
  window.speechSynthesis.speak(utterance);
}

export function ttsSupported(): boolean {
  return typeof window !== 'undefined' && !!window.speechSynthesis;
}
