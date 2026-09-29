#!/usr/bin/env python3
"""Verify the retained Build 42.21 autonomous horse-travel receipt."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/audits/c98-owned-horse-life-and-mobility/loaded-receipt.json"


def check(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit("FAULT: " + message)


data = json.loads(RECEIPT.read_text(encoding="utf-8"))
check(data.get("schema") == "sao-horse-loaded-receipt/1", "receipt schema differs")
check(data.get("engineVersion") == "42.21.0 4a0e9546ec", "engine version differs")
check(data.get("status") == "completed" and data.get("exitCode") == 0,
      "native run did not complete")
check(data.get("runtimeErrors") == [], "runtime error scanner was not clean")
check(data.get("datasetAdmission") == "unreviewed", "scenario was admitted without review")
check(data.get("behavioralVerdict") is None, "receipt invented a behavioral verdict")
check(set(data.get("explicitCohort", ())) == {
    "SurvivorAwareness", "ZombieAwareness", "ZombieBuddy"
}, "explicit native cohort differs")
events = data.get("events", [])
check([row.get("kind") for row in events] == [
    "horse-spawned", "travel-began", "mounted", "arrived", "dismounted"
], "physical horse event chain differs")
purpose = data.get("purpose", {})
check(purpose.get("status") == "completed" and purpose.get("cursor") == 5,
      "maintained travel purpose did not finish")
check([step.get("token") for step in purpose.get("steps", [])] == [
    "horse:reached", "horse:mounted", "route:arrived", "horse:dismounted"
], "owned execution results differ")
mount = data.get("finalHorseMount", {})
check(mount.get("animalId") == 189 and mount.get("active") is False,
      "final durable mount relation differs")
check(mount.get("mountedAtHours", 0) < mount.get("dismountedAtHours", 0),
      "mount timestamps are not ordered")
check(data.get("finalPosition") == {"x": 3800.5, "y": 10943.5, "z": 0},
      "final represented position differs")
print("horse travel acceptance: Build 42.21 spawn, mount, native route, arrival and dismount retained")
