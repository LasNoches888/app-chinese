from datetime import date, datetime, timedelta

from app.models import ReviewLogEntry
from app.stats import (
    compute_accuracy,
    compute_achievements,
    compute_level,
    compute_streak_days,
    compute_xp_today,
    compute_xp_total,
    reviews_today,
    xp_for_quality,
)


def entry(days_ago: int, quality: int, xp: int = 0) -> ReviewLogEntry:
    when = datetime(2026, 1, 10) - timedelta(days=days_ago)
    return ReviewLogEntry(quality=quality, reviewed_at=when, xp=xp)


def test_streak_counts_consecutive_days_ending_today():
    logs = [entry(0, 5), entry(1, 4), entry(2, 3)]
    assert compute_streak_days(logs, today=date(2026, 1, 10)) == 3


def test_streak_breaks_on_gap():
    logs = [entry(0, 5), entry(2, 4)]
    assert compute_streak_days(logs, today=date(2026, 1, 10)) == 1


def test_streak_zero_when_no_review_today():
    logs = [entry(1, 5)]
    assert compute_streak_days(logs, today=date(2026, 1, 10)) == 0


def test_accuracy_percent():
    logs = [entry(0, 5), entry(0, 4), entry(0, 1), entry(0, 0)]
    assert compute_accuracy(logs) == 50.0


def test_reviews_today_filters_by_date():
    logs = [entry(0, 5), entry(0, 3), entry(1, 4)]
    assert reviews_today(logs, today=date(2026, 1, 10)) == 2


def test_xp_for_quality_rewards_success_more_than_attempt():
    assert xp_for_quality(5) == 10
    assert xp_for_quality(3) == 10
    assert xp_for_quality(2) == 2
    assert xp_for_quality(0) == 2


def test_xp_total_and_today_sum_correctly():
    logs = [entry(0, 5, xp=10), entry(0, 2, xp=2), entry(1, 5, xp=10)]
    assert compute_xp_total(logs) == 22
    assert compute_xp_today(logs, today=date(2026, 1, 10)) == 12


def test_level_scales_with_xp():
    assert compute_level(0) == 1
    assert compute_level(99) == 1
    assert compute_level(100) == 2
    assert compute_level(250) == 3


def test_achievements_unlock_at_thresholds():
    unlocked = compute_achievements(reviews_total=1, streak_days=7, learned_words=10)
    assert "first_step" in unlocked
    assert "streak_7" in unlocked
    assert "words_10" in unlocked
    assert "streak_30" not in unlocked
    assert "words_50" not in unlocked
