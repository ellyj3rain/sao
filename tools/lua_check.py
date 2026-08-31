#!/usr/bin/env python3
"""Structural Lua checker: strips comments AND string literals, then verifies
block balance and paren/brace balance. Catches truncation and paste damage,
not semantics. Counting rule: for/while contribute nothing themselves - their
required 'do' opens the block their 'end' closes; if/function/do/repeat open
directly; end/until close."""
import re
import sys


def strip(text):
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        two = text[i:i + 2]
        if two == "--":
            m = re.match(r"--\[(=*)\[", text[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = text.find(close, i)
                i = (j + len(close)) if j != -1 else n
            else:
                j = text.find("\n", i)
                i = j if j != -1 else n
            continue
        if ch in "'\"":
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == ch:
                    break
                j += 1
            out.append('""')
            i = j + 1
            continue
        m = re.match(r"\[(=*)\[", text[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = text.find(close, i)
            out.append('""')
            i = (j + len(close)) if j != -1 else n
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def check(path):
    text = open(path, encoding="utf-8").read()
    code = strip(text)
    words = re.findall(r"\b\w+\b", code)
    openers = 0
    for k, w in enumerate(words):
        if w in ("function", "if", "do", "repeat"):
            openers += 1
        elif w in ("end", "until"):
            openers -= 1
        if openers < 0:
            print(f"{path}: MISMATCH extra 'end' near token {k}")
            return 1
    parens = code.count("(") - code.count(")")
    braces = code.count("{") - code.count("}")
    if openers != 0 or parens != 0 or braces != 0:
        print(f"{path}: MISMATCH blocks={openers} parens={parens} braces={braces}")
        return 1
    print(f"{path.split(chr(92))[-1].split('/')[-1]}: OK")
    return 0


if __name__ == "__main__":
    sys.exit(check(sys.argv[1]))
