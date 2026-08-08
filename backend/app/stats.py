"""Derived learner analytics computed from the review log."""
from __future__ import annotations

from datetime import date, datetime, timedelta

from .models import ReviewLogEntry

DAILY_GOAL_XP = 30
XP_PER_SUCCESS = 10
XP_PER_ATTEMPT = 2

ACHIEVEMENT_THRESHOLDS = {
    "first_step": lambda reviews, streak, learned: reviews >= 1,
    "streak_3": lambda reviews, streak, learned: streak >= 3,
    "streak_7": lambda reviews, streak, learned: streak >= 7,
    "streak_30": lambda reviews, streak, learned: streak >= 30,
    "words_10": lambda reviews, streak, learned: learned >= 10,
    "words_50": lambda reviews, streak, learned: learned >= 50,
    "words_100": lambda reviews, streak, learned: learned >= 100,
    "reviews_100": lambda reviews, streak, learned: reviews >= 100,
}


def xp_for_quality(quality: int) -> int:
    return XP_PER_SUCCESS if quality >= 3 else XP_PER_ATTEMPT


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


def compute_xp_total(logs: list[ReviewLogEntry]) -> int:
    return sum(log.xp for log in logs)


def compute_xp_today(logs: list[ReviewLogEntry], today: date | None = None) -> int:
    today = today or datetime.utcnow().date()
    return sum(log.xp for log in logs if log.reviewed_at.date() == today)


def compute_level(xp_total: int) -> int:
    return xp_total // 100 + 1


def compute_achievements(reviews_total: int, streak_days: int, learned_words: int) -> list[str]:
    return [
        achievement_id
        for achievement_id, check in ACHIEVEMENT_THRESHOLDS.items()
        if check(reviews_total, streak_days, learned_words)
    ]
