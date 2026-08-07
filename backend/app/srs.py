"""SM-2 spaced-repetition scheduling.

Reference: SuperMemo SM-2 algorithm. quality is 0-5, where < 3 counts
as a failed review and resets repetitions/interval.
"""
from __future__ import annotations

from datetime import datetime, timedelta

from .models import VocabCard

MIN_EASE_FACTOR = 1.3


def review_card(card: VocabCard, quality: int, now: datetime | None = None) -> VocabCard:
    now = now or datetime.utcnow()

    if quality < 3:
        card.repetitions = 0
        card.interval_days = 1
        card.weak = True
    else:
        if card.repetitions == 0:
            card.interval_days = 1
        elif card.repetitions == 1:
            card.interval_days = 6
        else:
            card.interval_days = round(card.interval_days * card.ease_factor)
        card.repetitions += 1
        card.weak = False

    new_ef = card.ease_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    card.ease_factor = max(MIN_EASE_FACTOR, new_ef)

    card.due_date = now + timedelta(days=card.interval_days)
    return card


def active_vocab(cards: list[VocabCard]) -> list[VocabCard]:
    return [c for c in cards if c.repetitions >= 2 and not c.weak]


def weak_vocab(cards: list[VocabCard]) -> list[VocabCard]:
    return [c for c in cards if c.weak]
