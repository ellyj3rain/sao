#!/usr/bin/env python3
r"""[B35] A policy that governed nothing.

Four creeds each adopt a ration policy, mapped in SAO_Standing:

    order = "watch-first"   mercy = "weak-first"
    wall  = "house-first"   road  = "carry-light"

Three of them change behaviour. `carry-light` was assigned, announced
on the wire as "light packs, nothing held back", and then read by no
gate anywhere - so a road house behaved exactly like a house with no
policy at all. Authored intent, unreachable.

This counts, per policy value, how many places READ it as a behaviour
gate, and fails when a policy the map can assign has none. A policy
that only the radio mentions is a policy in name.

Method notes, because getting here took two wrong passes:

  - A literal-matching sweep of `X == "y"` / `X = "y"` reported three
    of five DESIGNATIONS as never assigned. They are assigned through
    variables - `rec.designation = job`, `= bestJob` - so the sweep
    was measuring syntax, not reachability, and every one of those was
    a false negative.

  - The same sweep never saw `carry-light` at all, because it is
    assigned inside a TABLE LITERAL. It surfaced only when the map was
    read directly. So the assignment side is taken from the map here,
    not from a pattern.

The wire phrasings in SAO_Radio are deliberately NOT counted as reads:
saying a thing on the radio is not governing by it, and counting them
would have reported this defect as healthy.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
ST = LUA / "shared" / "SAO_Standing.lua"


def policy_map():
    """creed -> policy, read from the map that assigns it."""
    src = ST.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"local policy = creedName0 and \(\{(.*?)\}\)", src,
                  re.S)
    if not m:
        raise SystemExit("policy_reach_test: the creed->policy map "
                         "moved; this tool is blind")
    return dict(re.findall(r"(\w+)\s*=\s*\"([\w-]+)\"", m.group(1)))


def main():
    mapping = policy_map()
    print("=" * 70)
    print("Ration policies, and what actually reads them")
    print("=" * 70)
    for creed, pol in sorted(mapping.items()):
        print(f"  {creed:<8} -> {pol}")

    reads = {p: [] for p in mapping.values()}
    for path in sorted(LUA.rglob("*.lua")):
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        s = path.read_text(encoding="utf-8", errors="ignore")
        for pol in reads:
            for m in re.finditer(r'==\s*"' + re.escape(pol) + r'"'
                                 r'|"' + re.escape(pol) + r'"\s*==', s):
                ln = s[:m.start()].count("\n") + 1
                # The radio's phrasing table SAYS the policy; it does
                # not govern by it.
                if "SAO_Radio.lua" in rel:
                    continue
                reads[pol].append(f"{rel.split('/')[-1]}:{ln}")

    print()
    print("=" * 70)
    print("BEHAVIOUR READS (radio phrasings excluded, they only say it)")
    print("=" * 70)
    dead = []
    for pol in sorted(reads):
        n = len(reads[pol])
        print(f"  {pol:<14} {n:>2}  {', '.join(reads[pol][:4])}")
        if n == 0:
            dead.append(pol)

    print()
    print("VERDICT:")
    print(f"  policies a creed can adopt: {len(set(mapping.values()))}")
    print(f"  governing nothing:          {len(dead)} {dead}")
    if dead:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
