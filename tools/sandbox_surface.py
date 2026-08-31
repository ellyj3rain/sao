#!/usr/bin/env python3
r"""Border 16 - the options screen is a surface the player reads.

Three things must hold across `media/sandbox-options.txt`, the EN
Sandbox translations, and the Lua that reads them. Each is an exact
set comparison, so this border cannot manufacture a finding:

  1. Every declared option is READ somewhere in Lua. A dial nothing
     reads is a promise the screen makes and the mod does not keep.

  2. Every declared option has BOTH a name and a tooltip. [B33] found
     DayZero with its whole explanation crammed into the name field,
     so it rendered as a 130-character label where the other twelve
     showed a short name and explained themselves on hover.

  3. Every Lua fallback matches the declared default. `(sv and
     tonumber(sv.X)) or 45` against `default = 45` - if those drift,
     a fresh world and a configured world disagree about the same
     setting and nothing says so.

  4. Every tooltip carries a line break, and no rendered line runs
     past what the wide layout fits. [B37]: the widgets decide a
     tooltip's wrap width by whether it CONTAINS a break, never by
     how long it is, so a tooltip without one is laid out in a 300px
     column no matter what it says.

Vanilla PZ options (SandboxVars.X, not SandboxVars.SurvivorAwareness.X)
are not ours to declare and are not checked here.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OPTS = ROOT / "mod" / "42.20" / "media" / "sandbox-options.txt"
TRANS = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
         / "Translate" / "EN" / "Sandbox.json")
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

PREFIX = "SurvivorAwareness"

# [B37] The two characters backslash+n, never an escape sequence -
# this is what a translation file carries and what SandboxOptions.lua
# converts. LINE_BUDGET is the character count that fits inside the
# 1000px wide layout at UIFont.Small with margin to spare.
BREAK = "\\" + "n"
LINE_BUDGET = 150


def declared():
    """Option name -> declared default, from the options file."""
    text = OPTS.read_text(encoding="utf-8", errors="ignore")
    out = {}
    for m in re.finditer(
            r"option\s+" + PREFIX + r"\.(\w+)\s*\{(.*?)\}",
            text, re.S):
        name, body = m.group(1), m.group(2)
        d = re.search(r"default\s*=\s*([\w.]+)", body)
        out[name] = d.group(1) if d else None
    return out


def read_in_lua():
    """Option names the Lua actually reads off the mod's own table."""
    seen = set()
    for path in LUA.rglob("*.lua"):
        src = path.read_text(encoding="utf-8", errors="ignore")
        # sv.X / sv2.X where sv came from SandboxVars.SurvivorAwareness,
        # plus the fully-qualified form.
        for m in re.finditer(r"\bsv[0-9]*\.(\w+)", src):
            seen.add(m.group(1))
        for m in re.finditer(PREFIX + r"\.(\w+)", src):
            seen.add(m.group(1))
    return seen


def lua_fallbacks():
    """Option name -> the literal the Lua falls back to."""
    out = {}
    for path in LUA.rglob("*.lua"):
        src = path.read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(
                r"\bsv[0-9]*\.(\w+)\s*\)?\s*(?:or|\bor\b)\s*"
                r"([0-9]+\.?[0-9]*|true|false)", src):
            out.setdefault(m.group(1), set()).add(m.group(2))
        for m in re.finditer(
                r"tonumber\(\s*sv[0-9]*\.(\w+)\s*\)\s*\)?\s*or\s*"
                r"([0-9]+\.?[0-9]*)", src):
            out.setdefault(m.group(1), set()).add(m.group(2))
    return out


def same_number(a, b):
    try:
        return abs(float(a) - float(b)) < 1e-9
    except (TypeError, ValueError):
        return str(a) == str(b)


def requested_keys():
    """Keys the Lua asks the engine for at runtime.

    getTextManager() is font metrics, not translation, and must not be
    counted - it is the only `getText`-prefixed name in this tree and
    reading it as a lookup would invent a request that is not there.
    """
    import re as _re
    out = []
    for path in LUA.rglob("*.lua"):
        src = path.read_text(encoding="utf-8", errors="ignore")
        for m in _re.finditer(
                r"\bgetText(?:OrNull)?\s*\(\s*[\"']([^\"']+)[\"']",
                src):
            out.append((str(path.relative_to(ROOT)).replace("\\", "/"),
                        src[:m.start()].count("\n") + 1, m.group(1)))
    return out


def shape_faults(trans_text):
    """[B33]'s class: a key that exists and is wrong for its slot.

    DayZero's whole explanation sat in its NAME, so the options screen
    showed a 130-character label where its twelve siblings showed a
    short name. Present, valid JSON, and wrong.
    """
    import json as _json
    faults = []
    try:
        d = _json.loads(trans_text)
    except ValueError as e:
        return [f"the translation file is not valid JSON: {e}"]

    for k, v in d.items():
        if not str(v).strip():
            faults.append(f"{k} has an empty value")

    seen = {}
    for k, v in d.items():
        seen.setdefault(v, []).append(k)
    for v, ks in seen.items():
        if len(ks) > 1:
            faults.append(f"{' and '.join(ks)} say the same thing: "
                          f"{str(v)[:44]!r}")

    names = {k: v for k, v in d.items() if not k.endswith("_tooltip")}
    if len(names) >= 4:
        lens = sorted(len(str(v)) for v in names.values())
        med = lens[len(lens) // 2]
        for k, v in names.items():
            if len(str(v)) > 3 * max(med, 1):
                faults.append(
                    f"{k} is {len(str(v))} characters where its "
                    f"siblings median {med} - an explanation in a "
                    "name slot renders as a label, not a tooltip")

    # [B37] The same class again, one slot over. Every widget that
    # owns a tooltip picks its wrap width the same way - ISTickBox:123,
    # ISComboBox:313, ISTextEntryBox:214, ISLabel:120, ISButton:327,
    # ISRadioButtons:61:
    #
    #     if string.contains(self.tooltip, "\n") then
    #         self.tooltipUI.maxLineWidth = 1000 -- don't wrap the lines
    #     else
    #         self.tooltipUI.maxLineWidth = 300
    #     end
    #
    # There is no third case, and the test is on PRESENCE, not length.
    # A tooltip with no break is laid out in a 300px column; ours ran
    # to 489 characters, which is about thirteen stacked lines that
    # follow the mouse and, off the lower options, leave the screen.
    # The break is written as the two characters backslash+n - the
    # engine's own idiom, 232 occurrences across the shipped EN
    # translations against a single real newline - and
    # SandboxOptions.lua:665 converts it before the widget sees it.
    for k, v in d.items():
        if not k.endswith("_tooltip"):
            continue
        text = str(v)
        if BREAK not in text:
            faults.append(
                f"{k} carries no line break, so its {len(text)} "
                "characters are laid out in a 300px column")
            continue
        for i, line in enumerate(text.split(BREAK), start=1):
            if len(line) > LINE_BUDGET:
                faults.append(
                    f"{k} line {i} is {len(line)} characters, past the "
                    f"{LINE_BUDGET} that fits the wide layout")
    return faults


def main():
    if not OPTS.exists() or not TRANS.exists():
        print("16) sandbox surface: SKIPPED (no options file)")
        return 0

    decl = declared()
    if not decl:
        print("16) sandbox surface: SKIPPED (parsed no options)")
        return 0

    trans = TRANS.read_text(encoding="utf-8", errors="ignore")
    read = read_in_lua()
    falls = lua_fallbacks()

    dead, untranslated, drifted = [], [], []

    for name, default in sorted(decl.items()):
        if name not in read:
            dead.append(name)
        key = f'"Sandbox_{PREFIX}_{name}"'
        tip = f'"Sandbox_{PREFIX}_{name}_tooltip"'
        missing = []
        if key not in trans:
            missing.append("name")
        if tip not in trans:
            missing.append("tooltip")
        if missing:
            untranslated.append(f"{name} ({', '.join(missing)})")
        if default is not None and name in falls:
            for lit in falls[name]:
                if not same_number(lit, default):
                    drifted.append(
                        f"{name}: screen says {default}, Lua falls "
                        f"back to {lit}")

    # [B33] A key asked for at runtime that nothing declares renders
    # as the raw identifier on screen - the jankiest outcome there is.
    import json as _json
    try:
        declared_keys = set(_json.loads(trans))
    except ValueError:
        declared_keys = set()
    unresolved = [f"{f}:{n} asks for {k}, which nothing declares"
                  for f, n, k in requested_keys()
                  if k not in declared_keys]

    shape = shape_faults(trans)

    bad = bool(dead or untranslated or drifted or unresolved or shape)
    if not bad:
        print(f"16) sandbox surface: {len(decl)} options, all read, "
              f"all named and explained, defaults agree; "
              f"{len(declared_keys)} translation keys, no empty, "
              "duplicate or mis-slotted values")
        return 0

    print("16) sandbox surface:")
    for n in dead:
        print(f"      DEAD DIAL: {n} is on the screen and nothing "
              "reads it")
    for n in untranslated:
        print(f"      UNEXPLAINED: {n}")
    for n in drifted:
        print(f"      DEFAULT DRIFT: {n}")
    for n in unresolved:
        print(f"      RAW KEY ON SCREEN: {n}")
    for n in shape:
        print(f"      WRONG SLOT: {n}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
