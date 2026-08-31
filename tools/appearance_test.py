#!/usr/bin/env python3
r"""Border 27 - the age gradient is visible, and reversible.

[B38]. The operator ruled a visible age gradient important - age
that can be seen, not just stored.

[B37] gave everybody an age; [B38] made it read. Both were invisible
from inside the game - a sixty-two year old and a twenty-two year old
stood in the road looking identical.

Two invariants, and the second matters more than it looks:

  1. **The gradient is a gradient.** Greying must vary continuously
     with age and vary BETWEEN people of the same age - a room of
     fifty year olds has one grey head and one still dark. A rule that
     greys everyone over fifty identically is a threshold wearing a
     gradient's clothes.

  2. **The natural colour is never written.** Only the displayed
     colour moves. What a person's hair actually was is still under
     it, so this is undone by doing nothing - which is what makes it
     safe to ship into two live saves.

Every engine accessor it leans on is verified from the jar rather than
remembered, and named here so a build that moves one fails loudly:
`getDescriptor`, `getHumanVisual`, `getNaturalHairColor`,
`setHairColor`, `getNaturalBeardColor`, `setBeardColor`,
`getRedFloat`/`getGreenFloat`/`getBlueFloat`, `ImmutableColor.new`,
`resetModelNextFrame`.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
APP = LUA / "client" / "SAO_Appearance.lua"
HIST = LUA / "shared" / "SAO_History.lua"
POP = LUA / "client" / "SAO_Population.lua"


def const(src, name):
    m = re.search(rf"^local {name} = ([\d.]+)\s*(?:--.*)?$", src, re.M)
    if not m:
        raise SystemExit(f"appearance_test: {name} moved; this mirror is blind")
    return float(m.group(1))


def hash_of(text, salt):
    v = 2166136261
    for ch in f"{text}:{salt}":
        v = (v * 16777619 + ord(ch)) % 4294967296
    return v


def bands(src):
    m = re.search(r"local AGE_BANDS = \{(.*?)\n\}", src, re.S)
    return [(int(a), int(b), int(w)) for a, b, w in re.findall(
        r"from = (\d+), to = (\d+), weight = (\d+)", m.group(1))]


def age_of(sid, bnds):
    roll = hash_of(sid, "age") % 100
    seen = 0
    for lo, hi, w in bnds:
        seen += w
        if roll < seen:
            return lo + (hash_of(sid, "ageIn") % (hi - lo + 1))
    return 34


def main():
    src = APP.read_text(encoding="utf-8", errors="ignore")
    hsrc = HIST.read_text(encoding="utf-8", errors="ignore")
    psrc = POP.read_text(encoding="utf-8", errors="ignore")

    onset_min = const(src, "ONSET_MIN")
    onset_span = const(src, "ONSET_SPAN")
    takes = const(src, "TAKES_YEARS")
    greyest = const(src, "GREYEST")
    bnds = bands(hsrc)

    def onset(sid):
        return onset_min + (hash_of(sid, "grey") % int(onset_span))

    def grey(sid, age):
        o = onset(sid)
        if age <= o:
            return 0.0
        return min((age - o) / takes, greyest)

    ok = {}
    print("=" * 70)
    print("AGE, ON THE HEAD")
    print("=" * 70)
    print(f"  greying starts between {onset_min:.0f} and "
          f"{onset_min + onset_span - 1:.0f}, takes {takes:.0f} years, "
          f"never past {greyest:.0%}")
    print()

    ids = [f"sao-{i}" for i in range(1, 1201)]
    ages = {i: age_of(i, bnds) for i in ids}

    print("  age band   any grey   mean greyness")
    for lo, hi in ((19, 29), (30, 39), (40, 49), (50, 59), (60, 68)):
        band = [i for i in ids if lo <= ages[i] <= hi]
        if not band:
            continue
        greys = [grey(i, ages[i]) for i in band]
        any_grey = sum(1 for g in greys if g > 0.02)
        print(f"  {lo:>3}-{hi:<3}    {100 * any_grey / len(band):>6.0f}%    "
              f"{sum(greys) / len(greys):>10.2f}")

    # 1. It is a gradient across age.
    def mean_at(lo, hi):
        band = [i for i in ids if lo <= ages[i] <= hi]
        return sum(grey(i, ages[i]) for i in band) / max(len(band), 1)

    steps = [mean_at(*b) for b in
             ((19, 29), (30, 39), (40, 49), (50, 59), (60, 68))]
    ok["greying rises with age"] = all(
        b >= a for a, b in zip(steps, steps[1:]))
    ok["the young are not grey"] = steps[0] < 0.05
    ok["the old mostly are"] = steps[-1] > 0.4

    # 2. And a gradient BETWEEN people of one age - the part that
    # separates this from a threshold at fifty.
    fifties = [i for i in ids if ages[i] == 52]
    spread = 0.0
    if len(fifties) > 3:
        vals = [grey(i, 52) for i in fifties]
        spread = max(vals) - min(vals)
    print(f"\n  two people both aged 52 differ in greyness by up to "
          f"{spread:.2f}")
    ok["people of one age differ"] = spread > 0.2

    ok["nobody goes fully white"] = max(
        grey(i, 68) for i in ids) <= greyest + 1e-9

    # 3. The natural colour is never written.
    writes_natural = re.findall(r"setNaturalHairColor|setNaturalBeardColor",
                                src)
    ok["the natural colour is never written"] = not writes_natural
    print(f"  writes to the natural colour: "
          f"{writes_natural or 'none'} - undone by doing nothing")

    links = {
        "reads the person's own age": "SAO.History.ageOf(rec.id)" in src,
        "onset is a fact about them": 'hashOf(id, "grey")' in src,
        "reaches the visual":
            "body:getDescriptor():getHumanVisual()" in src,
        "moves hair": '"getNaturalHairColor", "setHairColor"' in src,
        "and beard": '"getNaturalBeardColor", "setBeardColor"' in src,
        "builds a real colour": "ImmutableColor.new(nr, ng, nb)" in src,
        "asks the model to redraw": "body:resetModelNextFrame()" in src,
        "applied once per person": "rec.greyApplied" in src,
        "wired where a body first exists":
            "pcall(SAO.Appearance.applyAge, rec, body)" in psrc,
    }
    print()
    print("  THE SHIPPED LINKS")
    for k, v in links.items():
        print(f"    {'yes' if v else 'NO '}  {k}")

    print()
    print("VERDICT:")
    for k, v in ok.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
    good = all(ok.values()) and all(links.values())
    if not good:
        print("  FAULT: age is not visible as a gradient, or the natural "
              "colour is being overwritten")
        return 1
    print(f"  27) appearance: greying {onset_min:.0f}-"
          f"{onset_min + onset_span - 1:.0f} onset over {takes:.0f} years, "
          "natural colour preserved")
    return 0


if __name__ == "__main__":
    sys.exit(main())
