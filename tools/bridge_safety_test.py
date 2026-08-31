#!/usr/bin/env python3
r"""Border 71 - a Java throw into Kahlua takes the Lua frame with it.

`SAOBridge`'s own class comment states a contract:

    Every method is exception-safe: a Java throw into Kahlua would take
    down the calling Lua frame, so failures return null/false and log
    to SAOAgent.log instead.

It is the load-bearing promise of the whole bridge. Every one of these
methods is called from Lua, most of them from inside a `pcall`, which
means a throw does not merely fail - it fails **the way [B44] and
[B42] both describe**, with the county quietly doing less and nothing
saying why.

Nothing checked it. And checking it by eye is not realistic: of 112
public methods, 60 carry no `catch` of their own, because they delegate.
Following one hop leaves 17. Following two leaves none - `sourceItem`
reaches `validSource`, which catches; `hasRippableCloth` reaches
`findRippableCloth`, which catches. A person asked to verify this
contract would have to walk that graph for every method, and would do
it once.

WHAT COUNTS AS SAFE
-------------------
Walking outward from each public method, three ways to be safe:

  1. **It catches.** `catch (Throwable` or `catch (Exception` in the
     body.
  2. **Everything it calls is safe**, transitively, through our own
     `com.sao` classes.
  3. **It cannot throw.** No call into engine code at all - only
     `instanceof`, our own fields and maps, arithmetic, and returns of
     constants. `isShell` is `return object instanceof
     SAOIsoPlayerShell;` and needs no guard to be safe.

Anything else is a path from Lua into the engine with no net under it.

The depth limit is 4. A bridge method that needs more than four hops to
reach a guard is one nobody can reason about anyway, and saying so is
the point rather than a limitation.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
JAVA = ROOT / "java" / "src" / "com" / "sao"
BRIDGE = "SAOBridge.java"
DEPTH = 4

CATCH = ("catch (Throwable", "catch (Exception")
PUBLIC = re.compile(
    r"^    public\s+(?!static\s+final)([\w.<>\[\]]+)\s+(\w+)\s*\(", re.M)
ANY_METHOD = re.compile(
    r"^    (?:public|private|protected|static)[^;=]*?\b(\w+)\s*\(", re.M)
# A call into one of our own classes: `SAOFoo.bar(` or `com.sao.x.SAOFoo.bar(`
OURS = re.compile(r"(?:com\.sao\.\w+\.)?(SAO\w+)\.(\w+)\s*\(")
# Anything that could reach the engine: a method call on a reference.
ENGINE_CALL = re.compile(r"\b\w+\s*\.\s*\w+\s*\(")


def bodies(src):
    """Every method in one file, by name, as text."""
    out = {}
    for m in ANY_METHOD.finditer(src):
        i = src.find("{", m.end())
        if i < 0:
            continue
        depth, j = 0, i
        while j < len(src):
            if src[j] == "{":
                depth += 1
            elif src[j] == "}":
                depth -= 1
                if depth == 0:
                    out.setdefault(m.group(1), src[i:j])
                    break
            j += 1
    return out


def cannot_throw(body):
    """No call that could reach engine code.

    Calls on one of our own SCREAMING_CASE constants do not count - the
    remembered-source maps are `WeakHashMap`s we own, and `remove` on
    one cannot reach the engine or throw. The first draft of this
    border hardcoded four guessed names (`SOURCES`, `WATER`, ...) and
    flagged `clearWaterSource`, `clearWeaponSource` and
    `clearAmmoSource` because the real fields are `WATER_SOURCES`,
    `WEAPON_SOURCES` and `AMMO_SOURCES`. Guessing at identifiers is how
    an instrument invents findings; the shape is what to match on.
    """
    stripped = OURS.sub("", body)
    stripped = re.sub(r"\b[A-Z][A-Z0-9_]{2,}\s*\.\s*\w+\s*\(", "", stripped)
    return not ENGINE_CALL.search(stripped)


def main():
    faults = []
    print("=" * 74)
    print("A JAVA THROW INTO KAHLUA")
    print("=" * 74)

    if not JAVA.exists():
        print()
        print("VERDICT:")
        print("  FAULT: the Java source is gone, so the bridge contract was "
              "not checked at all")
        return 1

    files = {p.name: p.read_text(encoding="utf-8", errors="ignore")
             for p in JAVA.rglob("*.java")}
    by_class = {p.stem: bodies(files[p.name]) for p in JAVA.rglob("*.java")}
    bridge = files.get(BRIDGE)
    if bridge is None:
        print()
        print("VERDICT:")
        print(f"  FAULT: {BRIDGE} is gone - the whole Lua-facing surface "
              "with it")
        return 1

    def safe(cls, meth, depth, seen):
        key = (cls, meth)
        if key in seen:
            return True          # recursion: not a new way to throw
        if depth > DEPTH:
            return False
        body = by_class.get(cls, {}).get(meth)
        if body is None:
            return False
        if any(c in body for c in CATCH):
            return True
        seen = seen | {key}
        calls = set(OURS.findall(body))
        if not calls:
            return cannot_throw(body)
        if not cannot_throw(body):
            return False
        return all(safe(c, m, depth + 1, seen) for c, m in calls)

    total, unsafe = 0, []
    for m in PUBLIC.finditer(bridge):
        total += 1
        name = m.group(2)
        if not safe("SAOBridge", name, 1, frozenset()):
            unsafe.append((name, bridge.count("\n", 0, m.start()) + 1))

    print(f"  public bridge methods  : {total}")
    print(f"  reach a guard, or cannot throw: {total - len(unsafe)}")
    print(f"  neither                : {len(unsafe)}")

    if total == 0:
        faults.append(
            "no public method was found on the bridge, which cannot be true "
            "of the class Lua calls for everything - the reading failed "
            "rather than the code being clean")

    for name, line in unsafe:
        faults.append(
            f"{BRIDGE}:{line} `{name}` can reach engine code with no catch "
            f"on any path within {DEPTH} hops. Lua calls this, usually from "
            "inside a pcall - so a throw here does not report, it just "
            "makes the county quietly do less, which is the shape [B42] "
            "and [B44] each cost a batch to find. Catch it, or delegate "
            "to something that does")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print(f"  71) bridge safety: all {total} Lua-facing methods either "
          "catch, reach something that catches, or cannot throw at all")
    return 0


if __name__ == "__main__":
    sys.exit(main())
