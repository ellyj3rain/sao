#!/usr/bin/env python3
r"""[B36] The claim, end to end, as one chain.

Five batches changed the claim lifecycle in five places, and no check
has ever run the whole thing:

    [B34]  founding derives the extent from the building footprint,
            and "Take this in too" absorbs whole outbuildings
    [B35]  a place belief is unlearned by proximity when the claim
            ends - `places` was the one table nothing ever cleared
    [B35]  the dormant learner admits player keys, so survivors can
            learn the player's ground by drifting past it
    [B35]  base selection admits player keys, so a survivor will not
            build over ground the player holds

Each was controlled on its own. A chain is not the sum of its links:
what matters is whether a claim founded in one place is respected in
the second, forgotten in the third, and never trampled in the fourth -
with the SAME key spelling running through all of them.

This drives the whole lifecycle over a modelled county, and asserts
each shipped link is present rather than modelling it and hoping.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"


def shipped(rel):
    return (LUA / rel).read_text(encoding="utf-8", errors="ignore")


# --- the model -------------------------------------------------------

class County:
    """Claims, and what each survivor believes about them."""

    def __init__(self):
        self.claims = {}          # ownerKey -> (minX, minY, maxX, maxY)
        self.places = {}          # believer -> {ownerKey: bounds}

    def found(self, owner, bounds):
        self.claims[owner] = bounds

    def release(self, owner):
        self.claims.pop(owner, None)

    def near(self, bounds, x, y, reach):
        return (bounds[0] - reach <= x <= bounds[2] + reach
                and bounds[1] - reach <= y <= bounds[3] + reach)

    def drift_past(self, who, x, y, reach=8):
        """[B35] learn what is held; [B35] forget what is not."""
        b = self.places.setdefault(who, {})
        for owner, bounds in self.claims.items():
            if owner != who and self.near(bounds, x, y, reach):
                b[owner] = bounds
        for owner in list(b):
            if self.near(b[owner], x, y, reach) \
                    and owner not in self.claims:
                del b[owner]

    def believes_claimed(self, who, x, y):
        for owner, bounds in self.places.get(who, {}).items():
            if bounds[0] <= x <= bounds[2] and bounds[1] <= y <= bounds[3]:
                return owner
        return None

    def would_build_at(self, who, x, y):
        """[B35] refuse ground somebody already holds."""
        for owner, bounds in self.claims.items():
            if owner != who and bounds[0] <= x <= bounds[2] \
                    and bounds[1] <= y <= bounds[3]:
                return False
        return True


def main():
    PLAYER, SURV = "player:Bob", "sao-7"
    HOUSE = (100, 100, 112, 108)          # a footprint, not a square
    ok = {}

    c = County()
    print("=" * 70)
    print("THE LIFECYCLE, driven")
    print("=" * 70)

    c.found(PLAYER, HOUSE)
    print(f"  1. the player founds {HOUSE} "
          f"({HOUSE[2]-HOUSE[0]+1} by {HOUSE[3]-HOUSE[1]+1})")

    # A survivor who has never been near it knows nothing.
    ok["unseen"] = c.believes_claimed(SURV, 106, 104) is None
    print(f"  2. a survivor who has not been near it believes nothing: "
          f"{ok['unseen']}")

    c.drift_past(SURV, 106, 104)
    ok["learned"] = c.believes_claimed(SURV, 106, 104) == PLAYER
    print(f"  3. after drifting through it, they know it is the "
          f"player's: {ok['learned']}")

    ok["respected"] = not c.would_build_at(SURV, 106, 104)
    print(f"  4. and will not build there: {ok['respected']}")

    c.release(PLAYER)
    ok["stale"] = c.believes_claimed(SURV, 106, 104) == PLAYER
    print(f"  5. the player releases it - the survivor still believes, "
          f"having not looked: {ok['stale']}")

    ok["free"] = c.would_build_at(SURV, 106, 104)
    print(f"  6. but the ground is free to build on again: "
          f"{ok['free']}")

    c.drift_past(SURV, 106, 104)
    ok["unlearned"] = c.believes_claimed(SURV, 106, 104) is None
    print(f"  7. once they walk past again, they forget it: "
          f"{ok['unlearned']}")

    # A second survivor far away must not forget by proxy.
    c.found(PLAYER, HOUSE)
    c.drift_past("sao-9", 106, 104)
    c.release(PLAYER)
    c.drift_past("sao-9", 400, 400)
    ok["distant"] = c.believes_claimed("sao-9", 106, 104) == PLAYER
    print(f"  8. someone far away does NOT forget by proxy: "
          f"{ok['distant']}")

    print()
    print("=" * 70)
    print("THE SHIPPED LINKS - modelled above, required below")
    print("=" * 70)
    links = {
        "[B34] footprint founds the claim":
            "buildingBoundsAt" in shipped("shared/SAO_Standing.lua"),
        "[B34] growClaim absorbs a whole building":
            "S.groundAround(body, x, y, 0)"
            in shipped("shared/SAO_Standing.lua"),
        "[B35] observe unlearns a freed place":
            re.search(r"b\.places\[ownerKey\] = nil",
                      shipped("shared/SAO_Perception.lua")) is not None,
        # [B42] These two moved. Both were written inside dormantLife,
        # whose loop gates on `not SAO.Body.get(id)`, so the drift-past
        # rule - un-teaching included, and [B35]'s player branch -
        # governed only survivors with no loaded body. They now live in
        # P.learnGroundNear, which BOTH halves read; Border 35 holds
        # that both still do, and that nobody spells it twice.
        "[B35] the drift-past unlearns too":
            "bU.places[ownerKey] = nil"
            in shipped("shared/SAO_Perception.lua"),
        "[B35] the drift-past learner admits player keys":
            "isPlayerKey(ownerId)"
            in shipped("shared/SAO_Perception.lua"),
        "[B35] base selection admits player keys":
            "isPlayerKey(owner)"
            in shipped("client/SAO_Controller.lua"),
        # [B37] The chain was invisible from inside the game: four
        # batches changed how the county treats your ground and
        # nothing said so anywhere. The Ledger now reports the extent
        # and how many survivors have actually learned it - which is
        # also the only way to WATCH the spread happen, since knowing
        # is per-survivor and travels on foot.
        "[B37] the Ledger reports your ground and who knows it":
            "Your ground - " in shipped("client/SAO_UI.lua")
            and "b.places[myKey]" in shipped("client/SAO_UI.lua"),
    }
    for k, v in links.items():
        print(f"  {'yes' if v else 'NO '}  {k}")

    print()
    print("VERDICT:")
    for k, v in ok.items():
        print(f"  {k:<12} {v}")
    all_ok = all(ok.values()) and all(links.values())
    print(f"  chain intact: {all_ok}")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
