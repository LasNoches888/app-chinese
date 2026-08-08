from __future__ import annotations

from fastapi import FastAPI, HTTPException

from . import decks, llm_client, srs, stats, storage
from .models import (
    ChatRequest,
    ChatResponse,
    DeckSummary,
    ImportDeckRequest,
    ReviewRequest,
    UserStats,
    VocabCard,
    VocabCreate,
)

app = FastAPI(title="AppChinese API")

SYSTEM_PROMPT_TEMPLATE = """\
Ты — AI-репетитор китайского языка (普通话) по имени Xiao Qiao.
Твоя единственная задача — вести диалог с учеником так, чтобы он реально прогрессировал.

## Профиль ученика
- Уровень: HSK {hsk_level}
- Активный словарь (используй в первую очередь): {known_words}
- Слабые слова (аккуратно вплетай в диалог для повторения): {weak_words}

## Правила
1. Используй в основном слова из активного словаря ученика, не более 10-15% новых слов
   за сообщение. Новое слово сопровождай переводом в скобках при первом употреблении.
2. Говори естественными фразами носителя, упрощай лексику, не грамматику.
3. Ошибки не исправляй в лоб — переформулируй фразу ученика правильно в своём ответе (recast).
4. Держи реплики короткими (1-3 предложения).
5. Если ученик пишет не по-китайски, не переключайся на его язык — переспроси
   на упрощённом китайском.

## Формат ответа
Верни ТОЛЬКО валидный JSON без пояснений вокруг, по схеме:
{{
  "reply_zh": "реплика на китайском",
  "reply_pinyin": "пиньинь реплики",
  "new_words_used": [{{"word": "...", "pinyin": "...", "translation": "..."}}],
  "grammar_recast": "исправленный вариант фразы ученика или null"
}}
"""


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/users/{user_id}/vocab", response_model=VocabCard)
def add_vocab(user_id: str, body: VocabCreate):
    return storage.add_card(user_id, body.word, body.pinyin, body.translation)


@app.get("/users/{user_id}/vocab", response_model=list[VocabCard])
def list_vocab(user_id: str):
    return storage.all_cards_for_user(user_id)


@app.get("/users/{user_id}/vocab/due", response_model=list[VocabCard])
def due_vocab(user_id: str):
    return storage.due_cards_for_user(user_id)


@app.post("/users/{user_id}/vocab/review", response_model=VocabCard)
def review_vocab(user_id: str, body: ReviewRequest):
    card = storage.get_card(body.card_id)
    if card is None or card.user_id != user_id:
        raise HTTPException(status_code=404, detail="Card not found")
    updated = srs.review_card(card, body.quality)
    storage.save_card(updated)
    storage.log_review(user_id, body.quality)
    return updated


@app.get("/users/{user_id}/stats", response_model=UserStats)
def user_stats(user_id: str):
    cards = storage.all_cards_for_user(user_id)
    logs = storage.get_review_logs(user_id)
    return UserStats(
        total_words=len(cards),
        learned_words=len(srs.active_vocab(cards)),
        weak_words=len(srs.weak_vocab(cards)),
        reviews_today=stats.reviews_today(logs),
        streak_days=stats.compute_streak_days(logs),
        accuracy_percent=stats.compute_accuracy(logs),
    )


@app.get("/decks", response_model=list[DeckSummary])
def get_decks():
    return [DeckSummary(id=d.id, name=d.name, word_count=len(d.words)) for d in decks.list_decks()]


@app.post("/users/{user_id}/vocab/import-deck", response_model=list[VocabCard])
def import_deck(user_id: str, body: ImportDeckRequest):
    deck = decks.get_deck(body.deck_id)
    if deck is None:
        raise HTTPException(status_code=404, detail="Deck not found")
    added = [
        storage.add_card(user_id, w.word, w.pinyin, w.translation)
        for w in deck.words
        if not storage.word_exists(user_id, w.word)
    ]
    return added


@app.post("/chat", response_model=ChatResponse)
async def chat(body: ChatRequest):
    cards = storage.all_cards_for_user(body.user_id)
    known = ", ".join(c.word for c in srs.active_vocab(cards)) or "(пока пусто)"
    weak = ", ".join(c.word for c in srs.weak_vocab(cards)) or "(пока пусто)"

    system_prompt = SYSTEM_PROMPT_TEMPLATE.format(
        hsk_level=body.hsk_level, known_words=known, weak_words=weak
    )
    data = await llm_client.chat_completion_json(system_prompt, body.message)
    return ChatResponse(**data)
