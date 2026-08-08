"""Data access layer for vocab cards.

In-memory dict for the MVP. Swap this module's internals for a
SQLite/Postgres-backed implementation later without touching main.py
or srs.py — callers only use the functions below.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from .models import ReviewLogEntry, VocabCard

_cards: dict[str, VocabCard] = {}
_review_logs: dict[str, list[ReviewLogEntry]] = {}


def add_card(user_id: str, word: str, pinyin: str, translation: str) -> VocabCard:
    now = datetime.utcnow()
    card = VocabCard(
        id=str(uuid.uuid4()),
        user_id=user_id,
        word=word,
        pinyin=pinyin,
        translation=translation,
        due_date=now,
        created_at=now,
    )
    _cards[card.id] = card
    return card


def get_card(card_id: str) -> VocabCard | None:
    return _cards.get(card_id)


def all_cards_for_user(user_id: str) -> list[VocabCard]:
    return [c for c in _cards.values() if c.user_id == user_id]


def due_cards_for_user(user_id: str, now: datetime | None = None) -> list[VocabCard]:
    now = now or datetime.utcnow()
    return [c for c in all_cards_for_user(user_id) if c.due_date <= now]


def save_card(card: VocabCard) -> None:
    _cards[card.id] = card


def word_exists(user_id: str, word: str) -> bool:
    return any(c.word == word for c in all_cards_for_user(user_id))


def log_review(user_id: str, quality: int, xp: int = 0, when: datetime | None = None) -> None:
    when = when or datetime.utcnow()
    _review_logs.setdefault(user_id, []).append(
        ReviewLogEntry(quality=quality, reviewed_at=when, xp=xp)
    )


def get_review_logs(user_id: str) -> list[ReviewLogEntry]:
    return _review_logs.get(user_id, [])
