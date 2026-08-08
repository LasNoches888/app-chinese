from datetime import date, datetime, timedelta

from app.models import ReviewLogEntry
from app.stats import compute_accuracy, compute_streak_days, reviews_today


def entry(days_ago: int, quality: int) -> ReviewLogEntry:
    when = datetime(2026, 1, 10) - timedelta(days=days_ago)
    return ReviewLogEntry(quality=quality, reviewed_at=when)


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
