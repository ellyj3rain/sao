#!/usr/bin/env python3
"""Upsert a ZombieBuddy approval for the DEPLOYED SAO.jar (F-023): the
approval store matches by jar hash, so every new build needs its entry or
ZB blocks the load at boot and the whole mod tree is excluded. Run by
deploy.sh after every copy; safe to run repeatedly."""
import json
import hashlib
import pathlib

store = pathlib.Path.home() / ".zombie_buddy/mod_approvals.json"
jar = pathlib.Path.home() / "Zomboid/mods/SurvivorAwareness/42.20/media/java/SAO.jar"
if not store.exists() or not jar.exists():
    print("[approve] store or jar missing; nothing done")
    raise SystemExit(0)
data = json.loads(store.read_text(encoding="utf-8"))
h = hashlib.sha256(jar.read_bytes()).hexdigest()
mods = data.setdefault("mods", [])
if any(m.get("id") == "SurvivorAwareness" and m.get("jar_hash") == h for m in mods):
    print("[approve] current hash already approved:", h[:12])
else:
    mods.append({"id": "SurvivorAwareness", "jar_hash": h, "decision": True})
    store.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print("[approve] approved deployed jar:", h[:12])
