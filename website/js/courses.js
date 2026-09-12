// "Курсы" section — real HSK deck data (website/data/decks.json,
// words.json — copied verbatim from mobile/assets/seed, the same bank the
// phone app teaches from) with a genuine multiple-choice quiz, not a
// placeholder. HSK 5/6 tabs aren't offered: there's no deck content for
// them yet (see mobile/assets/seed/decks.json — only 1-4 exist), and a
// tab that opens onto nothing is worse than a shorter, honest tab list.
const Courses = (() => {
  let decks = null;
  let words = null;
  let loading = null;

  function load() {
    if (loading) return loading;
    loading = Promise.all([
      fetch('data/decks.json').then((r) => r.json()),
      fetch('data/words.json').then((r) => r.json()),
    ]).then(([d, w]) => { decks = d; words = w; });
    return loading;
  }

  const TOPIC_ICON = {
    greetings: 'chat', numbers: 'hash', people: 'user', family: 'home',
    food: 'cup', food2: 'cup', time: 'clock', questions: 'question',
    verbs1: 'bolt', adjectives1: 'star', places1: 'pin', objects1: 'box',
    grammar1: 'link', colors: 'palette', movement: 'arrow', study2: 'book',
    shopping2: 'bag', body2: 'heart', transport2: 'car', adverbs2: 'link',
    daily2: 'sun', emotions3: 'smile', work3: 'briefcase', travel3: 'plane',
    nature3: 'leaf', society3: 'users',
  };
  const ICONS = {
    chat: '<path d="M4 12c0-4.4 3.6-8 8-8s8 3.6 8 8-3.6 8-8 8c-1.1 0-2.2-.2-3.1-.6L4 21l1.7-4.6C4.6 15 4 13.6 4 12Z" stroke-linejoin="round" stroke-linecap="round"/>',
    hash: '<path d="M9 3 7 21M17 3l-2 18M4 8h17M3 16h17" stroke-linecap="round"/>',
    user: '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.9 3.1-7 7-7s7 3.1 7 7" stroke-linecap="round"/>',
    home: '<path d="M4 11 12 4l8 7" stroke-linecap="round" stroke-linejoin="round"/><path d="M6 10v9h12v-9" stroke-linecap="round" stroke-linejoin="round"/>',
    cup: '<path d="M6 3h9v9a4.5 4.5 0 0 1-9 0V3Z" stroke-linejoin="round"/><path d="M15 6h2.5A1.5 1.5 0 0 1 19 7.5v1A2.5 2.5 0 0 1 16.5 11H15"/>',
    clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.5 2" stroke-linecap="round" stroke-linejoin="round"/>',
    question: '<circle cx="12" cy="12" r="8.5"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.3-1 .8-1 1.7" stroke-linecap="round"/><circle cx="12" cy="17" r="0.6" fill="currentColor"/>',
    bolt: '<path d="M13 3 5 14h6l-1 7 8-11h-6l1-7Z" stroke-linejoin="round" stroke-linecap="round"/>',
    star: '<path d="m12 3 2.6 5.9 6.4.6-4.8 4.3 1.4 6.3L12 17l-5.6 3.1 1.4-6.3-4.8-4.3 6.4-.6L12 3Z" stroke-linejoin="round"/>',
    pin: '<path d="M12 21s7-6.1 7-11.5S16.4 3 12 3 5 5.6 5 9.5 12 21 12 21Z" stroke-linejoin="round"/><circle cx="12" cy="9.5" r="2.5"/>',
    box: '<path d="M3 8 12 4l9 4-9 4-9-4Z" stroke-linejoin="round"/><path d="M3 8v9l9 4 9-4V8M12 12v9" stroke-linejoin="round"/>',
    link: '<path d="M9 15 15 9" stroke-linecap="round"/><path d="M11 6h3a4 4 0 0 1 0 8h-1M13 18h-3a4 4 0 0 1 0-8h1" stroke-linecap="round" stroke-linejoin="round"/>',
    palette: '<circle cx="12" cy="12" r="8.5"/><circle cx="9" cy="10" r="1" fill="currentColor"/><circle cx="13" cy="8.5" r="1" fill="currentColor"/><circle cx="16" cy="11.5" r="1" fill="currentColor"/><path d="M9 15c1 1 5 1 6-1" stroke-linecap="round"/>',
    arrow: '<path d="M5 12h14M13 6l6 6-6 6" stroke-linecap="round" stroke-linejoin="round"/>',
    book: '<path d="M4 5.5C4 4.7 4.7 4 5.5 4H14v16H5.5A1.5 1.5 0 0 1 4 18.5v-13Z" stroke-linejoin="round"/><path d="M14 4h4.5C19.3 4 20 4.7 20 5.5v13c0 .8-.7 1.5-1.5 1.5H14" stroke-linejoin="round"/>',
    bag: '<path d="M6 8h12l-1 12H7L6 8Z" stroke-linejoin="round"/><path d="M9 8V6a3 3 0 0 1 6 0v2" stroke-linecap="round"/>',
    heart: '<path d="M12 20s-7-4.3-9.5-8.8C1 8 2.5 4.5 6 4.5c2 0 3.3 1.1 4 2.3.7-1.2 2-2.3 4-2.3 3.5 0 5 3.5 3.5 6.7C19 15.7 12 20 12 20Z" stroke-linejoin="round"/>',
    car: '<path d="M4 16V11l2-4h12l2 4v5" stroke-linejoin="round"/><path d="M4 16h16M7 16v2M17 16v2" stroke-linecap="round"/><circle cx="7.5" cy="16" r="1.4"/><circle cx="16.5" cy="16" r="1.4"/>',
    sun: '<circle cx="12" cy="12" r="4.5"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4" stroke-linecap="round"/>',
    smile: '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 14c1 1.3 2.2 2 3.5 2s2.5-.7 3.5-2" stroke-linecap="round"/><circle cx="9" cy="10" r="0.8" fill="currentColor"/><circle cx="15" cy="10" r="0.8" fill="currentColor"/>',
    briefcase: '<rect x="3" y="7.5" width="18" height="12" rx="1.5"/><path d="M8 7.5V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v1.5M3 12.5h18" stroke-linecap="round"/>',
    plane: '<path d="M10.5 20.5 12 15l7.5-4.5c1-.6 1-2 0-2.6-.6-.4-1.4-.4-2 0L10 12 4.5 10 3 11l4.5 3-1 3.5 1.5 1 2-2.6 3 4.6.5.5Z" stroke-linejoin="round"/>',
    leaf: '<path d="M5 19C5 10 12 4 20 4c0 8-6 15-15 15Z" stroke-linejoin="round"/><path d="M5 19c2-4 5-7 9-9" stroke-linecap="round"/>',
    users: '<circle cx="9" cy="9" r="3"/><path d="M2.5 19c0-3.3 2.9-6 6.5-6s6.5 2.7 6.5 6" stroke-linecap="round"/><circle cx="17" cy="9" r="2.5"/><path d="M15.5 13.2c2.6.5 4.5 2.6 4.5 5.3" stroke-linecap="round"/>',
    check: '<path d="M20 6 9 17l-5-5" stroke-linecap="round" stroke-linejoin="round"/>',
    speaker: '<path d="M4 9v6h4l5 4V5L8 9H4Z" stroke-linejoin="round"/><path d="M17 8.5a5 5 0 0 1 0 7" stroke-linecap="round"/>',
  };
  const icon = (name, cls) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="${cls || 'icon-sm'}">${ICONS[name] || ICONS.book}</svg>`;

  let zhVoice = null;
  if ('speechSynthesis' in window) {
    const refresh = () => { zhVoice = speechSynthesis.getVoices().find((v) => v.lang && v.lang.toLowerCase().startsWith('zh')) || null; };
    refresh();
    speechSynthesis.onvoiceschanged = refresh;
  }
  function speak(text) {
    if (!zhVoice) return;
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.voice = zhVoice; u.lang = 'zh-CN'; u.rate = 0.85;
    speechSynthesis.speak(u);
  }

  function progress() {
    try { return JSON.parse(localStorage.getItem('uchi_course_progress')) || {}; } catch { return {}; }
  }
  function markDeckDone(deckId) {
    const p = progress();
    p[deckId] = true;
    try { localStorage.setItem('uchi_course_progress', JSON.stringify(p)); } catch {}
  }

  let activeLevel = 1;
  let quiz = null; // { deckId, questions: [{word, options}], index, correct }

  function buildQuiz(deckId) {
    const deckWords = words.filter((w) => w.deck_id === deckId);
    const pool = words.filter((w) => w.deck_id !== deckId);
    const questions = deckWords.map((w) => {
      const distractors = [];
      const shuffled = [...pool].sort(() => Math.random() - 0.5);
      for (const d of shuffled) {
        if (distractors.length >= 3) break;
        if (d.translation_ru !== w.translation_ru && !distractors.includes(d.translation_ru)) distractors.push(d.translation_ru);
      }
      const options = [w.translation_ru, ...distractors].sort(() => Math.random() - 0.5);
      return { word: w, options };
    });
    return { deckId, questions, index: 0, correct: 0, answered: null };
  }

  function renderList() {
    const levels = [...new Set(decks.map((d) => d.hsk_level))].sort();
    if (!levels.includes(activeLevel)) activeLevel = levels[0];
    const levelDecks = decks.filter((d) => d.hsk_level === activeLevel);
    const done = progress();
    return `
      <div class="screen">
        <h1 class="section__title" style="font-size:24px">Курсы</h1>
        <p class="section__lead" style="margin-top:6px">Выбери уровень и начни свой путь</p>
        <div class="hsk-tabs">
          ${levels.map((l) => `<button data-hsk-level="${l}" class="${l === activeLevel ? 'is-active' : ''}">HSK ${l}</button>`).join('')}
        </div>
        <div class="topic-grid" style="margin-top:20px">
          ${levelDecks.map((d) => `
            <a class="topic-card" href="app.html#/lessons/deck/${d.id}">
              <div class="topic-card__icon">${icon(TOPIC_ICON[d.topic] || 'book')}</div>
              <div class="topic-card__title">${d.title}</div>
              <div class="topic-card__sub">${d.word_count} слов</div>
              ${done[d.id] ? `<span class="topic-card__done">${icon('check')}</span>` : ''}
            </a>`).join('')}
        </div>
      </div>`;
  }

  function renderLesson(deckId) {
    if (!quiz || quiz.deckId !== deckId) quiz = buildQuiz(deckId);
    const deck = decks.find((d) => d.id === deckId);
    if (quiz.index >= quiz.questions.length) {
      markDeckDone(deckId);
      return `
        <div class="screen">
          <div class="complete">
            <img src="assets/mascot/panda_04.png" alt="">
            <h2>Урок пройден!</h2>
            <p>${deck.title} · ${quiz.correct} из ${quiz.questions.length} правильно</p>
            <button class="dbtn" style="background:var(--blue)" data-nav="app.html#/lessons">К списку тем</button>
          </div>
        </div>`;
    }
    const q = quiz.questions[quiz.index];
    const answered = quiz.answered;
    return `
      <div class="screen">
        <div class="lesson-head">
          <button class="appbar__back" data-nav="app.html#/lessons"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="icon-sm"><path d="m15 18-6-6 6-6" stroke-linecap="round" stroke-linejoin="round"/></svg></button>
          <div>
            <div style="font-weight:800">${deck.title}</div>
            <div style="font-size:12.5px;color:var(--ink-faint)">Вопрос ${quiz.index + 1} из ${quiz.questions.length}</div>
          </div>
        </div>
        <div class="fc-progress"><div class="fc-progress__bar" style="width:${(quiz.index / quiz.questions.length) * 100}%;background:var(--blue)"></div></div>
        <div class="quiz-card">
          <div class="quiz-card__hanzi">${q.word.hanzi}
            <button class="dcard__speak" ${zhVoice ? '' : 'disabled'} data-speak="${q.word.hanzi}">${icon('speaker')}</button>
          </div>
          <div class="quiz-card__reading">${q.word.pinyin}</div>
          <div class="quiz-card__prompt">Какой перевод правильный?</div>
          <div class="quiz-options">
            ${q.options.map((opt) => {
              let cls = '';
              if (answered) {
                if (opt === q.word.translation_ru) cls = 'is-correct';
                else if (opt === answered && opt !== q.word.translation_ru) cls = 'is-wrong';
              }
              return `<button class="quiz-option ${cls}" data-answer="${esc(opt)}" ${answered ? 'disabled' : ''}>${esc(opt)}</button>`;
            }).join('')}
          </div>
          ${answered ? `<button class="dbtn" style="background:var(--blue);margin-top:20px" data-quiz-next>Далее</button>` : ''}
        </div>
      </div>`;
  }

  function esc(s) { return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }

  function render(parts) {
    if (!decks) {
      load().then(() => { if (window.rerenderApp) window.rerenderApp(); });
      return `<div class="screen"><p style="color:var(--ink-faint)">Загрузка…</p></div>`;
    }
    if (parts[1] === 'deck' && parts[2]) return renderLesson(parts[2]);
    quiz = null;
    return renderList();
  }

  function onClick(e) {
    const tab = e.target.closest('[data-hsk-level]');
    if (tab) { activeLevel = Number(tab.getAttribute('data-hsk-level')); if (window.rerenderApp) window.rerenderApp(); return; }

    const nav = e.target.closest('[data-nav]');
    if (nav) { location.hash = nav.getAttribute('data-nav').replace('app.html', ''); return; }

    const speakBtn = e.target.closest('[data-speak]');
    if (speakBtn) { speak(speakBtn.getAttribute('data-speak')); return; }

    const ans = e.target.closest('[data-answer]');
    if (ans && quiz && !quiz.answered) {
      quiz.answered = ans.getAttribute('data-answer');
      if (quiz.answered === quiz.questions[quiz.index].word.translation_ru) quiz.correct++;
      if (window.rerenderApp) window.rerenderApp();
      return;
    }

    const next = e.target.closest('[data-quiz-next]');
    if (next && quiz) {
      quiz.index++;
      quiz.answered = null;
      if (window.rerenderApp) window.rerenderApp();
    }
  }

  return { render, onClick };
})();
