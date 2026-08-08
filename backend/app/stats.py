"""Derived learner analytics computed from the review log."""
from __future__ import annotations

from datetime import date, datetime, timedelta

from .models import ReviewLogEntry


def compute_streak_days(logs: list[ReviewLogEntry], today: date | None = None) -> int:
    today = today or datetime.utcnow().date()
    review_days = {log.reviewed_at.date() for log in logs}
    streak = 0
    day = today
    while day in review_days:
        streak += 1
        day -= timedelta(days=1)
    return streak


def compute_accuracy(logs: list[ReviewLogEntry]) -> float:
    if not logs:
        return 0.0
    good = sum(1 for log in logs if log.quality >= 3)
    return round(good / len(logs) * 100, 1)


def reviews_today(logs: list[ReviewLogEntry], today: date | None = None) -> int:
    today = today or datetime.utcnow().date()
    return sum(1 for log in logs if log.reviewed_at.date() == today)
