// A hash-routed mini-app for the Dialects section — the first slice of
// "learn on the site, not just read about it" (see project notes on
// site/app parity). Progress lives in localStorage: no account yet, so
// nothing here claims to sync with the phone app. That's the honest
// state until real accounts+sync land on top of this same screen.
const STORAGE_KEY = 'uchi_dialect_progress';
const app = document.getElementById('app');

function loadProgress() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}; } catch { return {}; }
}
function saveProgress(p) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(p)); } catch {}
}
function markDone(dialectId, kind) {
  const p = loadProgress();
  p[dialectId] = p[dialectId] || {};
  p[dialectId][kind] = true;
  saveProgress(p);
}
function isDone(dialectId, kind) {
  return !!(loadProgress()[dialectId] || {})[kind];
}

// ---- Mandarin speech: Web Speech API, offered only if the browser
// actually reports a zh voice — same "don't promise audio you can't
// deliver" rule as the app's SpeakButton. ----
let zhVoice = null;
function refreshVoices() {
  if (!('speechSynthesis' in window)) return;
  const v = speechSynthesis.getVoices().find((v) => v.lang && v.lang.toLowerCase().startsWith('zh'));
  zhVoice = v || null;
}
if ('speechSynthesis' in window) {
  refreshVoices();
  speechSynthesis.onvoiceschanged = () => { refreshVoices(); render(); };
}
function speak(text) {
  if (!zhVoice) return;
  speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.voice = zhVoice;
  u.lang = 'zh-CN';
  u.rate = 0.85;
  speechSynthesis.speak(u);
}

// ---- Icons ----
const ICON = {
  chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="icon-sm"><path d="m9 18 6-6-6-6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="icon-sm"><path d="m15 18-6-6 6-6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="icon-sm"><path d="M20 6 9 17l-5-5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  speaker: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="icon-sm"><path d="M4 9v6h4l5 4V5L8 9H4Z" stroke-linejoin="round"/><path d="M17 8.5a5 5 0 0 1 0 7" stroke-linecap="round"/></svg>',
  book: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="icon-sm"><path d="M4 5.5C4 4.7 4.7 4 5.5 4H14v16H5.5A1.5 1.5 0 0 1 4 18.5v-13Z"/><path d="M14 4h4.5C19.3 4 20 4.7 20 5.5v13c0 .8-.7 1.5-1.5 1.5H14"/></svg>',
  chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="icon-sm"><path d="M4 12c0-4.4 3.6-8 8-8s8 3.6 8 8-3.6 8-8 8c-1.1 0-2.2-.2-3.1-.6L4 21l1.7-4.6C4.6 15 4 13.6 4 12Z" stroke-linejoin="round" stroke-linecap="round"/></svg>',
  person: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="icon-sm"><circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.9 3.1-7 7-7s7 3.1 7 7" stroke-linecap="round"/></svg>',
  feature: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="icon-sm"><path d="M20 6 9 17l-5-5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
};

function esc(s) { return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
function dialect(id) { return DIALECTS.find((d) => d.id === id); }

// ---- Top bar ----
function appbar(title, sub, backHash) {
  return `<div class="appbar">
    <a class="appbar__back" href="${backHash}">${ICON.back}</a>
    <div class="appbar__title">${esc(title)}${sub ? `<small>${esc(sub)}</small>` : ''}</div>
  </div>`;
}

// ---- Screens ----
function renderList() {
  const rows = DIALECTS.map((d) => `
    <div class="dlegend__row" data-nav="#/d/${d.id}">
      <span class="dlegend__dot" style="background:${d.color}"></span>
      <span class="dlegend__name">${esc(d.nameRu)}</span>
      <span class="dlegend__region">${esc(d.regionRu)}</span>
      <span class="dlegend__chevron">${ICON.chevron}</span>
    </div>`).join('');
  return `
    ${appbar('Диалекты Китая', null, 'app.html#/home')}
    <div class="screen">
      <p style="color:var(--ink-soft)">7 регионов — 7 уникальных культур, языков и традиций. Нажмите на диалект, чтобы узнать больше и пройти его на сайте.</p>
      <p style="color:var(--ink-faint);font-size:13px;margin-top:8px">Прогресс пока сохраняется только в этом браузере — аккаунт и синхронизация с приложением ещё не подключены.</p>
      <div class="dlegend">${rows}</div>
      <button class="dbtn" style="background:var(--ink);color:var(--bg);margin-top:20px" data-nav="#/compare">Сравнить произношение</button>
    </div>`;
}

function renderDetail(id) {
  const d = dialect(id);
  if (!d) return renderList();
  const examples = d.examples.map((e) => `
    <div class="dcard">
      <div>
        <div class="dcard__hanzi">${esc(e.hanzi)}</div>
        ${e.reading ? `<div class="dcard__reading">${esc(e.reading)}</div>` : ''}
        <div class="dcard__ru">${esc(e.ru)}</div>
      </div>
      <button class="dcard__speak" ${d.hasAudio && zhVoice ? '' : 'disabled'} data-speak="${esc(e.hanzi)}">${ICON.speaker}</button>
    </div>`).join('');
  return `
    ${appbar(d.nameRu, null, '#/')}
    <div class="screen">
      <div class="dhead" style="background:${d.color}">
        <div class="dhead__top">
          <div class="dhead__name">${esc(d.nameRu)}</div>
          <div class="dhead__tag">${esc(d.nativeName)} · ${esc(d.romanization)}</div>
        </div>
        <div class="dhead__region">${esc(d.regionRu)}</div>
        <div class="dhead__desc">${esc(d.descriptionRu)}</div>
      </div>

      <div class="dsection">
        <div class="dsection__title">Особенности</div>
        ${d.featuresRu.map((f) => `<div class="dfeature">${ICON.feature}<span>${esc(f)}</span></div>`).join('')}
      </div>

      <div class="dsection">
        <div class="dsection__title">Примеры</div>
        ${examples}
      </div>

      <div class="dsection">
        <div class="dteaser" data-nav="#/d/${d.id}/culture">
          <div class="dteaser__icon" style="background:${d.color}22;color:${d.color}">${ICON.book}</div>
          <div class="dteaser__title">Культура и традиции</div>
          ${ICON.chevron}
        </div>
      </div>

      <button class="dbtn" style="background:${d.color}" data-nav="#/d/${d.id}/lessons">Изучить диалект</button>
    </div>`;
}

function renderLessons(id) {
  const d = dialect(id);
  if (!d) return renderList();
  const done = loadProgress()[d.id] || {};
  const tiles = [
    { kind: 'examples', icon: ICON.chat, title: 'Примеры и фразы', sub: `${d.examples.length}`, nav: `#/d/${d.id}/study` },
    { kind: 'culture', icon: ICON.book, title: 'Культура и особенности', sub: d.cultureTitleRu, nav: `#/d/${d.id}/culture` },
  ];
  if (d.dialogue) tiles.push({ kind: 'practice', icon: ICON.chat, title: 'Мини-диалог', sub: `${d.dialogue.length}`, nav: `#/d/${d.id}/practice` });
  return `
    ${appbar(d.nameRu, 'Уроки и материалы', `#/d/${d.id}`)}
    <div class="screen">
      ${tiles.map((t) => `
        <div class="ltile" data-nav="${t.nav}">
          <div class="ltile__icon" style="background:${d.color}22;color:${d.color}">${t.icon}</div>
          <div style="flex:1">
            <div class="ltile__title">${esc(t.title)}</div>
            <div class="ltile__sub">${esc(t.sub)}</div>
          </div>
          ${done[t.kind] ? `<span class="ltile__done">${ICON.check}</span>` : ICON.chevron}
        </div>`).join('')}
    </div>`;
}

let fcIndex = 0;
function renderStudy(id) {
  const d = dialect(id);
  if (!d) return renderList();
  const e = d.examples[fcIndex];
  return `
    ${appbar(d.nameRu, null, `#/d/${d.id}/lessons`)}
    <div class="screen fc-screen">
      <div>
        <div class="fc-progress"><div class="fc-progress__bar" style="width:${((fcIndex + 1) / d.examples.length) * 100}%;background:${d.color}"></div></div>
        <div class="fc-count">${fcIndex + 1} / ${d.examples.length}</div>
      </div>
      <div class="fc-card">
        <div class="fc-card__hanzi">${esc(e.hanzi)} ${d.hasAudio && zhVoice ? `<button class="dcard__speak" data-speak="${esc(e.hanzi)}">${ICON.speaker}</button>` : ''}</div>
        ${e.reading ? `<div class="fc-card__reading">${esc(e.reading)}</div>` : ''}
        <div class="fc-card__ru">${esc(e.ru)}</div>
      </div>
      <div class="fc-actions">
        <button class="no" data-fc-next="${id}">Не знал</button>
        <button class="yes" style="background:${d.color}" data-fc-next="${id}">Знал</button>
      </div>
    </div>`;
}

function renderCulture(id) {
  const d = dialect(id);
  if (!d) return renderList();
  markDone(d.id, 'culture');
  const vocab = d.cultureVocab.map((v) => `
    <div class="dcard">
      <div style="display:flex;align-items:center;gap:10px;width:100%">
        <span class="dcard__hanzi">${esc(v.hanzi)}</span>
        ${v.reading ? `<span class="dcard__reading" style="margin-top:0">${esc(v.reading)}</span>` : ''}
        <span style="margin-left:auto;font-size:14px">${esc(v.ru)}</span>
      </div>
    </div>`).join('');
  return `
    ${appbar('Культура и традиции', null, `#/d/${d.id}/lessons`)}
    <div class="screen">
      <div class="dhead" style="background:${d.color}">
        <div class="dhead__name" style="font-size:20px">${esc(d.cultureTitleRu)}</div>
      </div>
      <p style="margin-top:18px;line-height:1.5">${esc(d.cultureBodyRu)}</p>
      <div class="dsection">
        <div class="dsection__title">Полезные слова</div>
        ${vocab}
      </div>
    </div>`;
}

let pShown = 1;
function renderPractice(id) {
  const d = dialect(id);
  if (!d || !d.dialogue) return renderList();
  const lines = d.dialogue.slice(0, pShown).map((l) => `
    <div class="pline ${l.speaker}">
      <div class="pline__avatar">${l.speaker === 'mascot' ? '<img src="assets/mascot/panda_02.png" alt="">' : ICON.person}</div>
      <div class="pline__bubble" style="${l.speaker === 'learner' ? `background:${d.color}` : ''}">
        <div class="pline__hanzi">${esc(l.hanzi)} ${l.speaker === 'mascot' && zhVoice ? `<button class="dcard__speak" style="padding:0" data-speak="${esc(l.hanzi)}">${ICON.speaker}</button>` : ''}</div>
        ${l.reading ? `<div class="pline__reading">${esc(l.reading)}</div>` : ''}
        <div class="pline__ru">${esc(l.ru)}</div>
      </div>
    </div>`).join('');
  const isLast = pShown >= d.dialogue.length;
  return `
    ${appbar('Мини-диалог', null, `#/d/${d.id}/lessons`)}
    <div class="screen p-screen">
      <div class="fc-progress"><div class="fc-progress__bar" style="width:${(pShown / d.dialogue.length) * 100}%;background:${d.color}"></div></div>
      <div class="plines-wrap" style="margin-top:20px">${lines}</div>
      <button class="dbtn" style="background:${d.color}" data-practice-next="${id}">${isLast ? 'Продолжить' : 'Далее'}</button>
    </div>`;
}

function renderComplete(id, count) {
  const d = dialect(id);
  if (!d) return renderList();
  return `
    ${appbar('Готово', null, `#/d/${d.id}/lessons`)}
    <div class="screen">
      <div class="complete">
        <img src="assets/mascot/panda_04.png" alt="">
        <h2>Отличная работа!</h2>
        <p>Вы прошли раздел</p>
        <div class="complete-stat">
          <span style="display:flex;align-items:center;gap:8px"><span class="dlegend__dot" style="background:${d.color}"></span>${esc(d.nameRu)}</span>
          <b>${count} фраз</b>
        </div>
        <button class="dbtn" style="background:${d.color}" data-nav="#/d/${d.id}/lessons">Продолжить</button>
        <button class="dbtn" style="background:none;border:2px solid var(--line);color:var(--ink)" data-nav="#/">К списку диалектов</button>
      </div>
    </div>`;
}

function renderCompare() {
  const cards = COMPARE.map((c) => `
    <div class="cmp-card">
      <div class="cmp-card__label">${esc(c.ru)}</div>
      <div class="cmp-cols">
        <div><div class="cmp-cols__name" style="color:#3F5A7A">Мандарин</div><div class="cmp-cols__hanzi">${esc(c.hanziMandarin)}</div><div class="cmp-cols__reading">${esc(c.pinyin)}</div></div>
        <div><div class="cmp-cols__name" style="color:#A85A32">Кантонский</div><div class="cmp-cols__hanzi">${esc(c.hanziYue)}</div><div class="cmp-cols__reading">${esc(c.jyutping)}</div></div>
        <div><div class="cmp-cols__name" style="color:#7A4A63">Мин</div><div class="cmp-cols__hanzi">${esc(c.hanziMin)}</div><div class="cmp-cols__reading">${esc(c.poj)}</div></div>
      </div>
      <div class="cmp-tip">💡 <span>${esc(c.tipRu)}</span></div>
    </div>`).join('');
  return `
    ${appbar('Сравнение произношения', null, '#/')}
    <div class="screen">
      <p style="color:var(--ink-soft)">Одни и те же иероглифы, три реальных, задокументированных чтения.</p>
      <div style="margin-top:16px">${cards}</div>
    </div>`;
}

// ---- Router ----
function render() {
  const hash = location.hash || '#/';
  const parts = hash.replace(/^#\//, '').split('/').filter(Boolean);
  let html;
  if (parts[0] === 'compare') html = renderCompare();
  else if (parts[0] === 'd' && parts[1]) {
    const id = parts[1];
    const sub = parts[2];
    if (!sub) html = renderDetail(id);
    else if (sub === 'lessons') html = renderLessons(id);
    else if (sub === 'study') { fcIndex = 0; html = renderStudy(id); }
    else if (sub === 'culture') html = renderCulture(id);
    else if (sub === 'practice') { pShown = 1; html = renderPractice(id); }
    else if (sub === 'complete') html = renderComplete(id, Number(parts[3] || 0));
    else html = renderDetail(id);
  } else {
    html = renderList();
  }
  app.innerHTML = html;
  if (window.mountShell) mountShell('dialects');
  window.scrollTo(0, 0);
}

app.addEventListener('click', (e) => {
  const nav = e.target.closest('[data-nav]');
  if (nav) { location.hash = nav.getAttribute('data-nav'); return; }

  const speakBtn = e.target.closest('[data-speak]');
  if (speakBtn) { speak(speakBtn.getAttribute('data-speak')); return; }

  const fcNext = e.target.closest('[data-fc-next]');
  if (fcNext) {
    const id = fcNext.getAttribute('data-fc-next');
    const d = dialect(id);
    if (fcIndex + 1 < d.examples.length) { fcIndex++; app.innerHTML = renderStudy(id); }
    else { markDone(id, 'examples'); location.hash = `#/d/${id}/complete/${d.examples.length}`; }
    return;
  }

  const pNext = e.target.closest('[data-practice-next]');
  if (pNext) {
    const id = pNext.getAttribute('data-practice-next');
    const d = dialect(id);
    if (pShown < d.dialogue.length) { pShown++; app.innerHTML = renderPractice(id); }
    else { markDone(id, 'practice'); location.hash = `#/d/${id}/complete/${d.dialogue.length}`; }
    return;
  }
});

window.addEventListener('hashchange', render);
render();
