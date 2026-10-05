#!/usr/bin/env python3
r"""Border 109 - the county's gestures ([C35], DR-034).

The operator ruled that existing art crosses into SAO copied, with
permission, credited, and bound by SAO's own nodes. This border holds
the three things that must agree for a gesture to be seen: the file
under anims_X, the animation-set node that names it, and the name the
module asks for - and that every file is the art it claims to be (the
Bip01 rig the player wears), that the sounds the module plays are
defined over files that exist, that every credited author is in
CREDITS.md, and that the county's moments are wired to the gesture
that shows them: the meeting, the voice's events, the evening seat
and the stand, the porch tune and its listeners.

It never launches a game world: an animation node is a claim the engine
reads at load, so the claim is checked for form (the XML parses, the
conditions name SAO's own variables, the node names start with SAO_
so nothing overlaps another mod) and for reference (the file the
node names exists and is rigged). The live receipt is the operator's:
a survivor seen agreeing, arguing, dancing or playing from the
harness's four clicks. The installed native/Kahlua companion also checks
real Exchange listener admission around native action ownership; it does
not claim rendered animation or completed cooking.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree faults at every seam.
"""
import json
import os
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
sys.path.append(str(pathlib.Path(sys.argv[1]).resolve() / "tools") if len(sys.argv) > 1 else str(pathlib.Path(__file__).resolve().parent))
from lua_read import function_body, strip_lua

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "mod" / "42.20" / "media"
ANIMS = MEDIA / "anims_X" / "Bob"
ACTIONS = MEDIA / "AnimSets" / "player" / "actions"
SEATS = MEDIA / "AnimSets" / "player" / "sitonground-sitting"
SOUNDS = MEDIA / "scripts" / "sounds_SAO.txt"
GESTURE = MEDIA / "lua" / "client" / "SAO_Gesture.lua"
VOICE = MEDIA / "lua" / "client" / "SAO_Voice.lua"
EXCHANGE = MEDIA / "lua" / "client" / "SAO_Exchange.lua"
CONTROLLER = MEDIA / "lua" / "client" / "SAO_Controller.lua"
HARNESS = MEDIA / "lua" / "client" / "SAO_Harness.lua"
CREDITS = ROOT / "CREDITS.md"
MANIFEST = ROOT / "tools" / "gestures_manifest.json"


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def lua_list(src, name):
    """The names in one flat Lua table `G.NAME = { "a", "b" }`: a balanced
    brace pair with no nesting, so the match never runs on into the
    next table or into code (the first draft read "positive" and
    "aligned" out of the event map as gestures)."""
    m = re.search(r"G\.%s\s*=\s*\{([^{}]*)\}" % re.escape(name), src, re.S)
    return re.findall(r'"([A-Za-z0-9_]+)"', m.group(1)) if m else []


INSTRUMENT_WRITER = re.compile(r"\bSAO\.Gesture\.playInstrument\s*\(")
INSTRUMENT_ROUTES = {
    "decideRestActivity": ("what", "carriedInstrument", "material"),
    "Ctl.advanceLeisureParticipation": ("capability.verb", "offer.itemType", "item"),
}


def instrument_pattern(arguments):
    return re.compile(r"\bSAO\.Gesture\.playInstrument\s*\(\s*"
                      + r"\s*,\s*".join(re.escape(arg) for arg in
                          ("id", "body", *arguments, "purpose.id")) + r"\s*\)")


def instrument_faults(source):
    """Both owned routes carry the exact material and admitted purpose.

    A global writer census also refuses an additional unsupported route;
    finding one good call cannot conceal a missing or malformed sibling.
    """
    text = strip_lua(source)
    faults = []
    if len(INSTRUMENT_WRITER.findall(text)) != len(INSTRUMENT_ROUTES):
        faults.append("instrument writer census requires exactly two owned calls")
    for name, arguments in INSTRUMENT_ROUTES.items():
        body = function_body(source, name, stripped=text)
        route = strip_lua(body or "")
        if (len(INSTRUMENT_WRITER.findall(route)) != 1
                or len(instrument_pattern(arguments).findall(route)) != 1):
            faults.append("instrument route requires exact material and purpose: " + name)
    return faults


def instrument_controls(source):
    """Restore omissions and extra writers at each actual source seam."""
    faults = []
    checked = 0
    if instrument_faults(source):
        return ["instrument controls require valid current owned routes"], checked
    text = strip_lua(source)
    for name, arguments in INSTRUMENT_ROUTES.items():
        pattern = instrument_pattern(arguments)
        matches = list(pattern.finditer(text))
        if len(matches) != 1:
            faults.append("instrument control requires one unique route call: " + name)
            continue
        call = matches[0]
        prefix, suffix = source[:call.start()], source[call.end():]
        missing_material = "SAO.Gesture.playInstrument(id, body, %s, %s, purpose.id)" % arguments[:2]
        missing_purpose = "SAO.Gesture.playInstrument(id, body, %s, %s, %s)" % arguments
        witness = "instrument route requires exact material and purpose: " + name
        for label, replacement in (
                ("missing material", missing_material),
                ("missing purpose", missing_purpose),
                ("missing call", "false"),
                ("commented call", "false -- " + " ".join(call.group().split()) + "\n"),
                ("duplicate call", call.group() + "\n" + call.group())):
            checked += 1
            if witness not in instrument_faults(prefix + replacement + suffix):
                faults.append("instrument control accepted " + label + ": " + name)
        # Matching invocation text in a string or comment is not a writer.
        inert = source + '\n-- ' + call.group() + '\nlocal inert = "' + call.group() + '"\n'
        checked += 1
        if instrument_faults(inert):
            faults.append("instrument control counted comment/string text: " + name)
    checked += 1
    if not instrument_faults(source + "\nSAO.Gesture.playInstrument(id, body, what)\n"):
        faults.append("instrument control accepted an unsupported extra writer")
    return faults, checked


def main():
    faults = []
    print("=" * 74)
    print("THE COUNTY'S GESTURES")
    print("=" * 74)
    for path, what in ((GESTURE, "SAO_Gesture.lua"), (MANIFEST, "the manifest"),
                       (SOUNDS, "the sound script"), (ANIMS, "anims_X/Bob"),
                       (ACTIONS, "the action nodes"), (SEATS, "the seat nodes")):
        if not path.exists():
            faults.append(what + " does not exist")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1

    manifest = json.loads(read(MANIFEST))
    files = manifest.get("files", [])
    print("     manifest: %d files, %d nodes" % (len(files), len(manifest.get("nodes", {}))))
    rigged, missing = 0, 0
    for entry in files:
        p = ROOT / entry["file"]
        if not p.exists() or p.stat().st_size == 0:
            missing += 1
            faults.append("copied file missing or empty: " + entry["file"])
            continue
        if p.suffix.lower() in (".fbx", ".x"):
            data = p.read_bytes()
            if b"Bip01_Pelvis" in data and b"Bip01_Head" in data:
                rigged += 1
            else:
                faults.append("not the player's rig: " + entry["file"])
        if not entry.get("author"):
            faults.append("no author in the manifest for " + entry["file"])
    anim_files = {p.stem for p in ANIMS.iterdir() if p.suffix.lower() in (".fbx", ".x")}
    # Week One's file is known to the engine by the stack name inside it
    # (BWO_WaiterServing), which the manifest carries from the source node.
    if (ANIMS / "WaiterServing.fbx").exists() and manifest.get("waiterAnim"):
        anim_files.add(manifest["waiterAnim"])
    # [C119] The same case, generalized: every copied file entry may
    # declare the clip name inside it (`anim`), which is the name the
    # engine - and therefore the node's m_AnimName - knows it by when
    # it is not the file's own name. Counted only for a file that
    # exists, so a missing file still faults above rather than
    # quietly binding its clip.
    for entry in files:
        if entry.get("anim") and (ROOT / entry["file"]).exists():
            anim_files.add(entry["anim"])
    print("     rigged animations: %d; missing files: %d" % (rigged, missing))

    # Every node: parses, SAO_ named, SAO's own variable, names a file.
    nodes = {}
    for folder, var in ((ACTIONS, "SAOGesture"), (SEATS, "SAOSeat")):
        for p in sorted(folder.glob("SAO_*.xml")):
            try:
                root = ET.fromstring(read(p))
            except ET.ParseError as e:
                faults.append("node does not parse: %s (%s)" % (p.name, e))
                continue
            name = root.findtext("m_Name") or ""
            anim = root.findtext("m_AnimName") or ""
            conds = {c.findtext("m_Name"): (c.findtext("m_StringValue") or c.findtext("m_BoolValue"))
                     for c in root.findall("m_Conditions")}
            if not name.startswith("SAO_"):
                faults.append("node name does not start with SAO_: " + p.name)
            if var not in conds:
                faults.append("node %s is not keyed on %s" % (p.name, var))
            if anim not in anim_files:
                faults.append("node %s names an animation with no file: %s" % (p.name, anim))
            nodes[conds.get(var)] = anim
    print("     nodes parsed: %d" % len(nodes))
    if not nodes:
        faults.append("no nodes")

    # Every name the module asks for is bound.
    g = read(GESTURE)
    asked = set()
    for lst in ("SPEAK", "GRIEF", "FRUSTRATED", "TEACH", "BOW", "SPENT", "SERVE",
                "GUITAR", "HARMONICA", "DANCES",
                # [C119] The three new moments' vocabularies.
                "CASHIER", "PROTEST", "CPR"):
        asked.update(lua_list(g, lst))
    listen = re.search(r"G\.LISTEN\s*=\s*\{(.*?)\n\}", g, re.S)
    if listen:
        asked.update(re.findall(r'"([A-Za-z0-9_]+)"', listen.group(1)))
    # [C119] The bard's map is keyed by item type, so only its VALUES
    # are gesture names - the keys ("Base.Flute") are the engine's own
    # item names and would read as unbound gestures if the flat
    # list reader picked them up.
    bard = re.search(r"G\.BARD\s*=\s*\{(.*?)\n\}", g, re.S)
    if bard:
        asked.update(re.findall(r'=\s*"([A-Za-z0-9_]+)"', bard.group(1)))
    seats = set(lua_list(g, "SEATS"))
    for name in re.findall(r'"(IsSittingLoop[A-Za-z_]*)"', g):
        seats.add(name)
    unbound = sorted(n for n in asked if n not in nodes)
    unbound_seats = sorted(n for n in seats if n not in nodes)
    print("     names asked: %d gestures, %d seats; unbound: %d, %d"
          % (len(asked), len(seats), len(unbound), len(unbound_seats)))
    for n in unbound:
        faults.append("the module asks for a gesture with no node: " + n)
    for n in unbound_seats:
        faults.append("the module asks for a seat with no node: " + n)
    if len(asked) < 30:
        faults.append("the module's vocabulary is thin: %d names" % len(asked))

    # The sounds: every clip file exists; every name the module plays is defined.
    snd = read(SOUNDS)
    defined = set(re.findall(r"sound (SAO\w+)", snd))
    clips = re.findall(r"file = (media/sound/[^,\s]+)", snd)
    for c in clips:
        if not (ROOT / "mod" / "42.20" / c).exists():
            faults.append("sound clip missing: " + c)
    for i in range(1, 14):
        if "SAOClap%d" % i not in defined:
            faults.append("SAOClap%d is not defined" % i)
    for tag in ("M", "F"):
        for i in range(1, 5):
            if "SAOCough%s%d" % (tag, i) not in defined:
                faults.append("SAOCough%s%d is not defined" % (tag, i))
    print("     sounds defined: %d over %d clips" % (len(defined), len(clips)))

    ctl = read(CONTROLLER)
    route_faults = instrument_faults(ctl)
    faults.extend(route_faults)
    control_faults, instrument_count = instrument_controls(ctl)
    faults.extend(control_faults)
    print("     instrument routes: %d owned; restored-defect controls: %d"
          % (len(INSTRUMENT_ROUTES), instrument_count))
    seams = {
        "the action derives from the vanilla base": 'ISBaseTimedAction:derive("SAOGestureAction")' in g,
        "and carries the variable the nodes read": 'self:setAnimVariable("SAOGesture", self.gesture)' in g,
        "the voice's events reach the gesture": "SAO.Gesture.onEvent(id, event, tick)" in read(VOICE),
        "the meeting is seen on both people": "SAO.Gesture.meet(id, body, otherId, otherBody, verdict, warmM, sharpM)" in read(EXCHANGE),
        "the evening seat sets the seat": "SAO.Gesture.seat(id, body)" in ctl,
        "and every stand clears it": ctl.count("SAO.Gesture.standUp(") >= 3,
        # The ordinary and shared routes both carry current material,
        # observed type and the purpose that owns queue completion.
        "the tune plays the instrument": not route_faults,
        "unobserved tune grants no listener effects": "easeListeners(body, 12)" not in ctl,
        "the harness gives the four receipts": all(s in read(HARNESS) for s in
            ('"Gesture: agree"', '"Gesture: argue"', '"Dance a while"', '"Play the guitar"')),
        "the credits name Hobbies": "## Lifestyle: Hobbies (Angry)" in read(CREDITS),
        "and Week One's art": "## Week One (Slayer), for its art" in read(CREDITS),
        "the seat is cleared by name": 'body:clearVariable("SAOSeat")' in g,
        "greetings use the engine's own emotes": 'body:playEmote(arg)' in g,
    }
    print()
    print("  THE SEAMS")
    for k, v in seams.items():
        print("    %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append("seam missing: " + k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    from gesture_ownership_checks.run_checks import run as check_native_ownership
    if check_native_ownership(ROOT, output=os.environ.get("SAO_GESTURE_PROOF"),
            gesture=os.environ.get("SAO_GESTURE_SOURCE")) != 0:
        return 1
    print("  109) the county's gestures: %d rigged files, %d nodes, %d names bound, %d sounds, every moment wired"
          % (rigged, len(nodes), len(asked) + len(seats), len(defined)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
