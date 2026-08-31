#!/usr/bin/env python3
r"""Border 38 - a method called on an inventory item is a method items have.

[B42] found `hasLiveWireRadio` walking the player's inventory and
calling `it:getDeviceData()` on every item in it. That method is
declared on `zombie.inventory.types.Radio`, **not** on
`zombie.inventory.InventoryItem` - so it threw on a claw hammer, a bag
of chips, an ID card: once per item, every time the context menu
opened. A `pcall` swallowed the result, the loop carried on, the
feature worked, and the only symptom was the operator's console filling
with Kahlua stack traces.

That is the defect class `HANDOFF` names as the next sweep: a call
whose failure is indistinguishable from "nothing there". `bridge_arity`
already holds this line for calls into **our** bridge - every Lua call
site must name a real method with an arity some overload accepts. This
holds the same line for calls into the **engine**, on the one receiver
whose type is decidable without inference: an element drawn out of an
inventory container is an `InventoryItem`.

WHAT IT READS
-------------
`InventoryItem`'s own public API, from the installed
`projectzomboid.jar` via javap - 577 methods, none of them
`getDeviceData`. Not a list maintained here, which would rot the first
time the game shipped a new method.

THE ESCAPE HATCH, AND WHY IT IS NOT A HOLE
------------------------------------------
Calling a subclass method is fine once you have ASKED. An
`instanceof(it, "Radio")` in scope makes the receiver's type known, and
the call is then a question rather than a guess. The guard is what the
fix was; the border requires it rather than banning the call.

SKIPs when the engine jar or javap is absent - a check that cannot run
must not look like a check that passed.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from menu_reach import strip_lua                       # noqa: E402

JAVAP = pathlib.Path(
    r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin\javap.exe")
PZ = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
    r"\projectzomboid.jar")
ITEM_CLASS = "zombie.inventory.InventoryItem"

# How an inventory container hands over its contents.
WALK = re.compile(r"(\w+)\s*=\s*[^=]*?:\s*(?:getItems|getItemsFromCategory)"
                  r"\s*\(")
# `local it = items:get(i)`  /  `for _, it in ipairs(items)`
DRAW_INDEX = r"local\s+(\w+)\s*=\s*%s\s*:\s*get\s*\("
DRAW_LOOP = r"for\s+[\w,\s]*?(\w+)\s+in\s+\w+\s*\(\s*%s\b"


def item_api():
    if not (JAVAP.exists() and PZ.exists()):
        return None
    try:
        done = subprocess.run(
            [str(JAVAP), "-cp", str(PZ), ITEM_CLASS],
            capture_output=True, text=True, timeout=180)
    except (OSError, subprocess.SubprocessError):
        return None
    if not done.stdout.strip():
        return None
    return set(re.findall(r"\b([a-z]\w*)\s*\(", done.stdout))


def main():
    api = item_api()
    print("=" * 74)
    print("METHODS CALLED ON AN INVENTORY ITEM")
    print("=" * 74)
    if api is None:
        print("  SKIPPED - no engine jar or no javap to read the item API")
        print("  38) item api: SKIPPED, engine jar absent")
        return 0
    print(f"  {ITEM_CLASS} declares {len(api)} methods")

    faults, checked, guarded = [], 0, 0
    for path in sorted(LUA.rglob("*.lua")):
        code = strip_lua(path.read_text(encoding="utf-8", errors="ignore"),
                         strings=False)
        lines = code.split("\n")
        for i, line in enumerate(lines):
            walk = WALK.search(line)
            if not walk:
                continue
            bag = walk.group(1)
            # The element variable, drawn out of that bag nearby.
            elem, at = None, None
            for j in range(i, min(i + 8, len(lines))):
                m = re.search(DRAW_INDEX % re.escape(bag), lines[j]) \
                    or re.search(DRAW_LOOP % re.escape(bag), lines[j])
                if m:
                    elem, at = m.group(1), j
                    break
            if not elem:
                continue
            # Everything called on it before the loop plainly ends.
            body = "\n".join(lines[at:min(at + 40, len(lines))])
            asked = f'instanceof({elem},' in body.replace(" ", "") \
                or f'instanceof({elem} ,' in body
            for call in re.finditer(
                    r"\b%s\s*:\s*(\w+)\s*\(" % re.escape(elem), body):
                method = call.group(1)
                checked += 1
                if method in api:
                    continue
                if asked:
                    guarded += 1
                    continue
                faults.append(
                    f"{path.name}:{at + 1} calls `{elem}:{method}()` on an "
                    f"item out of an inventory, and {ITEM_CLASS} does not "
                    f"declare `{method}` - it throws on every item that is "
                    "not the subclass this assumed. Ask with instanceof "
                    "first, or the failure is indistinguishable from "
                    "finding nothing")

    print(f"  calls on drawn items:  {checked}")
    print(f"  behind an instanceof:  {guarded}")
    print(f"  unasked subclass calls: {len(faults)}")
    if checked == 0:
        faults.append(
            "not one call on a drawn item was examined, so the verdict "
            "below would describe an empty set. [B47] found three borders "
            "in this state by running them against a tree with the Lua "
            "removed - all three passed")

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print(f"  FAULT: {f}")
        return 1
    print("  38) item api: every method called on an item out of an "
          "inventory is one")
    print("      items have, or the code asked what it was holding first")
    return 0


if __name__ == "__main__":
    sys.exit(main())
