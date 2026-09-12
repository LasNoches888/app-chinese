// Router for the desktop-shell sections. Dialects keeps its own page
// (dialects.html) since it predates this shell and already works well;
// everything else — Home, Courses, Dictionary, Profile — lives here and
// delegates to its own module (courses.js / dictionary.js) once a
// section is more than a couple of static blocks.
const app = document.getElementById('app');

function dialectProgressSummary() {
  let data = {};
  try { data = JSON.parse(localStorage.getItem('uchi_dialect_progress')) || {}; } catch {}
  const names = { mandarin: 'Мандарин', wu: 'У', yue: 'Юэ', min: 'Мин', hakka: 'Хакка', xiang: 'Сян', gan: 'Гань' };
  return Object.keys(data)
    .filter((id) => Object.keys(data[id] || {}).length)
    .map((id) => ({ id, name: names[id] || id, kinds: Object.keys(data[id]) }));
}
function courseProgressSummary() {
  try { return Object.keys(JSON.parse(localStorage.getItem('uchi_course_progress')) || {}); } catch { return []; }
}

function renderHome() {
  const dialectProgress = dialectProgressSummary();
  const coursesDone = courseProgressSummary();
  return `
    <div class="screen">
      <div class="dash-hero">
        <div>
          <h1 class="dash-hero__title">Китайский язык ближе, чем кажется</h1>
          <p class="dash-hero__sub">Учись в своём темпе — офлайн, с умным помощником и милыми компаньонами.</p>
          <a href="#/lessons" class="dbtn" style="display:inline-block;width:auto;padding:13px 26px;margin-top:16px;background:var(--blue)">Начать обучение</a>
        </div>
        <img src="assets/mascot/panda_04.png" alt="">
      </div>

      <div class="dash-grid">
        <a class="dash-card" href="#/lessons">
          <div class="dash-card__icon" style="background:color-mix(in srgb, var(--blue) 16%, transparent);color:var(--blue)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="20" height="20"><path d="M4 5.5C4 4.7 4.7 4 5.5 4H14v16H5.5A1.5 1.5 0 0 1 4 18.5v-13Z" stroke-linejoin="round"/><path d="M14 4h4.5C19.3 4 20 4.7 20 5.5v13c0 .8-.7 1.5-1.5 1.5H14" stroke-linejoin="round"/></svg>
          </div>
          <div class="dash-card__title">Уроки</div>
          <div class="dash-card__sub">Изучай новые слова и грамматику</div>
        </a>
        <a class="dash-card" href="dialects.html">
          <div class="dash-card__icon" style="background:color-mix(in srgb, var(--purple) 16%, transparent);color:var(--purple)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="20" height="20"><path d="M12 21s7-6.1 7-11.5S16.4 3 12 3 5 5.6 5 9.5 12 21 12 21Z" stroke-linejoin="round"/><circle cx="12" cy="9.5" r="2.5"/></svg>
          </div>
          <div class="dash-card__title">Диалекты</div>
          <div class="dash-card__sub">Погрузись в культуру разных регионов</div>
        </a>
        <a class="dash-card" href="#/dictionary">
          <div class="dash-card__icon" style="background:color-mix(in srgb, var(--green) 16%, transparent);color:var(--green-dark)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="20" height="20"><path d="M4 5.5C4 4.7 4.7 4 5.5 4H19v16H5.5A1.5 1.5 0 0 1 4 18.5v-13Z" stroke-linejoin="round"/><path d="M8 8h7M8 12h7" stroke-linecap="round"/></svg>
          </div>
          <div class="dash-card__title">Словарь</div>
          <div class="dash-card__sub">Слова курса и примеры</div>
        </a>
        <div class="dash-card is-soon">
          <div class="dash-card__icon" style="background:color-mix(in srgb, var(--orange) 16%, transparent);color:var(--orange)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" width="20" height="20"><path d="M4 12c0-4.4 3.6-8 8-8s8 3.6 8 8-3.6 8-8 8c-1.1 0-2.2-.2-3.1-.6L4 21l1.7-4.6C4.6 15 4 13.6 4 12Z" stroke-linejoin="round" stroke-linecap="round"/></svg>
          </div>
          <div class="dash-card__title">Чат</div>
          <div class="dash-card__sub">Твой личный репетитор на базе ИИ</div>
          <div class="dash-card__badge">Скоро на сайте</div>
        </div>
      </div>

      <div class="dash-progress">
        <div class="dsection__title" style="margin-bottom:12px">Твой прогресс на сайте</div>
        ${dialectProgress.length === 0 && coursesDone.length === 0
          ? `<p class="dash-progress__empty">Пока пусто — начни с <a href="#/lessons" style="color:var(--blue);font-weight:600">урока</a> или <a href="dialects.html" style="color:var(--blue);font-weight:600">диалектов</a>. Это прогресс именно в этом браузере — с приложением на телефоне он пока не синхронизирован.</p>`
          : `
            ${coursesDone.length ? `<div class="dash-progress__row"><span>Пройдено тем</span><span style="color:var(--ink-faint);font-size:13px">${coursesDone.length}</span></div>` : ''}
            ${dialectProgress.map((p) => `<div class="dash-progress__row"><span>${p.name}</span><span style="color:var(--ink-faint);font-size:13px">${p.kinds.length} из 3 разделов</span></div>`).join('')}
          `}
      </div>
    </div>`;
}

function renderSoon(title, desc) {
  return `
    <div class="screen">
      <div class="soon">
        <img src="assets/mascot/panda_02.png" alt="">
        <h2>${title}</h2>
        <p>${desc}</p>
      </div>
    </div>`;
}

function loadTheme() {
  try { return localStorage.getItem('uchi_theme') || 'auto'; } catch { return 'auto'; }
}
function setTheme(value) {
  try {
    if (value === 'auto') { localStorage.removeItem('uchi_theme'); delete document.documentElement.dataset.theme; }
    else { localStorage.setItem('uchi_theme', value); document.documentElement.dataset.theme = value; }
  } catch {}
}

function renderProfile() {
  const current = loadTheme();
  const seg = (value, label) => `<button data-theme-set="${value}" class="${current === value ? 'is-active' : ''}">${label}</button>`;
  const dialectProgress = dialectProgressSummary();
  const coursesDone = courseProgressSummary();
  return `
    <div class="screen">
      <h1 class="section__title" style="font-size:24px">Профиль</h1>
      <div class="settings-group" style="margin-top:20px">
        <div class="settings-row">
          <div>
            <div class="settings-row__label">Тема оформления</div>
            <div class="settings-row__sub">Действует только на сайте в этом браузере</div>
          </div>
          <div class="seg">${seg('light', 'Светлая')}${seg('dark', 'Тёмная')}${seg('auto', 'Авто')}</div>
        </div>
      </div>
      <div class="dsection__title" style="margin:24px 0 12px">Прогресс в браузере</div>
      <div class="dash-progress" style="margin-top:0">
        ${dialectProgress.length === 0 && coursesDone.length === 0
          ? `<p class="dash-progress__empty">Пока пусто.</p>`
          : `
            ${coursesDone.length ? `<div class="dash-progress__row"><span>Тем по курсу пройдено</span><span style="color:var(--ink-faint);font-size:13px">${coursesDone.length}</span></div>` : ''}
            ${dialectProgress.map((p) => `<div class="dash-progress__row"><span>${p.name}</span><span style="color:var(--ink-faint);font-size:13px">${p.kinds.length} из 3 разделов</span></div>`).join('')}
          `}
      </div>
      <p style="color:var(--ink-faint);font-size:13px;margin-top:16px">Аккаунт и синхронизация с приложением на телефоне появятся здесь позже — пока это отдельный, локальный прогресс.</p>
    </div>`;
}

function render() {
  const hash = location.hash || '#/home';
  const parts = hash.replace(/^#\//, '').split('/');
  const key = parts[0] || 'home';
  document.body.dataset.section = key;
  let html;
  switch (key) {
    case 'home': html = renderHome(); break;
    case 'lessons': html = Courses.render(parts); break;
    case 'dictionary': html = Dictionary.render(); break;
    case 'chat': html = renderSoon('ИИ-репетитор скоро появится на сайте', 'Живой чат с репетитором требует своего сервера — мы его ещё не подняли. Пока доступен в приложении на телефоне.'); break;
    case 'profile': html = renderProfile(); break;
    default: html = renderHome();
  }
  app.innerHTML = html;
  if (window.mountShell) mountShell(document.body.dataset.section);
}

// Re-render without losing focus/caret in a live text input (the
// dictionary search box) — a plain innerHTML swap on every keystroke
// would otherwise kick focus out after each character typed.
window.rerenderApp = function (preserveFocus) {
  const active = preserveFocus ? document.activeElement : null;
  const id = active && active.id;
  const selStart = active && 'selectionStart' in active ? active.selectionStart : null;
  render();
  if (id) {
    const el = document.getElementById(id);
    if (el) {
      el.focus();
      if (selStart !== null && el.setSelectionRange) el.setSelectionRange(selStart, selStart);
    }
  }
};

app.addEventListener('click', (e) => {
  const section = document.body.dataset.section;
  if (section === 'lessons') return Courses.onClick(e);
  if (section === 'dictionary') return Dictionary.onClick(e);

  const themeBtn = e.target.closest('[data-theme-set]');
  if (themeBtn) { setTheme(themeBtn.getAttribute('data-theme-set')); render(); }
});

app.addEventListener('input', (e) => {
  if (document.body.dataset.section === 'dictionary') Dictionary.onInput(e);
});

window.addEventListener('hashchange', render);
render();
