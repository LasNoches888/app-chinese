"""Translates CC-CEDICT's English glosses to Russian on the local GPU.

Runs Helsinki-NLP/opus-mt-en-ru (a small Marian model) over the unique
gloss strings — CC-CEDICT repeats the same short gloss across many
entries, so deduplicating first cuts the work by roughly a third.

The English is kept alongside the Russian in the output on purpose:
machine translation of terse, context-free dictionary glosses is useful
but not trustworthy, and the app shows the original so a bad rendering is
always checkable rather than silently authoritative.
"""
from __future__ import annotations

import argparse
import json
import re
import time

import torch
from transformers import MarianMTModel, MarianTokenizer

MODEL = "Helsinki-NLP/opus-mt-en-ru"

CLASSIFIER_RE = re.compile(r"^CL:")
XREF_RE = re.compile(r"^(see|see also|variant of|old variant of|abbr\. for)\b")

# Chinese cross-references embedded mid-gloss, optionally as
# traditional|simplified and with a bracketed reading:
#   粉絲|粉丝[fen3 si1]
CJK_REF = re.compile(
    r"[一-鿿]+(?:\|[一-鿿]+)?(?:\[[^\]]*\])?"
)


def translatable(gloss: str) -> bool:
    if CLASSIFIER_RE.match(gloss) or XREF_RE.match(gloss):
        return False
    return bool(re.search(r"[a-zA-Z]{2}", gloss))


def protect(gloss: str) -> tuple[str, list[str]]:
    """Swaps Chinese references out for markers before translation.

    Feeding CJK straight to an en->ru model makes it emit noise where the
    reference was ("Δ Δ Δ", stray glyphs), destroying information that
    was perfectly good to begin with. Markers survive the round trip and
    the originals go back in afterwards.
    """
    refs: list[str] = []

    def swap(m: re.Match[str]) -> str:
        refs.append(m.group(0))
        return f" Q{len(refs)}Q "

    return CJK_REF.sub(swap, gloss), refs


def restore(translated: str, refs: list[str]) -> str:
    out = translated
    for i, ref in enumerate(refs, 1):
        out = re.sub(rf"\s*Q\s*{i}\s*Q\s*", f" {ref} ", out)
    # Marian likes to open short fragments with a stray dash.
    out = re.sub(r"^[\s\-–—]+", "", out)
    return re.sub(r"\s+", " ", out).strip()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--batch", type=int, default=64)
    ap.add_argument("--limit", type=int, default=0, help="0 = everything")
    ap.add_argument(
        "--existing",
        help="a previous output to carry forward; only glosses missing "
        "from it are translated, so a change to the parser costs minutes "
        "rather than another full pass",
    )
    args = ap.parse_args()

    with open(args.input, encoding="utf-8") as f:
        entries = json.load(f)

    done: dict[str, str] = {}
    if args.existing:
        with open(args.existing, encoding="utf-8") as f:
            done = json.load(f)
        print(f"carried forward: {len(done)}", flush=True)

    unique: list[str] = sorted(
        {g for e in entries for g in e["en"] if translatable(g) and g not in done}
    )
    if args.limit:
        unique = unique[: args.limit]
    print(f"unique glosses to translate: {len(unique)}", flush=True)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    tok = MarianTokenizer.from_pretrained(MODEL)
    model = MarianMTModel.from_pretrained(MODEL).to(device)
    model.eval()
    if device == "cuda":
        model = model.half()
    print(f"model loaded on {device}", flush=True)

    ru_by_en: dict[str, str] = dict(done)
    started = time.time()
    for i in range(0, len(unique), args.batch):
        chunk = unique[i : i + args.batch]
        protected = [protect(g) for g in chunk]
        batch = tok(
            [p for p, _ in protected],
            return_tensors="pt",
            padding=True,
            truncation=True,
            max_length=128,
        ).to(device)
        with torch.inference_mode():
            out = model.generate(**batch, max_new_tokens=128, num_beams=1)
        decoded = tok.batch_decode(out, skip_special_tokens=True)
        for src, (_, refs), tgt in zip(chunk, protected, decoded):
            ru_by_en[src] = restore(tgt, refs)

        done = i + len(chunk)
        if done % (args.batch * 20) == 0 or done == len(unique):
            elapsed = time.time() - started
            rate = done / elapsed if elapsed else 0
            remaining = (len(unique) - done) / rate if rate else 0
            print(
                f"{done}/{len(unique)}  {rate:.0f}/s  "
                f"~{remaining / 60:.1f} min left",
                flush=True,
            )
            with open(args.output, "w", encoding="utf-8") as f:
                json.dump(ru_by_en, f, ensure_ascii=False)

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(ru_by_en, f, ensure_ascii=False)
    print(f"done in {(time.time() - started) / 60:.1f} min", flush=True)


if __name__ == "__main__":
    main()
