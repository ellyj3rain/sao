#!/usr/bin/env python3
r"""Border 19 - mod.info is the first thing the game reads.

A key the loader does not recognise is not an error. It is ignored, in
silence, and whatever it was meant to declare simply never happens -
the same shape as [B33]'s jar, where everything looked fine from inside
a play session.

The valid key names are not assumed here. They were read out of the
bytecode of the two parsers that actually consume the file:

  zombie.gameStates.ChooseGameInfo   (projectzomboid.jar)
      author category description icon id loadModAfter loadModBefore
      modversion name pack poster require tiledef url versionMax
      versionMin

  me.zed_0xff.zombie_buddy.JavaModInfo.parseModInfoFile
      (ZombieBuddy.jar) - lowercases each line, then startsWith against
      javajarfile= javapkgname= zbversionmin= zbversionmax=
      javapreload= name=
      so ZombieBuddy's keys are CASE-INSENSITIVE and `ZBVersionMin`
      matches `zbversionmin=` correctly.

What this gates
  1. Every key declared is one of those parsers reads.
  2. Every file a key names exists in the shipped tree.
  3. The root and versioned mod.info agree on every shared key -
     ZombieBuddy calls parseMerged() across both, so a divergence
     resolves by merge order rather than by intent.

What it reports without gating
  - Supported keys that are absent. `poster` and `icon` are the ones
    that show: every working mod checked declares them, and without
    them the mod carries no art in the game's own list. That is a
    presentation decision, not a defect, so it is said and not failed.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOD = ROOT / "mod"

PZ_KEYS = {
    "author", "category", "description", "icon", "id", "loadmodafter",
    "loadmodbefore", "modversion", "name", "pack", "poster", "require",
    "tiledef", "url", "versionmax", "versionmin",
}
ZB_KEYS = {
    "javajarfile", "javapkgname", "zbversionmin", "zbversionmax",
    "javapreload",
}
VALID = PZ_KEYS | ZB_KEYS

# Keys whose value names a file that must exist.
FILE_KEYS = {"poster", "icon", "javajarfile"}

# Supported, absent, and worth saying so.
WORTH_HAVING = {"poster", "icon"}


def parse(path):
    """key(lowercased) -> (original key, value, line number)."""
    out = {}
    for n, line in enumerate(
            path.read_text(encoding="utf-8", errors="ignore")
            .splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        k, v = s.split("=", 1)
        out[k.strip().lower()] = (k.strip(), v.strip(), n)
    return out


def main():
    infos = sorted(MOD.rglob("mod.info"))
    if not infos:
        print("19) mod.info: MISSING - the game would not list the mod")
        return 1

    unknown, absent_files, disagree = [], [], []
    parsed = {}

    for path in infos:
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        keys = parse(path)
        parsed[rel] = keys
        for low, (orig, val, n) in keys.items():
            if low not in VALID:
                unknown.append(f"{rel}:{n}  {orig}= is read by neither "
                               "parser and is silently ignored")
            if low in FILE_KEYS and val:
                # Resolve beside this mod.info, then beside the version
                # directory - ZombieBuddy resolves the jar against the
                # version dir, and PZ resolves art against the mod dir.
                here = (path.parent / val)
                alt = [p / val for p in MOD.glob("*/") if p.is_dir()]
                if not here.exists() and not any(
                        a.exists() for a in alt):
                    absent_files.append(
                        f"{rel}:{n}  {orig}={val} names a file that "
                        "does not exist in the shipped tree")

    if len(parsed) > 1:
        names = sorted(parsed)
        base = parsed[names[0]]
        for other in names[1:]:
            for low, (orig, val, n) in parsed[other].items():
                if low in base and base[low][1] != val:
                    disagree.append(
                        f"{orig}: {names[0]} says {base[low][1]!r}, "
                        f"{other} says {val!r}")

    bad = unknown or absent_files or disagree
    if bad:
        print("19) mod.info:")
        for u in unknown:
            print(f"      UNKNOWN KEY: {u}")
        for a in absent_files:
            print(f"      MISSING FILE: {a}")
        for d in disagree:
            print(f"      DISAGREE: {d}")
        return 1

    declared = set()
    for keys in parsed.values():
        declared |= set(keys)
    missing = sorted(WORTH_HAVING - declared)
    note = f"; no {', '.join(missing)}" if missing else ""
    print(f"19) mod.info: {len(infos)} file(s), "
          f"{len(declared)} distinct keys, all read by a real parser, "
          f"all named files present{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
