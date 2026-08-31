#!/usr/bin/env python3
r"""[B33] The bridge is the widest silent-failure surface in the mod.

Nearly every call into Java sits inside a pcall:

    pcall(function()
        return SAOJavaBridge:spendVehicleFuel(body, 15, name, share)
    end)

which means a misnamed method, a wrong arity, or an argument of the
wrong type raises inside the pcall, is swallowed, and the feature is
simply dead - forever, silently, with nothing raised anywhere. That is
the [B24] class in its purest form, and there are 174 call sites.

This compares the Lua call sites against the COMPILED bridge class,
because the compiled surface is the one that ships. javap, not the
source: the source is what was meant, the class file is what runs.

What it checks
  1. NAME     - every method Lua calls exists on the bridge.
  2. ARITY    - the argument count matches some overload.
  3. TYPE     - where a literal makes the Lua type knowable, it can
                actually reach the declared Java parameter. Only
                unambiguous cases are flagged: a string literal into a
                numeric or boolean primitive, a number literal into
                java.lang.String, nil into any primitive. Kahlua
                coerces loosely and this refuses to guess about it.

What it CANNOT reach, reported rather than omitted
  - calls made through an alias (`local b = SAOJavaBridge; b:m()`)
  - calls whose method name is computed at runtime
  - argument types behind a variable or a function return
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
OUT = ROOT / "java" / "out"
JAVAP = pathlib.Path(
    r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin\javap.exe")
BRIDGE = "com.sao.bridge.SAOBridge"
GLOBAL = "SAOJavaBridge"

# Java parameter types that a Lua nil cannot occupy.
PRIMITIVES = {"int", "long", "short", "byte", "char",
              "double", "float", "boolean"}
NUMERIC = {"int", "long", "short", "byte", "double", "float"}


# ---------------------------------------------------------------- Lua

def strip_lua(src):
    """Blank out comments and string bodies, preserving offsets.

    Offsets must be preserved so a call site's line number stays true
    and so paren/comma scanning sees the real structure. Replacing a
    string with spaces of equal length does both.
    """
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        # Long bracket, as comment body or as string: [[ or [=*[
        m = re.match(r"\[(=*)\[", src[i:]) if c == "[" else None
        if c == "-" and src.startswith("--", i):
            m2 = re.match(r"--\[(=*)\[", src[i:])
            if m2:
                close = "]" + m2.group(1) + "]"
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
        if m:
            close = "]" + m.group(1) + "]"
            end = src.find(close, i)
            end = n if end < 0 else end + len(close)
            for k in range(i, end):
                if out[k] != "\n":
                    out[k] = " "
            i = end
            continue
        if c in "'\"":
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == c or src[j] == "\n":
                    break
                j += 1
            # Keep the quotes so a literal is still recognisable as a
            # string; blank only the body.
            for k in range(i + 1, min(j, n)):
                out[k] = "_"
            i = min(j + 1, n)
            continue
        i += 1
    return "".join(out)


def split_args(text):
    """Split a call's argument text on TOP-LEVEL commas."""
    args, depth, cur = [], 0, ""
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            args.append(cur.strip())
            cur = ""
            continue
        cur += ch
    if cur.strip():
        args.append(cur.strip())
    return args


def call_sites():
    """Every SAOJavaBridge:method(...) in the Lua tree."""
    sites, aliases = [], []
    for path in sorted(LUA.rglob("*.lua")):
        raw = path.read_text(encoding="utf-8", errors="ignore")
        src = strip_lua(raw)
        rel = str(path.relative_to(ROOT)).replace("\\", "/")

        # Coverage gap: the global bound to a local, then called
        # later. `local x = SAOJavaBridge:m(...)` is an ordinary call
        # site, not an alias, and the lookahead is what separates
        # them - without it every same-line assignment reads as an
        # unchecked alias and the tool reports six holes it does not
        # have.
        #
        # [B51] A binding is only a coverage hole if something is
        # CALLED through it. This tool reported one unchecked alias on
        # every run of the gate for
        #
        #     local jv = SAOJavaBridge and SAOJavaBridge:getVersion()
        #
        # where `jv` holds a version string, and nothing is called
        # through it anywhere - the lookahead only rejects a `:` or `.`
        # immediately after the global, and here what follows is `and`.
        #
        # Tightening the binding pattern would be the wrong repair: a
        # real alias written `local b = SAOJavaBridge or nil` would
        # stop being seen, and MISSING an alias is a silent hole while
        # naming a harmless one is only noise. So the binding is still
        # matched loosely and the question asked afterwards is the
        # question that matters.
        for m in re.finditer(
                r"local\s+(\w+)\s*=\s*" + GLOBAL + r"\b(?!\s*[:.])",
                src):
            name = m.group(1)
            after = src[m.end():]
            if not re.search(r"(?<![\w.])" + re.escape(name)
                             + r"\s*[:.]\s*\w+\s*\(", after):
                continue
            aliases.append((rel, src[:m.start()].count("\n") + 1, name))

        for m in re.finditer(GLOBAL + r"\s*:\s*(\w+)\s*\(", src):
            name = m.group(1)
            start = m.end()          # just past the '('
            depth, j = 1, start
            while j < len(src) and depth:
                if src[j] in "([{":
                    depth += 1
                elif src[j] in ")]}":
                    depth -= 1
                j += 1
            inner = src[start:j - 1]
            sites.append({
                "file": rel,
                "line": src[:m.start()].count("\n") + 1,
                "name": name,
                "args": split_args(inner),
            })
    return sites, aliases


# --------------------------------------------------------------- Java

def split_params(text):
    """Split a javap parameter list on top-level commas (generics)."""
    out, depth, cur = [], 0, ""
    for ch in text:
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
            continue
        cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def bridge_methods():
    """name -> list of parameter-type lists, from the CLASS FILE."""
    if not JAVAP.exists():
        return None, f"javap not found at {JAVAP}"
    if not (OUT / "com" / "sao" / "bridge" / "SAOBridge.class").exists():
        return None, ("java/out/com/sao/bridge/SAOBridge.class is "
                      "missing - run tools/build-java.sh first")
    proc = subprocess.run(
        [str(JAVAP), "-p", "-cp", str(OUT), BRIDGE],
        capture_output=True, text=True, errors="ignore")
    if proc.returncode != 0:
        return None, f"javap failed: {proc.stderr.strip()[:200]}"
    methods = {}
    for line in proc.stdout.splitlines():
        m = re.match(
            r"\s+public\s+(?:static\s+)?(?:final\s+)?"
            r"[\w.$<>\[\], ]+\s+(\w+)\(([^)]*)\);", line)
        if not m:
            continue
        methods.setdefault(m.group(1), []).append(
            split_params(m.group(2)))
    return methods, None


# ---------------------------------------------------------------- fit

def lua_type(arg):
    """The Lua type of an argument, when a literal makes it knowable."""
    a = arg.strip()
    if re.fullmatch(r"-?\d+(\.\d+)?", a):
        return "number"
    if re.fullmatch(r"""(['"])_*\1""", a):
        return "string"
    if a in ("true", "false"):
        return "boolean"
    if a == "nil":
        return "nil"
    if a.startswith("tostring("):
        return "string"
    if a.startswith("tonumber("):
        return "number"
    return None


def bad_fit(lt, jt):
    """True only where the mismatch is unambiguous."""
    base = jt.split("<")[0].strip()
    if lt is None:
        return False
    if lt == "nil":
        return base in PRIMITIVES
    if lt == "string":
        return base in NUMERIC or base == "boolean"
    if lt == "number":
        return base in ("java.lang.String", "boolean")
    if lt == "boolean":
        return base in NUMERIC or base == "java.lang.String"
    return False


def main():
    methods, err = bridge_methods()
    if err:
        print(f"18) bridge: SKIPPED - {err}")
        return 0

    sites, aliases = call_sites()
    missing, arity, types = [], [], []

    for s in sites:
        overloads = methods.get(s["name"])
        if overloads is None:
            missing.append(s)
            continue
        n = len(s["args"])
        if not any(len(p) == n for p in overloads):
            arity.append((s, sorted({len(p) for p in overloads})))
            continue
        fits = [p for p in overloads if len(p) == n]
        if len(fits) != 1:
            continue          # ambiguous overload: refuse to guess
        for idx, (a, jt) in enumerate(zip(s["args"], fits[0])):
            lt = lua_type(a)
            if bad_fit(lt, jt):
                types.append((s, idx + 1, a, lt, jt))

    called = {s["name"] for s in sites}
    print(f"18) bridge: {len(methods)} public methods on "
          f"{BRIDGE.split('.')[-1]} (from the class file)")
    print(f"call sites:     {len(sites)} across the Lua tree, "
          f"{len(called)} distinct methods")
    print(f"never called:   {len(set(methods) - called)} bridge "
          "methods no Lua reaches")

    if aliases:
        print(f"UNCHECKED: {len(aliases)} alias binding(s) - calls "
              "through these are invisible to this tool")
        for rel, ln, nm in aliases:
            print(f"    {rel}:{ln}  local {nm} = {GLOBAL}")

    bad = bool(missing or arity or types)
    if not bad:
        print("MATCH: every call site names a real method, with an "
              "arity some overload accepts, and no literal argument "
              "that cannot reach its parameter.")
        return 0

    print()
    for s in missing:
        print(f"  NO SUCH METHOD: {s['file']}:{s['line']}  "
              f"{GLOBAL}:{s['name']}() - dies inside its pcall")
    for s, ok in arity:
        print(f"  ARITY: {s['file']}:{s['line']}  {s['name']} called "
              f"with {len(s['args'])}, bridge accepts {ok}")
    for s, pos, a, lt, jt in types:
        print(f"  TYPE: {s['file']}:{s['line']}  {s['name']} arg {pos} "
              f"is {lt} ({a}), parameter is {jt}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
