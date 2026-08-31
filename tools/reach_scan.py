r"""One reader for every reach in the tree ([B47]).

[B46] recorded that Border 47's census undercounts: `survivorNear` -
the gate under every person verb in the context menu - compares
`d <= 9.0`, and the census's flat pattern only matched variables
spelled `*dist*`. Measuring the miss properly turned up five more
shapes it could not see:

  * an upper bound rather than a lower one - `> 900`, `> 40000`
  * `<` rather than `<=`
  * a parenthesised expression - `(wdx * wdx + wdy * wdy) <= 100.0`
  * a named intermediate - `local d2 = dx * dx + dy * dy`, compared
    somewhere below
  * a flat distance through `math.sqrt`, then compared

So the census was not slightly wrong, it was wrong about most of the
tree, and [B43] through [B45] have been reporting a backlog number
that described the reaches the regex happened to match rather than the
reaches that exist. That is worse than no number, because a wrong
count still looks like a measurement.

HOW THIS READS A REACH
----------------------
Two phases, because a distance is often named before it is compared.

  1. Find every variable that PROVABLY holds a distance: assigned from
     an expression containing `X * X + Y * Y`, whether bare, wrapped in
     `math.sqrt`, or returned from a `pcall(function() ... end)` whose
     value is bound to a local. Nothing is assumed from a variable's
     spelling - `d`, `d2`, `len`, `trip` and `cdist` all qualify by
     what they were assigned, and a variable called `dist` that was
     never assigned a distance does not qualify at all.

  2. Find every comparison of one of those - or of an inline squared
     expression - against a NUMERIC LITERAL, in any of the four
     directions. A comparison against a NAME is a named reach and is
     exactly what this is trying to encourage, so it is not counted.

Both reach borders read through here, so they cannot disagree about
what the tree contains.
"""
import re

# `X * X + Y * Y`, the squared-distance shape.
SQUARED = re.compile(r"(\w+)\s*\*\s*\1\s*\+\s*(\w+)\s*\*\s*\2")
# That shape compared straight to a number, parentheses allowed.
INLINE = re.compile(
    r"\(?\s*(\w+)\s*\*\s*\1\s*\+\s*(\w+)\s*\*\s*\2\s*\)?"
    r"\s*(<=|>=|<|>)\s*([0-9][0-9.]*)")
# `local a, b = ...` / `a = ...` - the names bound by one assignment.
ASSIGN = re.compile(r"^[ \t]*(?:local\s+)?([A-Za-z_][\w, \t]*?)\s*=\s*(.*)$",
                    re.M)
CALL_OPEN = re.compile(r"pcall\s*\(\s*function\s*\(")
# Where one function body starts. Names are scoped to these, because a
# `d` that holds a distance in one function and a `d` that holds
# something else in another are different variables, and a reader that
# cannot tell them apart will count the wrong one.
FUNC_HEAD = re.compile(r"^[ 	]*(?:local\s+)?function", re.M)


def _closure_span(src, start):
    """From a `pcall(function(` opening, the span of that call."""
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return i
    return None


def distance_names(src):
    """Variables provably assigned a distance, squared or flat."""
    names = set()
    for m in ASSIGN.finditer(src):
        targets = [t.strip() for t in m.group(1).split(",") if t.strip()]
        rest = m.group(2)
        if not targets or not all(t.isidentifier() for t in targets):
            continue
        # The assignment's own line, plus a pcall closure it opens.
        window = rest
        opener = CALL_OPEN.search(rest)
        if opener:
            at = m.start(2) + opener.start()
            end = _closure_span(src, src.index("(", at))
            if end:
                window = src[at:end]
        # `qualifies = (dx*dx + dy*dy) <= 100.0` assigns a BOOLEAN.
        # The squared expression is there, but it is the left side of a
        # comparison, so what lands in the variable is true or false and
        # comparing it to a number would mean nothing.
        if INLINE.search(window):
            continue
        if SQUARED.search(window):
            # `local ok, d = pcall(...)` binds the value to the LAST
            # name; a plain assignment binds it to the only one.
            names.add(targets[-1])
    return names


def _segments(src):
    """The file split at function boundaries, with their offsets."""
    starts = [m.start() for m in FUNC_HEAD.finditer(src)]
    bounds = [0] + starts + [len(src)]
    out = []
    for i in range(len(bounds) - 1):
        a, b = bounds[i], bounds[i + 1]
        if b > a:
            out.append((a, src[a:b]))
    return out


def bare_reaches(src):
    """Every comparison against a literal that is really a radius.

    Yields (offset, tiles, spelling) - `tiles` already un-squared where
    the comparison was against a squared distance, so two reaches that
    mean the same distance compare equal.
    """
    out = []
    for m in INLINE.finditer(src):
        value = float(m.group(4))
        out.append((m.start(), value ** 0.5, m.group(0).strip()))

    for base, seg in _segments(src):
        out.extend((base + off, tiles, spell)
                   for off, tiles, spell in _named_in(seg))
    return sorted(out)


def _named_in(src):
    """Comparisons of a locally-named distance against a literal."""
    out = []
    names = distance_names(src)
    if names:
        # A named distance is squared unless it went through sqrt; the
        # scan cannot tell from the comparison alone, so it records the
        # spelling and lets the caller decide. Squared names are the
        # common case and are marked.
        squared = _squared_names(src, names)
        # `(?<![\w.#])` - a leading `#` is Lua's length operator, so
        # `#queue > 0` is a count and not a distance however the
        # variable was spelled.
        pattern = re.compile(
            r"(?<![\w.#])(" + "|".join(sorted(map(re.escape, names)))
            + r")\s*(<=|>=|<|>)\s*([0-9][0-9.]*)")
        for m in pattern.finditer(src):
            value = float(m.group(3))
            tiles = value ** 0.5 if m.group(1) in squared else value
            out.append((m.start(), tiles, m.group(0).strip()))
    return out


def _squared_names(src, names):
    """Of the distance names, the ones NOT passed through math.sqrt."""
    squared = set()
    for m in ASSIGN.finditer(src):
        targets = [t.strip() for t in m.group(1).split(",") if t.strip()]
        if not targets or targets[-1] not in names:
            continue
        rest = m.group(2)
        window = rest
        opener = CALL_OPEN.search(rest)
        if opener:
            at = m.start(2) + opener.start()
            end = _closure_span(src, src.index("(", at))
            if end:
                window = src[at:end]
        if SQUARED.search(window) and "sqrt" not in window:
            squared.add(targets[-1])
    return squared


def line_of(src, offset):
    return src.count("\n", 0, offset) + 1
