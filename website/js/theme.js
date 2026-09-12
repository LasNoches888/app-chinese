// Applies a saved theme choice before first paint, everywhere in the app.
// Runs synchronously (no `defer`) so there's no flash of the wrong theme.
(function () {
  try {
    var t = localStorage.getItem('uchi_theme');
    if (t === 'light' || t === 'dark') document.documentElement.dataset.theme = t;
  } catch (e) {}
})();
