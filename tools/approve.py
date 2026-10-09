#!/usr/bin/env python3
"""Approve the exact deployed SAO JAR in ZombieBuddy's current store."""

import argparse
import hashlib
import json
import os
import pathlib
import sys
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--store", type=pathlib.Path)
    parser.add_argument("--jar", type=pathlib.Path)
    args = parser.parse_args()
    if (args.store is None) != (args.jar is None):
        parser.error("--store and --jar must be supplied together")

    store = args.store or pathlib.Path.home() / ".zombie_buddy/mod_approvals.json"
    jar = args.jar or pathlib.Path.home() / "Zomboid/mods/SurvivorAwareness/42.20/media/java/SAO.jar"
    if not store.is_file() or not jar.is_file():
        print("[approve] REFUSED: approval store or deployed JAR is missing", file=sys.stderr)
        return 1

    data = json.loads(store.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not isinstance(data.get("mods"), list):
        print("[approve] REFUSED: approval store has no mods list", file=sys.stderr)
        return 1
    digest = hashlib.sha256(jar.read_bytes()).hexdigest()
    mods = data["mods"]
    if any(isinstance(entry, dict) and entry.get("id") == "SurvivorAwareness"
           and entry.get("jar_hash") == digest and entry.get("decision") is True
           for entry in mods):
        print("[approve] current hash already approved:", digest[:12])
        return 0

    mods.append({"id": "SurvivorAwareness", "jar_hash": digest, "decision": True})
    temporary = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=store.parent,
                                         prefix=".mod_approvals.", suffix=".tmp",
                                         delete=False) as handle:
            temporary = pathlib.Path(handle.name)
            json.dump(data, handle, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, store)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print("[approve] approved deployed jar:", digest[:12])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
