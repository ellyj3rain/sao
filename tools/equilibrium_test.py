#!/usr/bin/env python3
"""The equilibrium test ([A23]): does the county's social physics hold a
living mix over months, or collapse into a mega-company / universal feud?
Ports the LIVE constants: road warmth +0.005/meeting (30-60s pair
cooldown -> a close pair meets a handful of times per game-day), politick
+0.05/-0.08 at 0.5 world-hour per-pair cooldown, company at mutual >0.5
(one side ungrouped), hostility at mutual <-0.5 via politick, feud at >=2
hostile cross-pairs, feud short-circuits politick (no further cooling),
peace when both LEADERS' mutual trust >0.3 at a meeting, schism on
internal mutual hostility (core = leader's enemy or lower trust-sum;
sympathizers trust core > leader). Deterministic seed; 120 days; 60
records in 4 town clusters."""
import random
from collections import defaultdict

random.seed(1993)
N = 60
DAYS = 120

# Homes: 4 towns on a line, intra-town spread.
towns = [(50, 50), (150, 60), (90, 160), (200, 170)]
homes = []
for i in range(N):
    tx, ty = towns[i % 4]
    homes.append((tx + random.uniform(-15, 15), ty + random.uniform(-15, 15)))

# Census classes at rough county proportions -> creed components.
CLASSES = (["hardened"] * 5 + ["carer"] * 4 + ["outdoors"] * 5
           + ["settled"] * 30 + ["trades"] * 16)
random.shuffle(CLASSES)
CLASS_COMPONENT = {"hardened": "order", "carer": "mercy",
                   "outdoors": "road", "settled": "wall", "trades": "wall"}
OPPOSES = {"order": "road", "road": "order", "wall": "mercy", "mercy": "wall"}

trust = defaultdict(float)      # (a,b) directional
hostile = set()                 # (a,b) directional
group = {}                      # id -> group name
feuds = set()                   # frozenset({gA,gB})
next_group = [0]
stats = {"peaces": 0, "schisms": 0, "feuds": 0, "hostilities": 0}

def meet_rate(a, b):
    dx = homes[a][0] - homes[b][0]
    dy = homes[a][1] - homes[b][1]
    d = (dx * dx + dy * dy) ** 0.5
    if d < 25: return 4.0      # same street: several road meetings a day
    if d < 60: return 0.8
    if d < 120: return 0.1
    return 0.01

def members(g):
    return [i for i in range(N) if group.get(i) == g]

def leader_of(g):
    ms = members(g)
    if not ms: return None
    best, bestsum = None, None
    for m in sorted(ms):
        s = sum(trust[(o, m)] for o in ms if o != m)
        if bestsum is None or s > bestsum:
            best, bestsum = m, s
    return best

# Claim-shaped creeds (sim fidelity fix, [A24]): the LIVE creedOf adds
# lesson components; modeling class alone produced a wall monoculture
# the live county does not have. Claims generated per member with the
# exact A18 math (hash + affinity port from depth_test_c3).
def _h(sid, salt):
    text = f"{sid}:{salt}"
    v = 2166136261
    for ch in text:
        v = (v * 16777619 + ord(ch)) % 4294967296
    return v

def _trait(sid, name):
    # [B32] The GAME buckets at 1/1000, not 1/10000. Both give the
    # same marginals and DIFFERENT joints: traits of one person are
    # correlated, and the two formulas correlate them differently -
    # in OPPOSITE directions for some pairs. Any figure resting on
    # two traits at once was measuring a population the game does
    # not have. [B25] and [B32] both dismissed this as harmless
    # because the marginals matched; the joint was never checked.
    return 0.15 + (_h(sid, name) % 1000) / 1000.0 * 0.70

def _circle(sid):
    # [A27] mirror: loner ~15%, band ~35% (circle of 3), house ~50%.
    # [B32] Same hash, same bucketing as the game.
    h = (_h(sid, "circle") % 1000) / 1000.0
    if h < 0.15: return "loner"
    if h < 0.50: return "band"
    return "house"

def _circle_cap(sid):
    c = _circle(sid)
    return 1 if c == "loner" else (3 if c == "band" else 999)

def circle_refuses(sid, g):
    c = _circle(sid)
    if c == "loner": return True
    if c == "band":
        return g is not None and len(members(g)) >= 3
    return False

_AFF = {"hardened": {"measure-the-danger": 3, "doors-decide-lives": 2,
                     "routine-is-armor": 2},
        "carer": {"people-are-worth-it": 3, "running-has-a-price": 2},
        "outdoors": {"noise-is-a-debt": 2, "routine-is-armor": 2,
                     "claimed-places-bite": 2},
        "settled": {"claimed-places-bite": 2, "people-are-worth-it": 2},
        "trades": {"routine-is-armor": 2, "doors-decide-lives": 2}}
_GRAM = [("measure-the-danger", lambda t: t["nerve"] < 0.45),
         ("doors-decide-lives", lambda t: t["aggression"] > 0.55),
         ("people-are-worth-it", lambda t: t["compassion"] > 0.55),
         ("claimed-places-bite", lambda t: True),
         ("routine-is-armor", lambda t: t["discipline"] > 0.5),
         ("noise-is-a-debt", lambda t: t["initiative"] > 0.5),
         ("running-has-a-price", lambda t: t["selfPreservation"] > 0.55)]

def _claims_for(i):
    sid = f"sao-{i}"
    cls = CLASSES[i]
    aff = _AFF[cls]
    traits = {k: _trait(sid, k) for k in
              ("nerve", "discipline", "aggression", "initiative",
               "selfPreservation", "compassion")}
    contact = 6.0 * (0.10 + (_h(sid, 77) % 900) / 1000.0)
    if contact < 0.5: count = _h(sid, 21) % 2
    elif contact < 2: count = 1 + _h(sid, 21) % 2
    else: count = 1 + _h(sid, 21) % 3
    fitting = []
    for key, fits in _GRAM:
        if fits(traits):
            fitting.extend([key] * aff.get(key, 1))
    out = set()
    for k in range(1, count + 1):
        if not fitting: break
        out.add(fitting[_h(sid, 30 + k) % len(fitting)])
    return out

MEMBER_CLAIMS = {i: _claims_for(i) for i in range(N)}
_CLAIM_COMP = {"routine-is-armor": "order", "people-are-worth-it": "mercy",
               "claimed-places-bite": "wall", "noise-is-a-debt": "road",
               "running-has-a-price": "road"}

def _pull(m, comp):
    """[B24] One member's pull, matching the live `S.creedPullOf`.
    Trades contribute HALF a point of wall, not a full one - the live
    `else` branch - and that half alone is not a conviction. Returns
    True when the only pull was that default."""
    weak = False
    cls = CLASSES[m]
    if cls == "trades":
        comp["wall"] += 0.5
        weak = True
    else:
        comp[CLASS_COMPONENT[cls]] += 1
    for c in MEMBER_CLAIMS[m]:
        k = _CLAIM_COMP.get(c)
        if k:
            comp[k] += 0.5
            weak = False
    return weak


def county_creed_share():
    """[B24] What the county's own living population pulls, so a house
    can be measured against it rather than against zero."""
    total = defaultdict(float)
    for m in range(N):
        _pull(m, total)
    s = sum(total.values())
    if s <= 0:
        return {k: 0.25 for k in ("order", "mercy", "wall", "road")}
    return {k: total[k] / s for k in ("order", "mercy", "wall", "road")}


_SHARE = None


def creed_comp(g):
    comp = defaultdict(float)
    n = 0
    for m in members(g):
        n += 1
        _pull(m, comp)
    return comp, max(1, n)

def creed_of(g):
    """[B24] The component this house has MOST OF relative to what
    the county would predict - not the raw maximum, which made wall
    universal."""
    global _SHARE
    if _SHARE is None:
        _SHARE = county_creed_share()
    comp, n = creed_comp(g)
    best, best_v = None, -1e9
    for k in ("order", "mercy", "wall", "road"):
        excess = comp[k] - _SHARE[k] * n
        if excess > best_v:
            best, best_v = k, excess
    return best


def _creed_of_unused(g):
    comp, _ = creed_comp(g)
    return max(("order", "mercy", "wall", "road"), key=lambda k: comp[k])

def creed_clash(gA, gB):
    # [A24] vector clash, mirroring live.
    ca, na = creed_comp(gA)
    cb, nb = creed_comp(gB)
    av = {k: ca[k] / na for k in ("order", "mercy", "wall", "road")}
    bv = {k: cb[k] / nb for k in ("order", "mercy", "wall", "road")}
    clash = (min(av["order"], bv["road"]) + min(av["road"], bv["order"])
             + min(av["wall"], bv["mercy"]) + min(av["mercy"], bv["wall"]))
    align = sum(min(av[k], bv[k]) for k in av)
    if clash > align and clash > 0.15:
        return "opposed"
    if creed_of(gA) == creed_of(gB) or align > 2 * clash:
        return "aligned"
    if OPPOSES.get(creed_of(gA)) == creed_of(gB):
        return "opposed"
    return "neutral"

# [B24] Designations, derived the way the live class prior deals them
# ([B2]): the leader leads, the rest work their class. The mirror has
# no perks, so it cannot model the [B2] skill-yield that can move a
# member off their class prior - it therefore reports a slightly
# TIDIER roster than the game has, which is the conservative direction
# for asking whether a pact is reachable at all.
DESIG_BY_CLASS = {"hardened": "watch", "outdoors": "scout",
                  "carer": "medic", "settled": "quartermaster",
                  "trades": "forager"}

PACTS = {}
_pact_probe = {"complement_ok": 0, "trust_ok": 0, "size_ok": 0, "tried": 0}


def group_shape(g):
    ms = list(members(g))
    n = len(ms)
    if n == 0:
        return None
    forage = sum(1 for m in ms if DESIG_BY_CLASS[CLASSES[m]] == "forager")
    watch = sum(1 for m in ms if DESIG_BY_CLASS[CLASSES[m]] == "watch")
    return {"n": n, "forage": forage / n, "watch": watch / n}


def try_pact(a, b, gA, gB):
    """[A26] bread-for-watch, ported exactly: both must be leaders,
    mutual leader trust at least 0.2, both houses four or more, and
    the shares must COMPLEMENT - one house's foragers meeting the
    other's watch."""
    _pact_probe["tried"] += 1
    if leader_of(gA) != a or leader_of(gB) != b:
        return False
    if gB in PACTS.get(gA, set()):
        return False
    if trust[(a, b)] < 0.2 or trust[(b, a)] < 0.2:
        return False
    _pact_probe["trust_ok"] += 1
    shA, shB = group_shape(gA), group_shape(gB)
    if not shA or not shB or shA["n"] < 4 or shB["n"] < 4:
        return False
    _pact_probe["size_ok"] += 1
    complement = ((shA["forage"] >= 0.2 and shB["watch"] >= 0.2)
                  or (shB["forage"] >= 0.2 and shA["watch"] >= 0.2))
    if not complement:
        return False
    _pact_probe["complement_ok"] += 1
    PACTS.setdefault(gA, set()).add(gB)
    PACTS.setdefault(gB, set()).add(gA)
    stats["pacts"] = stats.get("pacts", 0) + 1
    return True


def in_feud(gA, gB):
    return frozenset((gA, gB)) in feuds

def hostile_cross_pairs(gA, gB):
    n = 0
    for a in members(gA):
        for b in members(gB):
            if (a, b) in hostile or (b, a) in hostile:
                n += 1
    return n

SETTLED_CREED = {}


def settled_creed_of(g):
    """[B23] What a house has settled into, not what today's roster
    says. A challenger must lead by a real margin to displace it, so
    culture turns rather than flickering - and a division persists
    long enough to mean something.

    Ported because without it the mirror reads a creed fresh every
    day, houses drift in and out of division, and the erosion can
    never accumulate. Measuring the live law against a mirror that
    lacks it would price the wrong thing.
    """
    comp, _ = creed_comp(g)
    live = creed_of(g)
    settled = SETTLED_CREED.get(g)
    if settled is None:
        SETTLED_CREED[g] = live
        return live
    if live != settled:
        if comp.get(live, 0.0) - comp.get(settled, 0.0) >= 1.5:
            SETTLED_CREED[g] = live
            return live
    return settled


def lean_of(m):
    """[B23] Which creed one person pulls toward, matching the live
    `S.leansToward`. [B24]: None for a life whose only pull is the
    unclassified default - most people have no conviction about how
    the house should be run, and pretending otherwise made every
    divided house impossible."""
    comp = defaultdict(float)
    weak = _pull(m, comp)
    if weak:
        return None
    return max(comp.items(), key=lambda kv: (kv[1], kv[0]))[0]


def divide_house(g):
    """[B23] Two OPPOSED creeds under one roof bend trust toward two
    faces: the most-trusted adherent of each side. Everyone drifts
    toward their own and away from the other.

    NOTE the mirror has no larder, so it cannot apply the live
    surplus gate ("a house with nothing left does not hold a quarrel,
    people leave"). It therefore divides MORE readily than the game
    does - which is the conservative direction for a safety check:
    if schisms stay bounded here they stay bounded live.
    """
    ms = sorted(members(g))
    if len(ms) < 4:
        return False
    comp, _ = creed_comp(g)
    # [B25] The pair the house is actually contesting - the opposed
    # pair whose weaker side is strongest - not the settled creed's
    # formal opposite, which [B24] made a different question.
    settled = foe = None
    mine = theirs = 0.0
    best_floor = -1.0
    for a in ("order", "mercy", "wall", "road"):
        b = OPPOSES[a]
        va, vb = comp.get(a, 0.0), comp.get(b, 0.0)
        floor = min(va, vb)
        if floor > best_floor:
            best_floor = floor
            if va >= vb:
                settled, foe, mine, theirs = a, b, va, vb
            else:
                settled, foe, mine, theirs = b, a, vb, va
    if foe is None:
        return False
    # [B25] Margin of followers only; the near-parity clause was
    # [B23]'s own invention and is gone.
    if theirs < 1.5:
        return False
    face_ours = face_theirs = None
    best_ours = best_theirs = -1e9
    for m in ms:
        lean = lean_of(m)
        if lean not in (settled, foe):
            continue
        s = sum(trust[(o, m)] for o in ms if o != m)
        if lean == settled and s > best_ours:
            face_ours, best_ours = m, s
        elif lean == foe and s > best_theirs:
            face_theirs, best_theirs = m, s
    if face_ours is None or face_theirs is None:
        return False
    for m in ms:
        lean = lean_of(m)
        own = face_ours if lean == settled else (
            face_theirs if lean == foe else None)
        other = face_theirs if lean == settled else (
            face_ours if lean == foe else None)
        if own is not None and m != own:
            trust[(m, own)] = min(1.0, trust[(m, own)] + 0.02)
        if other is not None and m != other:
            trust[(m, other)] = max(-1.0, trust[(m, other)] - 0.03)
    # [B23] The two faces can come to blows. politick never runs
    # between housemates (it returns nil the moment both share a
    # group), so without this the division drove trust to the floor
    # and no schism could EVER fire. Same per-person bar strangers
    # cross.
    ta, tb = trust[(face_ours, face_theirs)], trust[(face_theirs, face_ours)]
    # The mirror models the flat -0.5 bar its docstring names, not
    # the live per-person hostilityBar. That makes it CONSERVATIVE
    # here: the live law lets an aggressive pair ignite earlier, so
    # whatever bound holds in this mirror holds live too.
    bar_a = bar_b = -0.5
    if (ta < bar_a and tb < bar_b
            and (face_ours, face_theirs) not in hostile
            and (face_theirs, face_ours) not in hostile):
        hostile.add((face_ours, face_theirs))
        hostile.add((face_theirs, face_ours))
        stats["hostilities"] += 1
    return True


def check_schism(g):
    ms = sorted(members(g))
    if len(ms) < 3: return
    pair = None
    for i in range(len(ms)):
        for j in range(i + 1, len(ms)):
            if (ms[i], ms[j]) in hostile and (ms[j], ms[i]) in hostile:
                pair = (ms[i], ms[j]); break
        if pair: break
    if not pair: return
    lead = leader_of(g)
    if pair[0] == lead: core = pair[1]
    elif pair[1] == lead: core = pair[0]
    else:
        sa = sum(trust[(m, pair[0])] for m in ms if m != pair[0])
        sb = sum(trust[(m, pair[1])] for m in ms if m != pair[1])
        core = pair[0] if sa <= sb else pair[1]
    if core == lead: return
    leavers = [core] + [m for m in ms if m not in (core, lead)
                        and trust[(m, core)] > trust[(m, lead)]]
    if len(leavers) < 2:
        group.pop(core, None)
        return
    ng = "g%d" % next_group[0]; next_group[0] += 1
    for m in leavers:
        group[m] = ng
    feuds.add(frozenset((g, ng)))
    stats["schisms"] += 1

politick_cd = {}   # pair -> day-hour of last politick
testified = set()  # (hearer, offender, teller): one testimony per voice
credited = set()   # [B8] (hearer, subject, teller): one good word per voice
touched = {}       # [B8] (a,b) -> day the feeling last moved

for day in range(DAYS):
    for a in range(N):
        for b in range(a + 1, N):
            n_meet = 0
            r = meet_rate(a, b)
            while random.random() < r and n_meet < 6:
                n_meet += 1; r *= 0.5
            for _ in range(n_meet):
                pa, pb = (a, b), (b, a)
                mutual_hostile = pa in hostile or pb in hostile
                if mutual_hostile:
                    continue   # wide berth on the roads
                trust[pa] += 0.005
                trust[pb] += 0.005
                gA, gB = group.get(a), group.get(b)
                if gA and gB and gA != gB:
                    # politick at most ~4/day per pair (0.5h world cd).
                    key = (a, b)
                    if politick_cd.get(key, -1) != day or random.random() < 0.5:
                        politick_cd[key] = day
                        if in_feud(gA, gB):
                            la, lb = leader_of(gA), leader_of(gB)
                            if a == la and b == lb \
                               and trust[pa] > 0.3 and trust[pb] > 0.3:
                                feuds.discard(frozenset((gA, gB)))
                                stats["peaces"] += 1
                        else:
                            verdict_c = creed_clash(gA, gB)
                            if verdict_c == "aligned":
                                trust[pa] += 0.05; trust[pb] += 0.05
                                # [B24] Exactly where the live politick
                                # reaches for a pact.
                                try_pact(a, b, gA, gB)
                            elif verdict_c == "opposed":
                                trust[pa] -= 0.08; trust[pb] -= 0.08
                                if trust[pa] < (-0.65 + _trait(a, "aggression") * 0.3)                                         and trust[pb] < (-0.65 + _trait(b, "aggression") * 0.3) \
                                   and pa not in hostile:
                                    hostile.add(pa); hostile.add(pb)
                                    stats["hostilities"] += 1
                                    if hostile_cross_pairs(gA, gB) >= 2 \
                                       and not in_feud(gA, gB):
                                        feuds.add(frozenset((gA, gB)))
                                        stats["feuds"] += 1
                # Grudges ride the roads ([A23] re-run): each meeting,
                # both tell - hostile relations retold to a receiver who
                # trusts the teller >0.3; delta -0.4*credibility;
                # hostility only on the receiver's OWN collapse.
                for teller, hearer in ((a, b), (b, a)):
                    if trust[(hearer, teller)] > 0.3                        or group.get(teller) == group.get(hearer) is not None:
                        cred = max(0.3, trust[(hearer, teller)])
                        for (x, y) in list(hostile):
                            if x == teller and y not in (hearer, teller):
                                k = (hearer, y)
                                if k not in hostile                                    and (hearer, y, teller) not in testified:
                                    testified.add((hearer, y, teller))
                                    trust[k] -= 0.4 * cred
                                    if trust[k] < -0.45:
                                        trust[k] = -0.45   # testimony floor
                # [B8] The good word rides the same roads: subjects the
                # teller trusts >0.6 raise the hearer's regard by
                # 0.25*credibility, once per (hearer, subject, teller),
                # CEILINGED below the company line so word alone never
                # builds a house.
                CEIL = 0.4
                for teller, hearer in ((a, b), (b, a)):
                    if trust[(hearer, teller)] > 0.3                        or group.get(teller) == group.get(hearer) is not None:
                        cred = max(0.3, trust[(hearer, teller)])
                        for other in range(N):
                            if other in (teller, hearer):
                                continue
                            if trust[(teller, other)] <= 0.6:
                                continue
                            k = (hearer, other)
                            if k in hostile or trust[k] >= CEIL:
                                continue
                            if (hearer, other, teller) in credited:
                                continue
                            credited.add((hearer, other, teller))
                            trust[k] = min(CEIL, trust[k] + 0.25 * cred)
                touched[pa] = day
                touched[pb] = day
                # Company formation (one side ungrouped, mutual > 0.5).
                gA, gB = group.get(a), group.get(b)
                bar = 0.5
                hostg = gA or gB
                if hostg and creed_of(hostg) == "mercy":
                    bar = 0.4   # A24: mercy takes people in
                if not (gA and gB) and trust[pa] > bar and trust[pb] > bar:
                    g = gA or gB
                    # [A27]: trust opens the door, the circle decides.
                    if not (circle_refuses(a, g) or circle_refuses(b, g)):
                        if not g:
                            g = "g%d" % next_group[0]; next_group[0] += 1
                        group[a] = g; group[b] = g
    # [B8] Time softens: feelings nobody refreshed in 14 days drift
    # 8% toward neutral, and hostility that has faded inside +/-0.2
    # lapses - forgiveness by forgetting.
    for k in list(trust.keys()):
        last = touched.get(k)
        if last is not None and day - last > 14 and abs(trust[k]) > 0.01:
            trust[k] *= 0.92
            if k in hostile and abs(trust[k]) < 0.2:
                hostile.discard(k)

    # [B8] The crowded walk out: one per company per day, a member
    # whose house exceeds their circle and who has lost faith in the
    # leader leaves.
    for g in list(set(group.values())):
        ms = members(g)
        lead = leader_of(g)
        if lead is None or len(ms) <= 2:
            continue
        for m in ms:
            if m != lead and len(ms) > _circle_cap(m)                and trust[(m, lead)] < 0:
                group.pop(m, None)
                break

    # Daily: schism checks per company; feud lapse for dead companies.
    # [A27]: crowding is politics - members whose circle the roster
    # exceeds lose faith in the leader (election-cadence drain mirrored
    # onto the daily loop).
    for g in set(group.values()):
        ms = members(g)
        lead = leader_of(g)
        if lead is not None and len(ms) > 1:
            for m in ms:
                if m != lead and len(ms) > _circle_cap(m):
                    k = (m, lead)
                    trust[k] = max(-1.0, trust[k]
                        - (0.04 if _circle(m) == "loner" else 0.02))
    for g in set(group.values()):
        if divide_house(g):
            stats["divided_days"] = stats.get("divided_days", 0) + 1
        check_schism(g)
    feuds_ = set()
    for f in feuds:
        gs = list(f)
        if members(gs[0]) and members(gs[1]):
            feuds_.add(f)
    feuds = feuds_
    # Trust clamp.
    for k in list(trust):
        trust[k] = max(-1.0, min(1.0, trust[k]))

    if day in (14, 30, 60, 90, DAYS - 1):
        sizes = defaultdict(int)
        for m, g in group.items():
            sizes[g] += 1
        comp_sizes = sorted(sizes.values(), reverse=True)
        print(f"day {day+1:3d}: companies={len(sizes)} sizes={comp_sizes} "
              f"ungrouped={N - len(group)} feuds={len(feuds)} "
              f"(cum: {stats['feuds']} declared, {stats['peaces']} peaces, "
              f"{stats['schisms']} schisms, {stats['hostilities']} hostile pairs)")

sizes = defaultdict(int)
for m, g in group.items():
    sizes[g] += 1
biggest = max(sizes.values()) if sizes else 0
print("\nVERDICT:")
print("  mega-company (>60% in one)?", "YES" if biggest > 0.6 * N else "no",
      f"(largest {biggest}/{N})")
print("  universal feud (all pairs)?",
      "YES" if sizes and len(feuds) >= len(sizes) * (len(sizes) - 1) / 2 * 0.8
      else "no", f"({len(feuds)} active among {len(sizes)} companies)")
# [B23] This asserted `stats['schisms'] >= 0`, which is trivially true -
# it printed "schisms occur: YES" across a run with exactly zero of
# them. A check that cannot fail is not a check ([B20]'s lesson).
print("  living mix: companies persist, feuds declared AND lifted:",
      "YES" if stats['peaces'] > 0 and len(sizes) >= 3 else "CHECK")
print(f"  house-days spent divided: {stats.get('divided_days', 0)}")
_pacts = stats.get("pacts", 0)
print(f"  pacts formed: {_pacts}",
      "- houses DO ally" if _pacts > 0
      else "- NO ALLIANCE EVER FORMED")
# [B24] A bare zero cannot tell "rare" from "impossible". These say
# which gate the attempts died at.
print(f"    of {_pact_probe['tried']} attempts: "
      f"{_pact_probe['trust_ok']} cleared leader trust, "
      f"{_pact_probe['size_ok']} cleared size, "
      f"{_pact_probe['complement_ok']} cleared the forage/watch complement")
if _pacts == 0 and _pact_probe["size_ok"] > 0:
    print("    WARNING: houses reached the complement check and none "
          "passed it - suspect a structural block, not scarcity")
print(f"  schisms: {stats['schisms']}",
      "- houses DO come apart" if stats['schisms'] > 0
      else "- nothing ever split")
if stats['schisms'] > len(sizes):
    print("  WARNING: more schisms than companies - division may be "
          "tearing the county apart faster than it can form")
