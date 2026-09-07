#!/usr/bin/env python3
r"""Border 103 - the operator's speech is not in the repository.

The operator, 2026-08-30, on finding their own words quoted through
the published records: documenting and publishing what they said in
session - casual speech, personal statements, raw phrasing - is
intrusive, and it was never the assistant's to decide. Rulings are
CONTENT; the records paraphrase them. Speech stays with the person
who said it.

This also stands as a data lesson the operator named the same day:
what enters a repository or a corpus is somebody's speech, and the
consent question is settled before admission, not after.

WHAT THIS HOLDS
---------------
  1. No profanity anywhere in the tracked tree - the county's own
     copy never carries it (DR-018), so any occurrence is quoted
     speech by definition.
  2. No quote-attribution shapes: an operator mention followed
     closely by quoted words, an "(operator):" attribution with a
     quote, or a "Verbatim:" marker introducing speech.
  3. The scrub is not clever: character dialogue in the shipped
     line-tables carries no operator attribution and no profanity,
     so it never matches; code that uses the word "operator" for
     Lua operators does not sit next to a quote.

An optional argv[1] points the checker at another tree root, which
is how the control runs against the pre-scrub tree.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent

PROFANITY = ("fuck", "shit", "goddamn", "asshole", "bitch")
ATTRIBUTION = re.compile(
    r'[Oo]perator[^a-zA-Z\n][^\n]{0,45}"[A-Za-z]'
    r'|\(operator\):\s*"'
    r'|Verbatim:\s*\n?\s*\*?"')
SUFFIXES = (".md", ".lua", ".py", ".txt", ".json")


def tracked_files():
    done = subprocess.run(
        ["git", "ls-files"], cwd=str(ROOT),
        capture_output=True, text=True, timeout=120)
    return [ROOT / line for line in done.stdout.splitlines()
            if line and pathlib.Path(line).suffix in SUFFIXES]


def main():
    faults = []
    print("=" * 74)
    print("THE OPERATOR'S SPEECH IS NOT IN THE REPOSITORY")
    print("=" * 74)

    files = tracked_files()
    if not files:
        print()
        print("VERDICT:")
        print("  FAULT: git ls-files returned nothing - a sweep over an "
              "empty set proves nothing")
        return 1
    scanned = 0
    for f in files:
        if f.name == "operator_speech_test.py":
            continue
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        scanned += 1
        rel = str(f.relative_to(ROOT)).replace("\\", "/")
        low = text.lower()
        for word in PROFANITY:
            if word in low:
                line = next(i + 1 for i, ln
                            in enumerate(low.split("\n")) if word in ln)
                faults.append(f"{rel}:{line} carries '{word}' - the "
                              "county's own copy never does (DR-018), "
                              "so this is somebody's speech, published")
                break
        m = ATTRIBUTION.search(text)
        if m:
            line = text[:m.start()].count("\n") + 1
            faults.append(f"{rel}:{line} attributes quoted words to "
                          "the operator - rulings are paraphrased "
                          "content; speech stays with the person who "
                          "said it")

    print(f"  tracked text files scanned: {scanned}")
    print()
    print("VERDICT:")
    if faults:
        for f in faults[:12]:
            print(f"  FAULT: {f}")
        if len(faults) > 12:
            print(f"  ... and {len(faults) - 12} more")
        return 1
    print("  103) no profanity and no operator-quote attributions in the")
    print("       tracked tree - the records speak content, the speech")
    print("       stays with the speaker")
    return 0


if __name__ == "__main__":
    sys.exit(main())
