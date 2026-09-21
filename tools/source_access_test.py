#!/usr/bin/env python3
r"""Border 177 - remembered world sources remain physically accessible.

Selection is not permission to mutate later. Cached items must still occupy
their loaded square/container, the actor must be on the same floor and within
unobstructed interaction reach, and vehicle parts must still be loaded and
accessible. The vanilla transfer action keeps its native validation while an
SAO subclass re-asks this authority throughout the timed action.
"""
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
NEEDS = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAONeeds.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
NEEDS_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Needs.lua"


def java_method(src, name):
    match = re.search(r"^\s{4}(?:public|private|protected)\s+.*?\b"
                      + re.escape(name) + r"\s*\([^)]*\)\s*\{", src, re.M)
    if not match:
        return ""
    start = match.end() - 1
    depth = 0
    for at in range(start, len(src)):
        if src[at] == "{":
            depth += 1
        elif src[at] == "}":
            depth -= 1
            if depth == 0:
                return src[start:at]
    return ""


def source_faults(needs, bridge, lua):
    faults = []
    offered = java_method(needs, "offeredWorldItem")
    square = java_method(needs, "squareWithinReach")
    container = java_method(needs, "containerAccessibleNow")
    port = java_method(bridge, "containerAccessibleNow")

    for seam, message in (
        ("square.getWorldObjects().contains(worldItem)",
         "a remembered offer need not remain on its loaded square"),
        ("squareWithinReach(shell, square)",
         "a remembered offer skips current physical access"),
    ):
        if seam not in offered:
            faults.append(message)
    for seam, message in (
        ("square.getCell() != shell.getCell()", "access can cross loaded cells"),
        ("square.getZ() != (int) shell.getZ()", "access can cross floors"),
        ("(dx * dx + dy * dy) <= 4.0f", "access has no arm's-reach bound"),
        ("!here.isSomethingTo(square)", "access can pass through obstruction"),
    ):
        if seam not in square:
            faults.append(message)
    for seam, message in (
        ("container.isVehiclePart()", "vehicle containers have no distinct authority"),
        ("vehicle.isRemovedFromWorld()", "removed vehicles remain usable"),
        ("cell.getVehicles().contains(vehicle)", "unloaded vehicles remain usable"),
        ("vehicle.canAccessContainer(part.getIndex(), shell)",
         "vehicle permission is not rechecked at use"),
        ("squareWithinReach(shell, square)", "container use skips physical access"),
    ):
        if seam not in container:
            faults.append(message)
    if "SAONeeds.containerAccessibleNow" not in port:
        faults.append("the bridge does not expose use-time container authority")
    for seam, message in (
        ("ISInventoryTransferAction.isValid(self)",
         "the verified action drops vanilla item/container validation"),
        ("SAOJavaBridge:containerAccessibleNow",
         "the timed action never rechecks world access"),
        ("self.saoWorldContainer", "the timed action forgets its world target"),
    ):
        if seam not in lua:
            faults.append(message)
    # C66 transfers reach the same verified native constructor through their
    # action owner. Check each caller's route instead of counting call sites.
    for name, route in (
        ("worldSourceTransferAction", "worldTransfer("),
        ("worldStoreTransferAction", "worldTransfer("),
        ("queueTake", "SAO.SourceUse.beginTransfer("),
        ("queueTakeGear", "worldTransfer("),
        ("queueTakeAmmo", "worldTransfer("),
        ("depositSpareFood", "SAO.SourceUse.beginTransfer("),
        ("depositWater", "SAO.SourceUse.beginTransfer("),
        ("takeStoredWater", "SAO.SourceUse.beginTransfer("),
    ):
        found = re.search(r"^function N\." + name + r"\([^\n]*.*?(?=^function |\Z)",
                          lua, re.M | re.S)
        if not found or route not in found.group(0):
            faults.append("verified transfer route missing: " + name)
    return faults


def reachable(same_cell, same_floor, distance_sq, blocked, permitted=True):
    return (same_cell and same_floor and distance_sq <= 4.0
            and not blocked and permitted)


def main():
    paths = (NEEDS, BRIDGE, NEEDS_LUA)
    if any(not path.exists() for path in paths):
        print("FAULT: a world-source access surface is missing")
        return 1
    needs, bridge, lua = [
        path.read_text(encoding="utf-8", errors="ignore") for path in paths]
    faults = source_faults(needs, bridge, lua)

    if not reachable(True, True, 1.0, False):
        faults.append("CONTROL model refused an accessible source")
    for case in ((False, True, 1.0, False, True),
                 (True, False, 1.0, False, True),
                 (True, True, 9.0, False, True),
                 (True, True, 1.0, True, True),
                 (True, True, 1.0, False, False)):
        if reachable(*case):
            faults.append("CONTROL model admitted unloaded, cross-floor, distant, "
                          "blocked or unauthorized ground")

    mutations = (
        (needs.replace("square.getWorldObjects().contains(worldItem)", "true", 1),
         bridge, lua, "offered-item square membership"),
        (needs.replace("square.getZ() != (int) shell.getZ()", "false", 1),
         bridge, lua, "same-floor access"),
        (needs.replace("!here.isSomethingTo(square)", "true", 1),
         bridge, lua, "obstruction access"),
        (needs.replace("vehicle.canAccessContainer(part.getIndex(), shell)",
                       "true", 1), bridge, lua, "vehicle permission"),
        (needs, bridge, lua.replace(
            "SAOJavaBridge:containerAccessibleNow(", "SAOJavaBridge:missingAuthority(", 1),
         "timed-action revalidation"),
        (needs, bridge, lua.replace("return worldTransfer(body, item, srcContainer, destContainer, destContainer)",
             "return ISInventoryTransferAction:new(body, item, srcContainer, destContainer)", 1),
         "store transfer bypass"),
    )
    for n, b, l, label in mutations:
        if not source_faults(n, b, l):
            faults.append("CONTROL removed %s but the border passed" % label)

    if faults:
        for fault in faults:
            print("FAULT: " + fault)
        return 1
    print("177) cached world sources retain loaded, same-floor, unobstructed, "
          "permissioned access through action completion")
    return 0


if __name__ == "__main__":
    sys.exit(main())
