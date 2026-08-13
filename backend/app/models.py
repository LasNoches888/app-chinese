from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class VocabCreate(BaseModel):
    word: str
    pinyin: str
    translation: str


class VocabCard(BaseModel):
    id: str
    user_id: str
    word: str
    pinyin: str
    translation: str
    repetitions: int = 0
    ease_factor: float = 2.5
    interval_days: int = 0
    due_date: datetime
    weak: bool = False
    created_at: datetime


class ReviewRequest(BaseModel):
    card_id: str
    quality: int = Field(ge=0, le=5)


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    user_id: str
    message: str
    hsk_level: int = 1
    # Optional local-vocabulary snapshot from an offline-first client (e.g.
    # the mobile app's on-device SRS data) — used in place of the
    # server-side vocab lookup when provided, since the client is the
    # source of truth for its own learning progress.
    known_words: Optional[list[str]] = None
    weak_words: Optional[list[str]] = None


class NewWord(BaseModel):
    word: str
    pinyin: str
    translation: str


class ChatResponse(BaseModel):
    reply_zh: str
    reply_pinyin: str
    new_words_used: list[NewWord] = []
    grammar_recast: Optional[str] = None


class ReviewLogEntry(BaseModel):
    quality: int
    reviewed_at: datetime
    xp: int = 0


class UserStats(BaseModel):
    total_words: int
    learned_words: int
    weak_words: int
    reviews_today: int
    streak_days: int
    accuracy_percent: float
    xp_total: int
    xp_today: int
    level: int
    daily_goal_xp: int
    achievements: list[str]


class DeckWord(BaseModel):
    word: str
    pinyin: str
    translation: str


class Deck(BaseModel):
    id: str
    name: str
    words: list[DeckWord]


class DeckSummary(BaseModel):
    id: str
    name: str
    word_count: int


class ImportDeckRequest(BaseModel):
    deck_id: str
