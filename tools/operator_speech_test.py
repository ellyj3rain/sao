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
WORDS = re.compile(r'\b(?:' + '|'.join(PROFANITY) + r')\b', re.I)
ATTRIBUTION = re.compile(
    r'\b[Oo]perator\b(?=[ \t:,.]|\x27s\b)[^a-zA-Z\n][^\n]{0,45}"[A-Za-z]'
    r'|\(operator\):\s*"'
    r'|Verbatim:\s*\n?\s*\*?"')
SUFFIXES = (".md", ".lua", ".py", ".txt", ".json")


def attribution_controls():
    """Keep prose attributions distinct from identifier/hash inventory rows."""
    samples = (
        ("standalone mention", 'Operator said: "Synthetic control"', True),
        ("lowercase mention", 'the operator replied "Synthetic control"', True),
        ("possessive mention", 'Operator\'s words: "Synthetic control"', True),
        ("parenthesized attribution", '(operator): "Synthetic control"', True),
        ("verbatim marker", 'Verbatim:\n*"Synthetic control"', True),
        ("filename/hash inventory", '"tools/operator_speech_test.py": '
         '"f4b53c25b9df1c0e4b64566a8ebba7f2bcf83bfb72822237b99c63c8a583cb05",', False),
        ("prefixed identifier", 'cooperator: "Synthetic control"', False),
        ("unattributed dialogue", 'character: "Synthetic control"', False),
        ("separate lines", 'Operator present\ncharacter: "Synthetic control"', False),
        ("player identifier", 'body("operator", 17, "Ava", "Person")', False),
        ("prefixed account", 'id == "player:operator" and kind == "conversation"', False),
        ("guard test identifier", "('operator-navigation-guards',[(\"event\")])", False),
    )
    faults = [f"attribution control '{name}' differs from its required verdict"
              for name, text, expected in samples
              if bool(ATTRIBUTION.search(text)) != expected]
    return len(samples), faults


def tracked_files():
    done = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=str(ROOT),
        capture_output=True, text=True, timeout=120)
    return [ROOT / line for line in sorted(set(done.stdout.splitlines()))
            if line and pathlib.Path(line).suffix in SUFFIXES]


def input_lexicon_spans(source):
    """Boolean lookup vocabulary classifies received input; it emits no speech."""
    from lua_read import function_body, strip_lua
    code = strip_lua(source, strings=False)
    consumer = function_body(code, 'sourceChatIntent') or ''
    if ('local words = text:lower()' not in consumer
            or 'if sourceThreats[words] then return "threat" end' not in consumer
            or len(re.findall(r'\bsourceThreats\b', code)) != 2):
        return []
    table = re.search(r'local\s+sourceThreats\s*=\s*\{([^{}]*)\}', code, re.S)
    if table is None:
        return []
    body = re.sub(r'\["[^"\n]+"\]\s*=\s*true\s*,?', '', table.group(1))
    return [(table.start(1), table.end(1))] if not body.strip() else []


def speech_controls():
    assert not WORDS.search('native sound ZSHit; snapshot; worship')
    assert WORDS.search('a shit utterance')
    sample = 'local sourceThreats = {["fuck you"] = true}\n' \
        'local function sourceChatIntent(text)\n' \
        'local words = text:lower()\n' \
        'if sourceThreats[words] then return "threat" end\nend\n'
    assert input_lexicon_spans(sample)
    assert not input_lexicon_spans(sample.replace('sourceThreats[words]', 'other[words]'))
    assert not input_lexicon_spans(sample + 'body:Say(sourceThreats[words])\n')
    assert ATTRIBUTION.search('Operator said: "Synthetic control"')
    return 6


def main():
    from source_scanner_baseline import Baseline
    baseline = Baseline()
    inventory = baseline.inventory
    controls, faults = attribution_controls()
    controls += speech_controls()
    print("=" * 74)
    print("THE OPERATOR'S SPEECH IS NOT IN THE REPOSITORY")
    print("=" * 74)
    print(f"  attribution controls checked: {controls}")

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
        original = inventory.preserved_original_text(f)
        lexicons = input_lexicon_spans(text) if f.suffix == '.lua' else []
        for match in WORDS.finditer(text):
            word = match.group().lower()
            if any(first <= match.start() < last for first, last in lexicons):
                continue
            # The exact original source text is recorded provenance, not
            # operator speech. Added occurrences remain findings. Quoted
            # operator attribution below is never waived.
            if original is not None and baseline.preserved(f, text.count('\n', 0, match.start()) + 1, comments=True):
                continue
            line = text.count('\n', 0, match.start()) + 1
            faults.append(f"{rel}:{line} carries '{word}' - the "
                          "county's own copy never does (DR-018), "
                          "so this is somebody's speech, published")
            break
        m = ATTRIBUTION.search(text)
        if (m and f.suffix == '.py'
                and text[m.start():].startswith('Operator said: "Synthetic control"')
                and re.search(r'write_text\([\x27"]$', text[max(0, m.start() - 20):m.start()])):
            # A negative scanner fixture is synthetic input created expressly
            # to make the speech rule reject it, with no recorded human words.
            m = None
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
