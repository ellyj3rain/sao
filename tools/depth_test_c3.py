#!/usr/bin/env python3
"""Depth test, re-run for [A18] C3: occupation-shaped claims. The gate is
the operator's: two seasoned survivors in the same town must be able to
disagree about a lesson because provenance differs; if everyone recasts
the same lived claims, the grammar is a stamp. Ports the Lua math
EXACTLY: census draw -> classOf -> affinity multiplicity -> tilted
provenance bar. Also checks the new failure mode this batch could
introduce: occupational MONOCULTURE (all deputies identical)."""

def hash_of(sid, salt):
    text = f"{sid}:{salt}"
    v = 2166136261
    for ch in text:
        v = (v * 16777619 + ord(ch)) % 4294967296
    return v

def trait(sid, name):
    return 0.15 + (hash_of(sid, name) % 10000) / 10000.0 * 0.70

# --- census (exact port of assign + classOf) ---
BASE = [
    ("homemaker", 1000), ("retiree", 1400), ("student", 500),
    ("unemployed", 470), ("clerk", 900), ("salesperson", 550),
    ("teacher", 200), ("trucker", 340), ("waitress", 300), ("minister", 50),
    ("postal", 60), ("bartender", 60), ("factoryhand", 800),
    ("farmhand", 300), ("nursesaide", 220), ("burgerflipper", 300),
    ("chef", 110), ("carpenter", 170), ("construction", 330),
    ("electrician", 85), ("engineer", 65), ("farmer", 260), ("rancher", 65),
    ("fisherman", 20), ("fitness", 12), ("lumberjack", 40),
    ("mechanic", 210), ("metalworker", 150), ("nurse", 125),
    ("parkranger", 4), ("police", 28), ("fireofficer", 12),
    ("repairman", 130), ("security", 65), ("smither", 4), ("tailor", 25),
    ("veteran", 210), ("doctor", 20), ("burglar", 30), ("soldier", 380),
    ("SoldierOccupation:armyranger", 7), ("SoldierOccupation:deltaforce", 7),
    ("SoldierOccupation:navyseal", 7),
]
TOTAL = sum(w for _, w in BASE)

def assign(sid):
    roll = hash_of(sid, "census") % TOTAL
    cum = 0
    for key, w in BASE:
        cum += w
        if roll < cum:
            return key
    return BASE[-1][0]

CLASS_BY_KEY = {
    "police": "hardened", "security": "hardened", "veteran": "hardened",
    "soldier": "hardened", "burglar": "hardened",
    "nurse": "carer", "doctor": "carer", "nursesaide": "carer",
    "fireofficer": "carer", "minister": "carer",
    "farmer": "outdoors", "rancher": "outdoors", "fisherman": "outdoors",
    "lumberjack": "outdoors", "farmhand": "outdoors", "parkranger": "outdoors",
    "clerk": "settled", "homemaker": "settled", "retiree": "settled",
    "student": "settled", "salesperson": "settled", "teacher": "settled",
    "waitress": "settled", "bartender": "settled", "postal": "settled",
    "unemployed": "settled",
}
def class_of(key):
    if key in CLASS_BY_KEY:
        return CLASS_BY_KEY[key]
    if key.startswith("SoldierOccupation:"):
        return "hardened"   # specops bucket
    return "trades"

AFFINITY = {
    "hardened": {"measure-the-danger": 3, "doors-decide-lives": 2,
                 "routine-is-armor": 2},
    "carer": {"people-are-worth-it": 3, "running-has-a-price": 2},
    "outdoors": {"noise-is-a-debt": 2, "routine-is-armor": 2,
                 "claimed-places-bite": 2},
    "settled": {"claimed-places-bite": 2, "people-are-worth-it": 2},
    "trades": {"routine-is-armor": 2, "doors-decide-lives": 2},
}
TILT = {"hardened": 15, "carer": 10, "outdoors": 5, "settled": -15, "trades": 0}

GRAMMAR = [
    ("measure-the-danger",  lambda t: t["nerve"] < 0.45),
    ("doors-decide-lives",  lambda t: t["aggression"] > 0.55),
    ("people-are-worth-it", lambda t: t["compassion"] > 0.55),
    ("claimed-places-bite", lambda t: True),
    ("routine-is-armor",    lambda t: t["discipline"] > 0.5),
    ("noise-is-a-debt",     lambda t: t["initiative"] > 0.5),
    ("running-has-a-price", lambda t: t["selfPreservation"] > 0.55),
]

def generate(sid, world_months):
    occ = assign(sid)
    occ_class = class_of(occ)
    affinity = AFFINITY[occ_class]
    lived_bar = 45 + TILT[occ_class]
    contact = world_months * (0.10 + (hash_of(sid, 77) % 900) / 1000.0)
    traits = {k: trait(sid, k) for k in
              ("nerve", "discipline", "aggression", "initiative",
               "selfPreservation", "compassion")}
    if contact < 0.5:
        count = hash_of(sid, 21) % 2
    elif contact < 2:
        count = 1 + hash_of(sid, 21) % 2
    else:
        count = 1 + hash_of(sid, 21) % 3
    fitting = []
    for key, fits in GRAMMAR:
        if fits(traits):
            times = affinity.get(key, 1)
            fitting.extend([key] * times)
    claims = {}
    used = set()
    for k in range(1, count + 1):
        if not fitting:
            break
        pick = fitting[hash_of(sid, 30 + k) % len(fitting)]
        if pick in used:
            continue
        used.add(pick)
        roll = hash_of(sid, 90 + k) % 100
        src = ("lived" if roll < lived_bar
               else ("witnessed" if roll < lived_bar + 25 else "told"))
        claims[pick] = src
    return occ, occ_class, contact, claims

WORLD_MONTHS = 6.0
cohort = [f"sao-{i}" for i in range(1, 41)]
results = {sid: generate(sid, WORLD_MONTHS) for sid in cohort}

sets = {}
hermits = 0
for sid, (occ, cls, contact, claims) in results.items():
    key = tuple(sorted(claims.items()))
    sets.setdefault(key, []).append(sid)
    if contact < 1.0:
        hermits += 1
counts = sorted((len(v) for v in sets.values()), reverse=True)
print(f"cohort 40 at world-month {WORLD_MONTHS} (occupation-shaped):")
print(f"  distinct (claim,provenance) sets: {len(sets)}")
print(f"  hermits (contact < 1.0 month): {hermits}")
print(f"  largest identical-set group: {counts[0]} of 40")

from itertools import combinations
disagree = pairs = 0
for a, b in combinations(cohort, 2):
    ca, cb = results[a][3], results[b][3]
    shared = set(ca) & set(cb)
    if shared:
        pairs += 1
        if any(ca[k] != cb[k] for k in shared):
            disagree += 1
print(f"  pairs sharing >=1 claim: {pairs}; disagreeing on provenance: "
      f"{disagree} ({100*disagree//max(1,pairs)}%)")

# Monoculture check: within each class, are the sets distinct?
from collections import defaultdict
by_class = defaultdict(list)
for sid, (occ, cls, contact, claims) in results.items():
    by_class[cls].append(tuple(sorted(claims.items())))
print("  within-class diversity (distinct/members):")
for cls, lst in sorted(by_class.items()):
    print(f"    {cls:9s} {len(set(lst))}/{len(lst)}")

# The texture the batch bought: does provenance now differ BY CLASS?
lived_share = {}
for cls in by_class:
    tot = lived = 0
    for sid, (occ, c2, contact, claims) in results.items():
        if c2 != cls:
            continue
        for src in claims.values():
            tot += 1
            lived += 1 if src == "lived" else 0
    lived_share[cls] = f"{lived}/{tot}"
print("  lived share by class:", lived_share)
