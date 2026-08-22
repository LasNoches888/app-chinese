"""Builds the shipped dictionary database from the parsed + translated CC-CEDICT.

The dictionary is read-only reference data, so it ships as a prebuilt
SQLite file copied out of assets on first run rather than being seeded
row-by-row at startup: 124k inserts on a phone is a visible freeze, and
the data never changes between releases anyway.

The app's own taught words stay in their own tables. Those carry decks,
SRS state, examples and hand-checked Russian; these are reference entries
with machine translation, and the two are deliberately not mixed.

Usage:
    python cedict_build_db.py --parsed parsed.json --ru ru.json --out cedict.db
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import unicodedata

# Build-time only, nothing ships: CC-CEDICT carries no usage frequency,
# so without this a search for "вода" ranks the obscure 㵮 above 水
# purely because it is one character long.
from wordfreq import zipf_frequency

TONE_DIGITS = re.compile(r"[0-9]")
SEPARATORS = re.compile(r"[\s'’·\-]+")

# The translator emits sentence-shaped output for fragment-shaped input:
# "hello" comes back as "Привет." with a capital and a full stop. Left
# alone, a dictionary of 124k entries reads like 124k tiny sentences.
SPACE_BEFORE_PUNCT = re.compile(r"\s+([,;:.!?)\]])")
DOUBLE_SPACE = re.compile(r"\s{2,}")


def plain_pinyin(pinyin: str) -> str:
    """Toneless, separator-free pinyin: what people actually type."""
    text = unicodedata.normalize("NFD", pinyin.lower())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = text.replace("ü", "v")
    return SEPARATORS.sub("", TONE_DIGITS.sub("", text))


def tidy(ru: str, en: str) -> str:
    """Turns one machine-translated sentence back into a dictionary gloss."""
    ru = DOUBLE_SPACE.sub(" ", SPACE_BEFORE_PUNCT.sub(r"\1", ru)).strip()
    # A single trailing full stop is punctuation the translator added, not
    # part of the gloss. Text that really is two sentences keeps its stops.
    if ru.endswith(".") and ". " not in ru[:-1] and not ru.endswith(".."):
        ru = ru[:-1].rstrip()
    # Proper nouns keep their capital; everything else follows the
    # English, which CC-CEDICT capitalizes deliberately.
    if ru and en and en[:1].islower() and ru[:1].isupper():
        ru = ru[:1].lower() + ru[1:]
    return ru


# Cross-references are the bulk of what the translator returns nothing
# usable for: strip out the Chinese and "see 中國|中国[Zhong1 guo2]" is an
# empty sentence. They are also entirely formulaic, so they translate
# exactly, which machine translation would not.
TEMPLATES = [
    ("erhua variant of ", "эризованный вариант "),
    ("old variant of ", "устаревший вариант "),
    ("Japanese variant of ", "японский вариант "),
    ("variant of ", "вариант написания "),
    ("see also ", "см. также "),
    ("see ", "см. "),
    ("abbr. for ", "сокр. от "),
    ("also written ", "также пишется "),
    ("same as ", "то же, что "),
    ("equivalent to ", "то же, что "),
    ("used in ", "употребляется в "),
]


def from_template(en: str) -> str:
    """Translates a cross-reference gloss by its fixed opening phrase."""
    for english, russian in TEMPLATES:
        if en.startswith(english):
            return russian + en[len(english):]
    return ""


def dedupe(glosses: list[str]) -> list[str]:
    """Drops repeats — "to thank; thanks; thank you" all translate alike."""
    seen: set[str] = set()
    out: list[str] = []
    for gloss in glosses:
        key = gloss.lower().strip(" .,;")
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(gloss)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--parsed", required=True)
    ap.add_argument("--ru", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument(
        "--course-words",
        help="the app's own words.json; its hand-checked Russian is "
        "trusted over the machine translation for the entries it covers",
    )
    args = ap.parse_args()

    with open(args.parsed, encoding="utf-8") as fh:
        entries = json.load(fh)
    with open(args.ru, encoding="utf-8") as fh:
        ru_by_gloss: dict[str, str] = json.load(fh)

    # The course covers a few hundred words, and they are overwhelmingly
    # the high-frequency ones people actually look up. Their Russian was
    # written by hand, so it leads the gloss list wherever it exists —
    # this is what makes 水 read "вода" rather than the translator's
    # "воды".
    checked: dict[str, str] = {}
    if args.course_words:
        with open(args.course_words, encoding="utf-8") as fh:
            for word in json.load(fh):
                checked[word["hanzi"]] = word["translation_ru"]

    db = sqlite3.connect(args.out)
    db.executescript(
        """
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
        DROP TABLE IF EXISTS entries;
        CREATE TABLE entries (
            id           INTEGER PRIMARY KEY,
            simp         TEXT NOT NULL,
            trad         TEXT NOT NULL,
            pinyin       TEXT NOT NULL,
            pinyin_plain TEXT NOT NULL,
            ru           TEXT NOT NULL,
            en           TEXT NOT NULL,
            -- Zipf frequency x100. The whole reason results are usable:
            -- 124k entries match loosely, and only frequency tells the
            -- everyday word from the literary hapax.
            freq         INTEGER NOT NULL,
            -- Tie-breaker for the long tail, where frequency is 0 for
            -- everything: shorter headwords first.
            weight       INTEGER NOT NULL,
            -- 1 when the entry says nothing but "see 吃[chi1]". These
            -- share a headword and a frequency with the entry that
            -- carries the actual meaning, so without this they can win
            -- the tie and answer a lookup with a pointer to itself.
            is_ref       INTEGER NOT NULL
        );
        """
    )

    rows = []
    missing = 0
    for i, entry in enumerate(entries):
        en = entry["en"]
        ru = dedupe(
            [
                *([checked[entry["simp"]]] if entry["simp"] in checked else []),
                *[
                    tidy(ru_by_gloss[g], g)
                    if ru_by_gloss.get(g)
                    else from_template(g)
                    for g in en
                ],
            ]
        )
        if not ru:
            # An entry with no Russian is still worth having: the English
            # is shown regardless, and dropping it would leave holes in a
            # dictionary that claims to be complete.
            missing += 1
        rows.append(
            (
                i,
                entry["simp"],
                entry["trad"],
                entry["pinyin"],
                plain_pinyin(entry["pinyin"]),
                "; ".join(ru),
                "; ".join(en),
                round(zipf_frequency(entry["simp"], "zh") * 100),
                len(entry["simp"]),
                1 if ru and all(from_template(g) for g in en) else 0,
            )
        )

    db.executemany("INSERT INTO entries VALUES (?,?,?,?,?,?,?,?,?,?)", rows)
    db.executescript(
        """
        CREATE INDEX idx_simp   ON entries(simp);
        CREATE INDEX idx_trad   ON entries(trad);
        CREATE INDEX idx_pinyin ON entries(pinyin_plain);
        CREATE INDEX idx_freq   ON entries(freq DESC);
        """
    )
    db.commit()
    db.execute("VACUUM")
    db.close()

    corrected = sum(1 for e in entries if e["simp"] in checked)
    common = sum(1 for r in rows if r[7] >= 300)
    print(
        f"entries: {len(rows)}  without any Russian: {missing}  "
        f"in everyday use: {common}  hand-checked: {corrected}"
    )


if __name__ == "__main__":
    main()
