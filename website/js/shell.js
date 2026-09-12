// Shared desktop-shell chrome (sidebar + top bar), injected by every app
// page (dialects.html, app.html) so there's one nav to keep in sync
// instead of copies drifting apart. Visible only >=1024px — see
// css/shell.css; below that every page falls back to its own mobile
// appbar, already built and tested separately.
function renderSidebar(activeKey) {
  const items = [
    { key: 'home', href: 'app.html#/home', label: 'Главная',
      icon: '<path d="M4 11 12 4l8 7" stroke-linecap="round" stroke-linejoin="round"/><path d="M6 10v9h12v-9" stroke-linecap="round" stroke-linejoin="round"/>' },
    { key: 'lessons', href: 'app.html#/lessons', label: 'Курсы',
      icon: '<path d="M4 5.5C4 4.7 4.7 4 5.5 4H14v16H5.5A1.5 1.5 0 0 1 4 18.5v-13Z" stroke-linejoin="round"/><path d="M14 4h4.5C19.3 4 20 4.7 20 5.5v13c0 .8-.7 1.5-1.5 1.5H14" stroke-linejoin="round"/>' },
    { key: 'dialects', href: 'dialects.html', label: 'Диалекты',
      icon: '<path d="M12 21s7-6.1 7-11.5S16.4 3 12 3 5 5.6 5 9.5 12 21 12 21Z" stroke-linejoin="round"/><circle cx="12" cy="9.5" r="2.5"/>' },
    { key: 'dictionary', href: 'app.html#/dictionary', label: 'Словарь',
      icon: '<path d="M4 5.5C4 4.7 4.7 4 5.5 4H19v16H5.5A1.5 1.5 0 0 1 4 18.5v-13Z" stroke-linejoin="round"/><path d="M8 8h7M8 12h7" stroke-linecap="round"/>' },
    { key: 'chat', href: 'app.html#/chat', label: 'Чат',
      icon: '<path d="M4 12c0-4.4 3.6-8 8-8s8 3.6 8 8-3.6 8-8 8c-1.1 0-2.2-.2-3.1-.6L4 21l1.7-4.6C4.6 15 4 13.6 4 12Z" stroke-linejoin="round" stroke-linecap="round"/>' },
    { key: 'profile', href: 'app.html#/profile', label: 'Профиль',
      icon: '<circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.9 3.1-7 7-7s7 3.1 7 7" stroke-linecap="round"/>' },
  ];
  const links = items.map((it) => `
    <a href="${it.href}" data-key="${it.key}" class="${it.key === activeKey ? 'is-active' : ''}">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">${it.icon}</svg>
      ${it.label}
    </a>`).join('');

  return `
    <a href="index.html" class="sidebar__brand">
      <img src="assets/app-icon.png" alt="">
      <span>Uchi</span>
    </a>
    <nav class="sidebar__nav">${links}</nav>`;
}

// Below 1024px the sidebar (rendered above) is hidden by CSS and this
// bar takes over — same nav items, a hamburger instead of a permanent
// rail, since dialects.html's per-screen appbar already gets you *back*
// to app.html#/home but nothing on mobile could get you sideways to
// Курсы/Словарь/Профиль without this.
function renderMobileTopbar(activeKey) {
  return `
    <div class="mobile-topbar">
      <a href="index.html" class="sidebar__brand">
        <img src="assets/app-icon.png" alt="">
        <span>Uchi</span>
      </a>
      <button class="nav__burger" id="shellBurger" aria-label="Меню" aria-expanded="false">
        <span></span><span></span><span></span>
      </button>
    </div>
    <nav class="mobile-nav" id="shellMobileNav">${renderSidebar(activeKey)}</nav>`;
}

// Fills a stable <div id="sidebarRoot" class="sidebar"> — deliberately
// innerHTML, not outerHTML: replacing the element itself would destroy
// the id, so every render after the first would silently find nothing
// to mount into and the sidebar would never update its active item again.
function mountShell(activeKey) {
  const root = document.getElementById('sidebarRoot');
  if (root) root.innerHTML = renderSidebar(activeKey);

  const mobileRoot = document.getElementById('mobileShellRoot');
  if (mobileRoot) {
    mobileRoot.innerHTML = renderMobileTopbar(activeKey);
    const burger = document.getElementById('shellBurger');
    const menu = document.getElementById('shellMobileNav');
    burger.addEventListener('click', () => {
      const open = menu.classList.toggle('is-open');
      burger.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    menu.querySelectorAll('a').forEach((a) => a.addEventListener('click', () => menu.classList.remove('is-open')));
  }
}
