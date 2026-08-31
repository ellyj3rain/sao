#!/usr/bin/env python3
r"""The one reader for Lua source. Not a border - the thing borders read with.

[B47] made `reach_scan.py` the one reader for reaches after two
borders disagreed about the same code. This is the same move for a
worse case: `strip_lua` is copied verbatim into four tools, and three
separate borders have now hand-rolled a "find one function's body"
that counts `end` keywords.

Every one of those hand-rolled readers has been wrong.

  * [B51]'s first draft of Border 74 reported `ensurePopulation` as
    walking the identity store eleven times. It walks it twice. The
    reader was counting `if`, `for` and `end` INSIDE COMMENTS, in a
    file where the comments outweigh the code.
  * The same reader mishandles a bare `do ... end` block, which this
    tree uses, by counting the `end` without ever having counted the
    `do`.
  * `if ... then ... elseif ... then ... end` has two `then` and one
    `end`, so the obvious fix of counting `then` instead over-counts
    just as badly in the other direction.

A Lua block is not something to approximate. Getting it wrong does not
produce an error - it produces a body that stops early or runs long,
and then a border reports on text that is not the function.

WHAT A BLOCK ACTUALLY IS
------------------------
`end` closes exactly one of: `function`, `if`, `for`, `while`, or a
bare `do`. The trap is that `for` and `while` are followed by their own
`do`, which must NOT count a second time - so a `for` or `while` arms a
flag that swallows the next `do`. `repeat` is closed by `until`, not by
`end`. `elseif` and `else` open nothing.

Comments and strings are removed first, by the same `strip_lua` the
four older tools carry, so none of those keywords can be counted out of
prose or out of a string literal.
"""
import re

# Blank out comments and string bodies, preserving offsets, so a line
# number stays true and paren scanning sees the real structure.
# Copied unchanged from the four tools that each carry it; identical
# behaviour is the point, so that moving a border onto this module
# cannot change what that border reads.
_LONG_OPEN = re.compile(r"\[(=*)\[")
_LONG_COMMENT = re.compile(r"--\[(=*)\[")


def strip_lua(src, strings=True):
    """Blank out comments and (optionally) string bodies, keeping offsets.

    `strings=False` leaves string literals alone, which a caller reading
    a pattern out of a `gmatch` needs and a caller counting keywords
    does not.
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            m = _LONG_COMMENT.match(src, i)
            if m:
                close = "]" + m.group(1) + "]"
                end = src.find(close, i)
                end = n if end < 0 else end + len(close)
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            for k in range(i, end):
                if out[k] != "\n":
                    out[k] = " "
            i = end
            continue
        m = _LONG_OPEN.match(src, i) if c == "[" else None
        if m:
            close = "]" + m.group(1) + "]"
            end = src.find(close, i)
            end = n if end < 0 else end + len(close)
            if strings:
                for k in range(i, end):
                    if out[k] != "\n":
                        out[k] = " "
            i = end
            continue
        if strings and c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                j += 1
            for k in range(i + 1, min(j, n)):
                if out[k] != "\n":
                    out[k] = " "
            i = min(j + 1, n)
            continue
        i += 1
    return "".join(out)


_TOKEN = re.compile(
    r"\b(function|if|for|while|do|repeat|until|end|elseif|else)\b")


def function_body(src, name, stripped=None):
    """The text of one function, by real block depth.

    `src` is the original source (so the returned slice is real code);
    `stripped` is `strip_lua(src)` if the caller already has it, which
    is where the keywords are counted. Returns None when there is no
    such function - which is a finding for the caller, never a reason
    to guess.
    """
    text = stripped if stripped is not None else strip_lua(src)
    start = re.search(
        r"^[ \t]*(?:local[ \t]+)?function[ \t]+" + re.escape(name)
        + r"[ \t]*\(", text, re.M)
    if not start:
        return None
    depth, swallow_do = 1, False
    for t in _TOKEN.finditer(text, start.end()):
        word = t.group(1)
        if word in ("for", "while"):
            depth += 1
            swallow_do = True
        elif word == "do":
            if swallow_do:
                swallow_do = False
            else:
                depth += 1
        elif word in ("function", "if", "repeat"):
            depth += 1
        elif word in ("end", "until"):
            depth -= 1
            if depth == 0:
                return src[start.end():t.start()]
    return src[start.end():]


def functions(src, stripped=None):
    """Every named function in one file, as {name: body}."""
    text = stripped if stripped is not None else strip_lua(src)
    out = {}
    for m in re.finditer(
            r"^[ \t]*(?:local[ \t]+)?function[ \t]+([\w.:]+)[ \t]*\(",
            text, re.M):
        body = function_body(src, m.group(1), text)
        if body is not None:
            out.setdefault(m.group(1), body)
    return out
