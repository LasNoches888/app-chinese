/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        tone1: '#e04b4b',
        tone2: '#e0a23c',
        tone3: '#3cb371',
        tone4: '#4a7ee0',
        tone5: '#9aa0a6',
      },
    },
  },
  plugins: [],
}
