from datetime import datetime

from app.models import VocabCard
from app.srs import review_card


def make_card(**overrides) -> VocabCard:
    defaults = dict(
        id="1",
        user_id="u1",
        word="你好",
        pinyin="ni hao",
        translation="hello",
        due_date=datetime(2026, 1, 1),
        created_at=datetime(2026, 1, 1),
    )
    defaults.update(overrides)
    return VocabCard(**defaults)


def test_successful_review_increments_repetitions():
    card = make_card()
    now = datetime(2026, 1, 1)
    updated = review_card(card, quality=4, now=now)
    assert updated.repetitions == 1
    assert updated.interval_days == 1
    assert updated.due_date == datetime(2026, 1, 2)


def test_failed_review_resets_repetitions_and_marks_weak():
    card = make_card(repetitions=3, interval_days=15, ease_factor=2.6)
    updated = review_card(card, quality=1, now=datetime(2026, 1, 1))
    assert updated.repetitions == 0
    assert updated.interval_days == 1
    assert updated.weak is True


def test_interval_grows_with_repeated_good_reviews():
    now = datetime(2026, 1, 1)
    card = make_card()
    card = review_card(card, quality=5, now=now)
    assert card.interval_days == 1
    card = review_card(card, quality=5, now=now)
    assert card.interval_days == 6
    card = review_card(card, quality=5, now=now)
    assert card.interval_days > 6


def test_ease_factor_has_floor():
    card = make_card(ease_factor=1.3)
    updated = review_card(card, quality=0, now=datetime(2026, 1, 1))
    assert updated.ease_factor >= 1.3
