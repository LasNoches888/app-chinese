"""Appends a batch of HSK4+ decks/words/stroke-data to the bundled seed
JSON, sourced from the already-extracted KitUP HSK 3.0 word list.

Unlike mobile/tool/gen_vocab.py (which *overwrites* words.json/decks.json
from a hard-coded dict and doesn't know about the hand-added HSK3 decks —
do not run that script), this one *reads* the existing seed JSON and
*appends* new entries, so it's safe to re-run with a different --start for
the next batch later.

Run from the repo root:
    python tools/gen_hsk4_batch.py --level 4 --start 1 --count 125 --chunk 25

Reading passages and dialogues are NOT generated here — they're authored by
hand per deck (see plan) and appended to reading_passages.json/dialogues.json
separately, since they need to read naturally and stay within the taught
character set.
"""
import argparse
import json
import os
import re
import sys

# Windows consoles default to a legacy codepage (cp1251 here) that can't
# print Chinese/Cyrillic text -- force UTF-8 on stdout so the skip report
# below doesn't crash after (and lose) an otherwise-successful run.
sys.stdout.reconfigure(encoding="utf-8")

# The KitUP source has a few notation quirks mixed into the hanzi field
# itself rather than kept separate:
#   - a trailing part-of-speech tag, e.g. "别（动）" = "别" + "(verb)"
#   - a mid-word optional character in brackets, e.g. "有（一）些" = "有些"
#     or "有一些" are both acceptable — the bracketed part can be omitted
#   - alternate written forms separated by "｜", e.g. "爸爸｜爸" or "零｜〇"
#   - an ellipsis marking a fill-in-the-blank pattern word rather than a
#     real character, e.g. "…极了", "…分之…"
_PARENTHETICAL = re.compile(r"[（(][^）)]*[）)]")


def clean_hanzi(hanzi):
    hanzi = hanzi.split("｜")[0]
    hanzi = _PARENTHETICAL.sub("", hanzi)
    hanzi = hanzi.replace("…", "")
    return hanzi.strip()

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED_DIR = os.path.join(REPO_ROOT, "mobile", "assets", "seed")
HSK_WORDS_PATH = (
    r"C:\Users\igort\AppData\Local\Temp\claude\E--ClaudeProject-AppChines"
    r"\31c5cde5-04cf-452a-ad05-b96a198bc4d3\scratchpad\hsk_words.json"
)
GRAPHICS_PATH = (
    r"C:\Users\igort\AppData\Local\Temp\claude\E--ClaudeProject-AppChines"
    r"\31c5cde5-04cf-452a-ad05-b96a198bc4d3\scratchpad\makemeahanzi_graphics.txt"
)


def load(name):
    with open(os.path.join(SEED_DIR, name), encoding="utf-8") as f:
        return json.load(f)


def save(name, data):
    path = os.path.join(SEED_DIR, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote {path} ({len(data)} entries)")


def build_graphics_index():
    index = {}
    with open(GRAPHICS_PATH, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            index[obj["character"]] = obj
    return index


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", type=int, required=True)
    ap.add_argument("--start", type=int, required=True, help="1-based index into that level's word list")
    ap.add_argument("--count", type=int, required=True)
    ap.add_argument("--chunk", type=int, default=25)
    args = ap.parse_args()

    with open(HSK_WORDS_PATH, encoding="utf-8") as f:
        hsk_words = json.load(f)
    level_words = [w for w in hsk_words if w["hsk_level"] == args.level]
    batch = level_words[args.start - 1 : args.start - 1 + args.count]
    if len(batch) != args.count:
        raise SystemExit(f"expected {args.count} words, got {len(batch)} (level has {len(level_words)})")

    words_json = load("words.json")
    decks_json = load("decks.json")
    stroke_json = load("stroke_data.json")

    existing_word_ids = {w["id"] for w in words_json}
    existing_deck_ids = {d["id"] for d in decks_json}
    existing_hanzi = {w["hanzi"] for w in words_json}
    known_chars = set(stroke_json.keys())

    graphics = None  # lazy-loaded only if new characters are actually needed

    deck_num_base = (args.start - 1) // args.chunk + 1
    new_word_count = 0
    new_deck_count = 0
    new_char_count = 0
    skipped = []

    for i in range(0, len(batch), args.chunk):
        chunk = batch[i : i + args.chunk]
        deck_num = deck_num_base + i // args.chunk
        deck_id = f"hsk{args.level}_{deck_num:02d}"
        if deck_id in existing_deck_ids:
            raise SystemExit(f"deck {deck_id} already exists — pick a different --start")

        w_start = args.start + i
        w_end = w_start + len(chunk) - 1
        deck_words = []

        for j, w in enumerate(chunk, start=1):
            hanzi = clean_hanzi(w["hanzi"])
            # A handful of the same character(s) with a different sense/part
            # of speech collide with an already-taught word (e.g. "\u522b\uff08\u52a8\uff09"
            # = the verb sense of \u522b, when \u522b the adverb is already taught).
            # The schema keys one flashcard per hanzi string, so the second
            # sense can't get its own entry -- skip it rather than crash.
            if hanzi in existing_hanzi:
                skipped.append((w_start + j - 1, w["hanzi"]))
                continue
            existing_hanzi.add(hanzi)
            word_id = f"hsk{args.level}_{w_start + j - 1:04d}"
            if word_id in existing_word_ids:
                raise SystemExit(f"word id {word_id} already exists")
            existing_word_ids.add(word_id)
            deck_words.append(
                {
                    "id": word_id,
                    "hanzi": hanzi,
                    "pinyin": w["pinyin"],
                    "translation_ru": w["translation_ru"],
                    "example_sentence": None,
                    "example_translation": None,
                    "hsk_level": args.level,
                    "topic": deck_id,
                    "deck_id": deck_id,
                }
            )

            for ch in hanzi:
                if ch in known_chars:
                    continue
                if graphics is None:
                    print("loading makemeahanzi graphics.txt (one-time)...")
                    graphics = build_graphics_index()
                if ch not in graphics:
                    raise SystemExit(f"character {ch!r} (word {w['hanzi']}) not found in makemeahanzi dataset")
                entry = graphics[ch]
                stroke_json[ch] = {
                    "character": entry["character"],
                    "strokes": entry["strokes"],
                    "medians": entry["medians"],
                }
                known_chars.add(ch)
                new_char_count += 1

        decks_json.append(
            {
                "id": deck_id,
                "title": f"HSK {args.level} \u00b7 \u0441\u043b\u043e\u0432\u0430 {w_start}\u2013{w_end}",
                "topic": deck_id,
                "hsk_level": args.level,
                "word_count": len(deck_words),
            }
        )
        new_deck_count += 1
        words_json.extend(deck_words)
        new_word_count += len(deck_words)

    if skipped:
        print(f"skipped {len(skipped)} words already taught under a different sense:")
        for idx, original in skipped:
            print(f"  #{idx}: {original!r}")

    save("words.json", words_json)
    save("decks.json", decks_json)
    save("stroke_data.json", stroke_json)
    print(f"added {new_deck_count} decks, {new_word_count} words, {new_char_count} new characters")


if __name__ == "__main__":
    main()
