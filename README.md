# AppChinese

MVP приложения для изучения китайского: SRS-словарь (SM-2) + текстовый чат с
AI-репетитором на локальной модели Qwen. Голос и коррекция тонов — не в этой
версии (архитектура зарезервирована под них на будущее).

- [`/backend`](backend) — FastAPI, нужен только для `/chat` (LLM-клиент)
- [`/mobile`](mobile) — Flutter, offline-first: уроки/SRS/XP/жизни/стрики/ачивки
  полностью локальные (SQLite), только чат требует backend
- [`/web`](web) — отдельное веб-приложение в стиле Duolingo (React + TS + Tailwind,
  без бэкенда, прогресс в localStorage) — независимый продукт, не связан с
  backend/mobile выше

## Быстрый старт (всё вместе)

### 1. Локальная модель

```bash
ollama pull qwen2.5:7b-instruct
ollama serve
```

Слушает OpenAI-совместимый API на `http://localhost:11434/v1`.

### 2. Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Проверка: `curl http://localhost:127.0.0.1:8000/health` → `{"status":"ok"}`.

Переопределить LLM (переменные окружения): `LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY`.

### 3. Mobile (Flutter) — offline-first

```bash
cd mobile
flutter pub get
flutter run
```

Приложение полностью рабочее для обучения без бэкенда/интернета — словарь
HSK1/2 зашит в APK, прогресс в локальной SQLite. Backend нужен только для
вкладки Чат: по умолчанию клиент ходит на `http://10.0.2.2:8000` (алиас
хоста для Android-эмулятора); для физического устройства поменяйте base URL
на экране Settings (например, IP машины в локальной сети).

### 4. Web (Duolingo-style, опционально, независимо от остального)

```bash
cd web
npm install
npm run dev
```

Полностью автономно — не требует backend/Ollama, весь прогресс в localStorage браузера.

## Тесты и линт

```bash
cd backend && pytest
cd mobile && flutter analyze && flutter test && flutter build apk --debug
cd web && npm run build && npm run lint
```

## Архитектурные заметки

- Хранилище словаря — in-memory (`backend/app/storage.py`), слой доступа к данным
  изолирован от бизнес-логики SM-2 и роутов, замена на SQLite/Postgres не требует
  переписывать `srs.py`/`main.py`.
- LLM-клиент (`backend/app/llm_client.py`) — тонкая обёртка над любым
  OpenAI-совместимым `/chat/completions` API (Ollama, vLLM, хостинг-провайдер) —
  провайдер не захардкожен, переключается через env.
- Голос/коррекция тонов не реализованы — оставлено для отдельного акустического
  сервиса в будущей итерации.
