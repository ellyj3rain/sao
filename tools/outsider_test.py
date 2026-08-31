#!/usr/bin/env python3
r"""The outsider test ([B28]) - everyone in the county who is not ours.

[B24] and [B24] set this project's hardest lesson: **unmodelled means
uncheckable.** The pact layer was structurally dead for the life of
the project and nothing noticed, because no mirror simulated pacts.

Five batches then shipped behaviour no mirror covers at all:

    [B27] the player perceives and TELLS through the same functions
          survivors use; `chosen` skips only the speaker's reticence
    [B27] the player receives wire news when carrying a receiver
    [B28] `foreign:` keys resolve to a body, so a medic will aid
          another mod's person
    [B28] the county may exceed the size it started at
    [B28] the road runs before the refill clock, gated on the
          helicopter, one admission a month

Every other mirror hard-codes N = 60 `sao-` survivors. There is no
player, no foreign person and no growth in any of them - so the
mirrors now actively CONTRADICT the live code on population, which is
a finding in its own right.

## What this cannot price, stated up front

Anything that reads the real world. Whether the player is actually
carrying a receiver, whether a foreign person is actually within
fifteen tiles, whether anyone is actually bleeding, whether a place
yielded anything - all of that is real inventories and real bodies in
a real cell. Inventing rates for them would be authoring numbers,
which is the trap this project refuses.

## What it can price, exactly

The pure logic: the key-domain rule, `bodyForKey`'s dispatch, the gate
CHAINS in `P.tell` and the aid loop, and the arithmetic of the road.
If a chain cannot pass on social facts alone, no amount of world
simulation would save it - that is a structural finding.

So this reports **reachability, not frequency**, and names the gate
that would be responsible.
"""
import contextlib
import io
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

_quiet = io.StringIO()
with contextlib.redirect_stdout(_quiet):
    import equilibrium_test as eq

PLAYER = "player:you"
FOREIGN = "foreign:someone"

# The live defaults, read off sandbox-options.txt rather than guessed.
POPULATION_DEFAULT = 60
NEWCOMERS_DEFAULT = 180
NEWCOMERS_MAX = 500
MONTH_HOURS = 720.0
TRAFFIC_DEFAULT = 2      # [B29] SurvivorAwareness.RoadTraffic
TRAFFIC_MAX = 12


# --- the key-domain rule, ported from S.keyForObserved -------------------
def key_for_observed(label, known_names):
    """`sao-` for ours, `foreign:` for a marked label, `player:` else."""
    if label in known_names:
        return known_names[label]
    if label.startswith("~"):
        return "foreign:" + label[1:]
    return "player:" + label


def body_for_key(key, *, foreign_resolves=True):
    """Ported from bodyForKey. `foreign_resolves=False` is the
    pre-[B28] code, kept so this mirror can prove it catches the bug
    it was written for."""
    if key.startswith("sao-"):
        return "shell"
    if key.startswith("player:"):
        return "the player"
    if key.startswith("foreign:"):
        return "another mod's person" if foreign_resolves else None
    return None


# --- [B27] the player's telling ------------------------------------------
def tell_allowed(from_key, to_id, chosen):
    """P.tell's two gates. Everything past them is identical for
    anyone, which is the whole of [B27]."""
    # The LISTENER's skepticism is never waived by choosing to speak.
    if eq.trust[(to_id, from_key)] < -0.2:
        return False, "listener distrusts the teller"
    if not chosen:
        same = eq.group.get(from_key) is not None and \
            eq.group.get(from_key) == eq.group.get(to_id)
        if not same and eq.trust[(from_key, to_id)] < 0.3:
            return False, "speaker's reticence"
    return True, None


# --- [B28] the aid chain --------------------------------------------------
def may_aid(aider_index, hurt_key):
    """mayAid, minus the two terms this mirror cannot see. `medic`
    needs a designation and `urgentAider` needs a lesson the mirror's
    claim grammar does not carry, so this is a conservative FLOOR:
    the live game aids at least this often, never less."""
    if eq.CLASSES[aider_index] == "carer":
        return True
    same = eq.group.get(aider_index) is not None and \
        eq.group.get(aider_index) == eq.group.get(hurt_key)
    return same and eq.trust[(aider_index, hurt_key)] > 0.3


def can_aid(aider_index, hurt_key, *, foreign_resolves=True):
    if not may_aid(aider_index, hurt_key):
        return False, "mayAid"
    if (aider_index, hurt_key) in eq.hostile or \
            (hurt_key, aider_index) in eq.hostile:
        return False, "hostile"
    if body_for_key(hurt_key, foreign_resolves=foreign_resolves) is None:
        return False, "bodyForKey"
    return True, None


# --- [B28]/[B28] the road -------------------------------------------------
def county_after(hours, population, newcomers, traffic=TRAFFIC_DEFAULT,
                 sky_quiet_at=0.0):
    """The ceiling the county may reach, by [B28]'s cadence and
    [B29]'s magnitude: one admission a month, of `traffic` people,
    once the sky has gone quiet.

    NOTE the hours are WORLD-AGE hours, which javap confirms are
    getNightsSurvived() * 24 + timeOfDay - in-game hours. Day length
    changes how much REAL time a month costs and nothing here."""
    if newcomers <= population:
        return population
    if hours <= sky_quiet_at:
        return population
    months = int((hours - sky_quiet_at) // MONTH_HOURS)
    return min(newcomers, population + months * max(1, traffic))


# --- [B27] the wire -------------------------------------------------------
def fresh_listener(known_factions=()):
    """A listener's belief store, in the shape P.observe builds."""
    return {"people": {},
            "factions": {g: {"stance": "neutral"} for g in known_factions}}


def hear_the_wire(key, b, items, reactive):
    """Ported from hearTheWire in SAO_Radio.lua. Returns
    (heardSomething, handler_calls) so `reactive` can be checked
    without changing what crossed.

    NOTE `heard` is cumulative exactly as the live flag is - see the
    probe below for why that is kept rather than tidied."""
    heard = False
    fired = []
    for item in items:
        if item["kind"] == "death" and item["id"] != key:
            dname = item.get("name")
            if dname and dname != "Unnamed":
                # [B28] per-death, not cumulative - see the live fix.
                was_news = False
                pb = b["people"].get(dname)
                if pb is not None:
                    if not pb.get("dead"):
                        pb["dead"] = True
                        was_news = True
                else:
                    b["people"][dname] = {
                        "x": item.get("x"), "y": item.get("y"),
                        "dist": 999, "at": 0, "source": "told",
                        "dead": True,
                    }
                    was_news = True
                if was_news:
                    heard = True
                if reactive and was_news:
                    fired.append((key, dname))
        elif item["kind"] in ("feud", "peace"):
            stance = "wary" if item["kind"] == "feud" else "neutral"
            for g in (item.get("a"), item.get("b")):
                if g and g in b["factions"]:
                    b["factions"][g]["stance"] = stance
                    heard = True
    return heard, fired


def deliver(items, *, player_listens=True):
    """deliverToListeners. `player_listens=False` is the pre-[B27]
    code - the loop walked SAO.Identity.all() and the player, holding
    a receiver and listening to the same broadcast, got nothing."""
    out = {}
    surv = fresh_listener(known_factions=("g0",))
    out["sao-1"] = (surv, hear_the_wire("sao-1", surv, items, True))
    if player_listens:
        pl = fresh_listener(known_factions=("g0",))
        out[PLAYER] = (pl, hear_the_wire(PLAYER, pl, items, False))
    return out


def main():
    print("The outsider test ([B28]) - the player, another mod's person,")
    print("and a county that is not the size it started")
    print(f"county: {eq.N} survivors, plus {PLAYER} and {FOREIGN}")

    known = {}   # no survivor in this mirror shares a label with them

    # 1. The key domains.
    print("\n--- the three key domains ---")
    cases = [("~someone", "foreign:someone"), ("you", "player:you")]
    dom_ok = True
    for label, want in cases:
        got = key_for_observed(label, known)
        ok = got == want
        dom_ok = dom_ok and ok
        print(f"  {label:<12} -> {got:<22} {'ok' if ok else 'WRONG'}")
    for k in ("sao-3", PLAYER, FOREIGN):
        print(f"  bodyForKey({k:<16}) -> {body_for_key(k)}")

    # 2. [B27] the player's telling.
    print("\n--- [B27] can the player put a belief in anyone's head? ---")
    reach = {}
    for chosen in (False, True):
        n, why = 0, {}
        for s in range(eq.N):
            ok, gate = tell_allowed(PLAYER, s, chosen)
            if ok:
                n += 1
            else:
                why[gate] = why.get(gate, 0) + 1
        reach[chosen] = n
        label = "chosen (a click)" if chosen else "unchosen (as an NPC)"
        print(f"  {label:<22} reaches {n:3}/{eq.N}   {why or ''}")
    print("  the gap between those two lines IS `chosen`: a stranger")
    print("  keeps their own counsel, a player already decided.")

    # 3. [B28] foreign aid, before and after.
    print("\n--- [B28] can anyone aid another mod's person? ---")
    aid = {}
    for resolves in (False, True):
        n, why = 0, {}
        for s in range(eq.N):
            ok, gate = can_aid(s, FOREIGN, foreign_resolves=resolves)
            if ok:
                n += 1
            else:
                why[gate] = why.get(gate, 0) + 1
        aid[resolves] = n
        era = "post-[B28]" if resolves else "pre-[B28] (the bug)"
        print(f"  {era:<22} {n:3}/{eq.N} could aid   {why or ''}")
    print("  carers only - `medic` needs a designation and `urgentAider`")
    print("  a lesson this mirror's grammar has no claim for, so the")
    print("  live game aids at least this often and never less.")

    # 4. [B28]/[B28] the road.
    print("\n--- [B28]/[B28] how large does the county actually get? ---")
    year = 24 * 365.0
    for label, hours in (("after 1 year", year), ("after 2 years", 2 * year),
                         ("after 5 years", 5 * year)):
        got = county_after(hours, POPULATION_DEFAULT, NEWCOMERS_DEFAULT)
        print(f"  {label:<14} {got:4} (default ceiling "
              f"{NEWCOMERS_DEFAULT})")
    print("  --- and across [B29]'s RoadTraffic, which is the option ---")
    for tr in (1, TRAFFIC_DEFAULT, 6, TRAFFIC_MAX):
        got = county_after(2 * year, POPULATION_DEFAULT, 360, tr)
        need = (360 - POPULATION_DEFAULT) / float(tr)
        print(f"  traffic {tr:2}: {got:4} after 2 years; 360 reachable "
              f"in {need / 12.0:5.1f} years")

    # 5. [B27] the wire.
    print("\n--- [B27] does the wire reach a player the way it reaches"
          " a survivor? ---")
    items = [
        {"kind": "death", "id": "sao-9", "name": "Ana Reyes",
         "x": 100, "y": 200},
        {"kind": "feud", "a": "g0", "b": "g4"},
        {"kind": "peace", "a": "g7", "b": "g8"},
    ]
    post = deliver(items, player_listens=True)
    surv_b, (surv_heard, surv_fired) = post["sao-1"]
    play_b, (play_heard, play_fired) = post[PLAYER]
    same_state = surv_b == play_b
    print(f"  survivor heard: {surv_heard}   player heard: {play_heard}")
    print(f"  belief state identical: {same_state}")
    print(f"  handler fired for survivor: {len(surv_fired)}   "
          f"for player: {len(play_fired)}")
    print("  `reactive` is the ONLY difference: what crossed is the same")
    print("  object; a survivor learns FROM it and a player has their own")
    print("  interior already.")

    pre = deliver(items, player_listens=False)
    pre_player = PLAYER in pre
    print(f"  pre-[B27] (survivors only): player present as a listener"
          f" = {pre_player}")

    # The cumulative-flag probe. The live guard is
    # `if reactive and heardSomething`, and heardSomething carries
    # across items - so a feud heard first could, in principle, make
    # an ALREADY-KNOWN death fire the handler afterwards.
    known = fresh_listener(known_factions=("g0",))
    known["people"]["Ana Reyes"] = {"dead": True, "source": "told"}
    _, spur = hear_the_wire("sao-1", known,
                            [{"kind": "feud", "a": "g0", "b": "g4"},
                             {"kind": "death", "id": "sao-9",
                              "name": "Ana Reyes"}], True)
    print(f"  cumulative-flag probe: handler fires on an already-known"
          f" death after a feud = {len(spur) > 0}")

    print("\nVERDICT:")
    fail = []
    if not dom_ok:
        fail.append("a key domain resolves to the wrong prefix")
    if reach[True] == 0:
        fail.append("[B27] the player can reach NOBODY even by choosing")
    if reach[True] <= reach[False]:
        fail.append("[B27] `chosen` changes nothing - the gate is dead")
    if aid[True] == 0:
        fail.append("[B28] no one can aid another mod's person")
    if aid[False] != 0:
        fail.append("this mirror does NOT catch the pre-[B28] bug, so it "
                    "cannot be trusted to catch the next one")
    if county_after(5 * year, POPULATION_DEFAULT, NEWCOMERS_DEFAULT) \
            <= POPULATION_DEFAULT:
        fail.append("[B28] the county never grows")
    if county_after(2 * year, POPULATION_DEFAULT, 360, TRAFFIC_MAX) \
            <= county_after(2 * year, POPULATION_DEFAULT, 360, 1):
        fail.append("[B29] RoadTraffic changes nothing - the "
                    "option is dead")
    if not same_state:
        fail.append("[B27] the wire leaves a player and a survivor "
                    "holding DIFFERENT beliefs from the same broadcast")
    if not play_heard:
        fail.append("[B27] the player receives nothing from the wire")
    if pre_player:
        fail.append("this mirror does NOT catch the pre-[B27] bug, so it "
                    "cannot be trusted to catch the next one")
    if play_fired:
        fail.append("[B27] deathNewsHandler fired for a player - that is "
                    "a survivor's modelled interior being issued to a human")
    if fail:
        for f in fail:
            print("  FAIL:", f)
        return 1
    print(f"  the player reaches {reach[True]}/{eq.N} by choosing and "
          f"{reach[False]} without - `chosen` is load-bearing")
    print(f"  {aid[True]}/{eq.N} could aid another mod's person; the "
          "pre-[B28] code reaches 0, which this mirror catches")
    print("  the county grows, and the ceiling is reachable")
    print("  the wire leaves a player and a survivor holding the same\n  beliefs; only the survivor learns from it")
    print("  NOT priced here: real inventories, real distances, real "
          "wounds - see the header.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
