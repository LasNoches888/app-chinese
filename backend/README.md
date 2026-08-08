# AppChinese backend

FastAPI service: SRS (SM-2) vocab deck + AI chat tutor backed by a local
Qwen model served through an OpenAI-compatible API (Ollama / vLLM).

## Run

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Local LLM (Ollama)

```bash
ollama pull qwen2.5:7b-instruct
ollama serve   # OpenAI-compatible API on http://localhost:11434/v1
```

Env vars (all optional, defaults shown):

```
LLM_BASE_URL=http://localhost:11434/v1
LLM_MODEL=qwen2.5:7b-instruct
LLM_API_KEY=ollama
LLM_TIMEOUT_SECONDS=180
```

To switch to a hosted provider later, just point `LLM_BASE_URL`/`LLM_MODEL`/`LLM_API_KEY`
at it — `app/llm_client.py` only assumes an OpenAI-compatible `/chat/completions` endpoint.

## Tests

```bash
pytest
```

## Endpoints

- `POST /users/{user_id}/vocab` — add a word to the deck
- `GET /users/{user_id}/vocab/due` — cards due for review today
- `POST /users/{user_id}/vocab/review` — submit a review result (`quality` 0-5), recomputed via SM-2
- `GET /users/{user_id}/vocab` — full deck
- `POST /chat` — message the AI tutor, returns structured JSON
- `GET /health`

## Storage

`app/storage.py` is an in-memory data-access layer. It's the only module that
knows about card persistence; swapping it for SQLite/Postgres later doesn't
require touching `srs.py` or `main.py`.
