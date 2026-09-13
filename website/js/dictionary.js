// "Словарь" section — search over the course's own word bank (the same
// website/data/words.json Courses uses). The mockup also shows a
// CC-CEDICT tab (124,000 entries) — that's the app's separate 29MB
// reference database, not something to ship to a browser tab, so that
// tab stays an honest "coming soon" rather than a silent no-op.
const Dictionary = (() => {
  let words = null;
  let loading = null;
  let query = '';
  let selectedId = null;

  function load() {
    if (loading) return loading;
    loading = fetch('data/words.json').then((r) => r.json()).then((w) => { words = w; });
    return loading;
  }

  function favorites() {
    try { return JSON.parse(localStorage.getItem('uchi_dictionary_favorites')) || []; } catch { return []; }
  }
  function toggleFavorite(id) {
    const favs = favorites();
    const i = favs.indexOf(id);
    if (i === -1) favs.push(id); else favs.splice(i, 1);
    try { localStorage.setItem('uchi_dictionary_favorites', JSON.stringify(favs)); } catch {}
  }

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

  const speakerIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="icon-sm"><path d="M4 9v6h4l5 4V5L8 9H4Z" stroke-linejoin="round"/><path d="M17 8.5a5 5 0 0 1 0 7" stroke-linecap="round"/></svg>';
  const starIcon = (filled) => `<svg viewBox="0 0 24 24" fill="${filled ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="1.8" class="icon-sm"><path d="m12 3 2.6 5.9 6.4.6-4.8 4.3 1.4 6.3L12 17l-5.6 3.1 1.4-6.3-4.8-4.3 6.4-.6L12 3Z" stroke-linejoin="round"/></svg>`;

  function esc(s) { return String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }

  function matches(w, q) {
    return w.hanzi.includes(q) || w.pinyin.toLowerCase().includes(q) || w.translation_ru.toLowerCase().includes(q);
  }

  function render() {
    if (!words) {
      load().then(() => { if (window.rerenderApp) window.rerenderApp(); });
      return `<div class="screen"><p style="color:var(--ink-faint)">Загрузка словаря…</p></div>`;
    }
    const q = query.trim().toLowerCase();
    const results = (q ? words.filter((w) => matches(w, q)) : words).slice(0, 60);
    const favs = favorites();
    const selected = words.find((w) => w.id === selectedId) || results[0] || words[0];

    return `
      <div class="screen">
        <h1 class="section__title" style="font-size:24px">Словарь</h1>
        <div class="dict-tabs">
          <button class="is-active">Слова курса</button>
          <button disabled title="Полный словарь — в приложении на телефоне">CC-CEDICT <span class="dash-card__badge" style="margin-top:0;margin-left:4px">скоро</span></button>
        </div>
        <div class="dict-search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" class="icon-sm"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3" stroke-linecap="round"/></svg>
          <input id="dictSearch" type="text" placeholder="Поиск слова, иероглифа, пиньиня..." value="${esc(query)}">
        </div>
        <div class="dict-layout">
          <div class="dict-list">
            ${results.length === 0 ? `<p style="color:var(--ink-faint);padding:12px">Ничего не нашлось</p>` : results.map((w) => `
              <button class="dict-row ${selected && w.id === selected.id ? 'is-active' : ''}" data-word="${w.id}">
                <div>
                  <div class="dict-row__hanzi">${w.hanzi}</div>
                  <div class="dict-row__pinyin">${w.pinyin}</div>
                </div>
                <span class="dict-row__star ${favs.includes(w.id) ? 'is-fav' : ''}" data-fav="${w.id}">${starIcon(favs.includes(w.id))}</span>
              </button>`).join('')}
          </div>
          <div class="dict-detail">
            ${selected ? `
              <div class="dict-detail__hanzi">${selected.hanzi} <button class="dcard__speak" ${zhVoice ? '' : 'disabled'} data-speak="${selected.hanzi}">${speakerIcon}</button></div>
              <div class="dict-detail__pinyin">${selected.pinyin}</div>
              <div class="dict-detail__ru">${selected.translation_ru}</div>
              ${selected.example_sentence ? `
                <div class="dsection__title" style="margin-top:20px">Пример</div>
                <div class="dcard" style="display:block">
                  <div class="dcard__hanzi">${selected.example_sentence}</div>
                  <div class="dcard__ru" style="margin-top:4px">${selected.example_translation || ''}</div>
                </div>` : ''}
              <button class="dbtn" style="background:var(--accent);color:var(--on-accent);margin-top:20px" data-fav="${selected.id}">${favs.includes(selected.id) ? 'В избранном ✓' : 'Добавить в избранное'}</button>
            ` : ''}
          </div>
        </div>
      </div>`;
  }

  function onClick(e) {
    const row = e.target.closest('[data-word]');
    if (row) { selectedId = row.getAttribute('data-word'); if (window.rerenderApp) window.rerenderApp(); return; }

    const fav = e.target.closest('[data-fav]');
    if (fav) { toggleFavorite(fav.getAttribute('data-fav')); if (window.rerenderApp) window.rerenderApp(); return; }

    const speakBtn = e.target.closest('[data-speak]');
    if (speakBtn) { speak(speakBtn.getAttribute('data-speak')); return; }
  }

  function onInput(e) {
    if (e.target.id === 'dictSearch') {
      query = e.target.value;
      if (window.rerenderApp) window.rerenderApp(true);
    }
  }

  return { render, onClick, onInput };
})();
