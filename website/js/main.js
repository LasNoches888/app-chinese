// Mobile nav toggle
const burger = document.getElementById('navBurger');
const navLinks = document.getElementById('navLinks');
if (burger && navLinks) {
  burger.addEventListener('click', () => {
    const open = navLinks.classList.toggle('is-open');
    burger.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
  navLinks.querySelectorAll('a').forEach((a) =>
    a.addEventListener('click', () => {
      navLinks.classList.remove('is-open');
      burger.setAttribute('aria-expanded', 'false');
    })
  );
}

// Scroll-reveal for every section below the hero (which has its own,
// always-on CSS entrance — see style.css). Uses IntersectionObserver, not
// GSAP/ScrollTrigger: the trigger condition (visible or not) is exactly
// what the DOM/CSSOM already tracks, so there's no separate animation
// ticker that could stall and leave content permanently hidden.
document.querySelectorAll('section:not(.hero) > .wrap > *').forEach((el) => {
  el.classList.add('reveal');
});

const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if ('IntersectionObserver' in window && !prefersReducedMotion) {
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.15 }
  );
  document.querySelectorAll('.reveal').forEach((el) => io.observe(el));
} else {
  document.querySelectorAll('.reveal').forEach((el) => el.classList.add('is-visible'));
}

// Nav bar picks up a background/shadow only once the hero has scrolled
// past — kept out of CSS since it depends on scroll position, not state.
const nav = document.getElementById('nav');
if (nav) {
  const onScroll = () => nav.classList.toggle('is-scrolled', window.scrollY > 8);
  document.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}
