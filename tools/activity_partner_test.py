#!/usr/bin/env python3
r"""Border 176 - private, current activity participants.

A nearby body is not automatically a participant. The actor must first hold a
fresh firsthand person belief, then the use path rechecks the current bodies
against the scanner's same-floor, facing, range and occlusion law. Controls
remove provenance, use-time visibility, floor and occlusion in turn.
"""
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
PERCEPTION = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / \
    "SAO_Perception.lua"
CONTROLLER = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / \
    "SAO_Controller.lua"
SCANNER = ROOT / "java" / "src" / "com" / "sao" / "engine" / \
    "SAOPerceptionScanner.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / \
    "SAOBridge.java"


def lua_function(src, name):
    match = re.search(r"(?:local\s+)?function\s+" + re.escape(name)
                      + r"\s*\([^)]*\)", src)
    if not match:
        return ""
    # These functions contain nested blocks. Stop at the next file-level
    # declaration; source assertions below are deliberately local to it.
    tail = src[match.start():]
    next_decl = re.search(r"\n(?:local\s+)?function\s+[A-Za-z_]", tail[1:])
    return tail if not next_decl else tail[:next_decl.start() + 1]


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


def source_faults(perception, controller, scanner, bridge):
    faults = []
    fresh = lua_function(perception, "P.freshObservedPerson")
    at_hand = lua_function(controller, "activityParticipantAtHand")
    visible = java_method(scanner, "visibleFrom")
    current = java_method(scanner, "canSeePersonNow")
    port = java_method(bridge, "canSeePersonNow")
    activity_at = controller.find("-- [C119] The counter")
    activity_end = controller.find('if agent.state == "SEARCHWARD"', activity_at)
    activity = controller[activity_at:activity_end] \
        if activity_at >= 0 and activity_end >= 0 else ""

    for seam, message in (
        ('belief.source ~= "observed"', "participant candidates need firsthand provenance"),
        ("belief.dead", "dead person beliefs can become participants"),
        ("SCAN_INTERVAL * 2", "participant beliefs have no fresh bound"),
    ):
        if seam not in fresh:
            faults.append(message)
    for seam, message in (
        ("SAO.Identity.beliefKey(rec)", "active children bypass their belief identity"),
        ("otherBody:getUsername()", "the player cannot resolve to the scanner key"),
        ("freshObservedPerson(id, key, tick)", "the activity ignores private acquisition"),
        ("SAOJavaBridge:canSeePersonNow", "the activity skips use-time visibility"),
        ("actionRange", "activity-specific physical reach is not preserved"),
    ):
        if seam not in at_hand:
            faults.append(message)
    if activity.count("activityParticipantAtHand(") < 4:
        faults.append("cashier and playmate paths do not share the guarded reader")
    if "pdx * pdx + pdy * pdy" in activity \
            or "cdx * cdx + cdy * cdy" in activity:
        faults.append("raw nearby coordinates still authorize an activity partner")

    for seam, message in (
        ("Math.abs(other.getZ() - sz) >= 0.5f", "current visibility ignores floors"),
        ("dist > maxRange", "current visibility ignores action range"),
        ("alignment < CONE_COS", "current visibility ignores the observer's facing"),
        ("!eye.isSomethingTo(target)", "current visibility ignores occlusion"),
    ):
        if seam not in visible:
            faults.append(message)
    if "visibleFrom(" not in current or "other instanceof IsoAnimal" not in current:
        faults.append("current participant visibility bypasses scanner classification")
    if "SAOPerceptionScanner.canSeePersonNow" not in port:
        faults.append("the bridge does not expose the scanner's use-time verdict")
    return faults


def candidate(source, dead, age, fresh_for=40):
    return source == "observed" and not dead and 0 <= age <= fresh_for


def main():
    paths = (PERCEPTION, CONTROLLER, SCANNER, BRIDGE)
    if any(not path.exists() for path in paths):
        print("FAULT: an activity-participant source surface is missing")
        return 1
    sources = [path.read_text(encoding="utf-8", errors="ignore") for path in paths]
    faults = source_faults(*sources)

    if not candidate("observed", False, 20):
        faults.append("CONTROL model refused a fresh observed participant")
    for case in (("told", False, 20), ("observed", True, 20),
                 ("observed", False, 41), ("observed", False, -1)):
        if candidate(*case):
            faults.append("CONTROL model admitted a told, dead, stale or future belief")

    perception, controller, scanner, bridge = sources
    mutations = (
        (perception.replace('belief.source ~= "observed"', "false", 1),
         controller, scanner, bridge, "firsthand provenance"),
        (perception, controller.replace(
            "return SAOJavaBridge:canSeePersonNow(body, otherBody, actionRange)",
            "return true", 1), scanner, bridge, "use-time visibility"),
        (perception, controller, scanner.replace(
            "Math.abs(other.getZ() - sz) >= 0.5f", "false", 1), bridge,
         "same-floor check"),
        (perception, controller, scanner.replace(
            "!eye.isSomethingTo(target)", "true", 1), bridge, "occlusion check"),
    )
    for p, c, s, b, label in mutations:
        if not source_faults(p, c, s, b):
            faults.append("CONTROL removed %s but the border passed" % label)

    if faults:
        for fault in faults:
            print("FAULT: " + fault)
        return 1
    print("176) activity partners require fresh private sight and current physical visibility")
    return 0


if __name__ == "__main__":
    sys.exit(main())
