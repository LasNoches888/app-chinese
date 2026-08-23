"""Parses CC-CEDICT into the structured rows the app's dictionary needs.

CC-CEDICT is Chinese->English; the app is Russian, so this is step one of
two (parse/filter here, translate in cedict_translate.py).

Line format:
    TRAD SIMP [pin1 yin1] /gloss one/gloss two/

Glosses carry markup this keeps out of the translator's way:
    CL:個|个[ge4]      classifier cross-reference
    see 中國|中国[...]  cross-reference to another entry
    (coll.) (lit.)     register/usage labels
"""
from __future__ import annotations

import argparse
import json
import re

# CC-CEDICT tags its own coarse material, which is the most reliable
# signal available. The word list backs it up for entries that carry no
# tag — kept deliberately narrow so anatomy and medical vocabulary
# (necessary in any real dictionary) survives.
TAG_BLOCKLIST = re.compile(
    r"\((vulgar|coarse|obscene|offensive)[^)]*\)", re.IGNORECASE
)
TERM_BLOCKLIST = re.compile(
    r"\b("
    r"fuck\w*|shit\w*|cunt\w*|whore\w*|slut\w*|bitch\b|bastard\b|"
    r"motherfuck\w*|wank\w*|blowjob\w*|handjob\w*|"
    r"pornograph\w*|\bporn\b|hardcore sex|"
    r"masturbat\w*|orgasm\w*|ejaculat\w*|"
    r"prostitut\w*|brothel\w*|hooker\b|"
    r"dildo\w*|sex toy|sexual intercourse|have sex\b|"
    r"penis\b|vagina\b|genitalia\b|testicle\w*|scrotum\b|anus\b"
    r")",
    re.IGNORECASE,
)

LINE_RE = re.compile(r"^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+/(.*)/\s*$")

# Markup that should be preserved verbatim rather than translated.
CLASSIFIER_RE = re.compile(r"^CL:")
XREF_RE = re.compile(r"^(see|see also|variant of|old variant of|abbr\. for)\b")


def is_blocked(gloss: str) -> bool:
    """Whether this one sense is coarse.

    Checked per sense, not per entry. Plenty of ordinary words carry one
    vulgar sense among several — 小姐 is "Miss" and, in mainland slang,
    "prostitute"; 黄色 is "yellow" and "pornographic" — and blocking the
    whole entry loses the word a learner actually needs. Dropping the one
    sense keeps the word and leaves the coarse reading out.
    """
    return bool(TAG_BLOCKLIST.search(gloss) or TERM_BLOCKLIST.search(gloss))


def translatable(gloss: str) -> bool:
    """Whether a gloss is prose worth sending to a translator."""
    if CLASSIFIER_RE.match(gloss):
        return False
    if XREF_RE.match(gloss):
        return False
    # Pure Chinese/pinyin cross references carry no English to translate.
    if not re.search(r"[a-zA-Z]{2}", gloss):
        return False
    return True


def parse(path: str) -> list[dict]:
    entries: list[dict] = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            m = LINE_RE.match(line)
            if not m:
                continue
            trad, simp, pinyin, gloss_blob = m.groups()
            glosses = [g.strip() for g in gloss_blob.split("/") if g.strip()]
            if not glosses:
                continue
            kept = [g for g in glosses if not is_blocked(g)]
            # An entry whose every sense is coarse has nothing left to
            # teach, so it goes; one that merely mentions it keeps the
            # rest.
            if not kept:
                continue
            glosses = kept
            entries.append(
                {
                    "simp": simp,
                    "trad": trad,
                    "pinyin": pinyin,
                    "en": glosses,
                }
            )
    return entries


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    args = ap.parse_args()

    entries = parse(args.input)
    n_glosses = sum(len(e["en"]) for e in entries)
    n_translatable = sum(
        1 for e in entries for g in e["en"] if translatable(g)
    )
    unique = {g for e in entries for g in e["en"] if translatable(g)}

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False)

    print(f"entries kept:        {len(entries)}")
    print(f"glosses total:       {n_glosses}")
    print(f"glosses to translate:{n_translatable}")
    print(f"unique gloss strings:{len(unique)}")


if __name__ == "__main__":
    main()
