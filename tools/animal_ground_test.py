#!/usr/bin/env python3
r"""Border 155 - an animal is not a foreign person.

Build 42 animals are `IsoAnimal`, which extends `IsoPlayer`.  The old
foreign-person predicate recognised an off-slot non-shell `IsoPlayer` and
therefore filed every animal as somebody from another NPC framework.  The
predicate repair alone was insufficient: the broader scan branch still emitted
the animal as a human `P` row before any lookup used that classification.

This holds the class order: animals stop before the person fallthrough;
our shells and slot players remain excluded; a genuine off-slot human is
still a foreign person.  The source control removes the animal guard and
must make the border fault.
"""
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
SCANNER = ROOT / "java" / "src" / "com" / "sao" / "engine" / \
    "SAOPerceptionScanner.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / \
    "SAOBridge.java"


def method_body(src, name):
    """Return a Java method body by brace balance."""
    match = re.search(r"^\s{4}(?:public|private|protected)\s+.*?\b"
                      + re.escape(name) + r"\s*\([^)]*\)\s*\{", src,
                      re.M)
    if match is None:
        return ""
    start = match.end() - 1
    depth, at = 0, start
    while at < len(src):
        if src[at] == "{":
            depth += 1
        elif src[at] == "}":
            depth -= 1
            if depth == 0:
                return src[start:at]
        at += 1
    return ""


def source_faults(scanner_src, bridge_src):
    predicate = method_body(scanner_src, "isForeignPerson")
    scan = method_body(scanner_src, "scan")
    combat = method_body(bridge_src, "beginCombatWithName")
    faults = []
    if "import zombie.characters.animals.IsoAnimal;" not in scanner_src:
        faults.append("the scanner does not name the engine animal class")

    guard = re.search(r"person\s*==\s*null\s*\|\|\s*"
                      r"person\s+instanceof\s+IsoAnimal\b", predicate)
    shell = predicate.find("person instanceof SAOIsoPlayerShell")
    slots = predicate.find("IsoPlayer.players")
    if guard is None:
        faults.append("an IsoAnimal falls through as a foreign person")
    elif (shell >= 0 and guard.start() > shell) or \
            (slots >= 0 and guard.start() > slots):
        faults.append("the animal guard runs after the person fallthrough")
    scan_guard = scan.find("!(person instanceof IsoAnimal)")
    human_output = scan.find('appendIfVisible(out, "P", label')
    if scan_guard < 0 or human_output < 0 or scan_guard > human_output:
        faults.append("the actual scanner can emit an IsoAnimal as a human P row")
    if "person instanceof IsoAnimal" not in combat:
        faults.append("the named-combat lookup can target an IsoAnimal")
    return faults


class IsoPlayer:
    pass


class SAOShell(IsoPlayer):
    pass


class IsoAnimal(IsoPlayer):
    pass


def old_foreign(person, local_players):
    return person is not None and not isinstance(person, SAOShell) \
        and person not in local_players


def fixed_foreign(person, local_players):
    return person is not None and not isinstance(person, IsoAnimal) \
        and not isinstance(person, SAOShell) and person not in local_players


def main():
    if not SCANNER.exists() or not BRIDGE.exists():
        print("FAULT: an animal/person source surface is missing")
        return 1
    scanner_src = SCANNER.read_text(encoding="utf-8", errors="ignore")
    bridge_src = BRIDGE.read_text(encoding="utf-8", errors="ignore")
    faults = source_faults(scanner_src, bridge_src)

    local = IsoPlayer()
    shell = SAOShell()
    animal = IsoAnimal()
    foreign = IsoPlayer()
    if not old_foreign(animal, [local]):
        faults.append("CONTROL old predicate did not misclassify the animal")
    if (fixed_foreign(animal, [local])
            or fixed_foreign(shell, [local])
            or fixed_foreign(local, [local])
            or not fixed_foreign(foreign, [local])):
        faults.append("the class-order model does not preserve person domains")

    bad_scanner = re.sub(r"\s*\|\|\s*person\s+instanceof\s+IsoAnimal",
                         "", scanner_src, count=1)
    if bad_scanner == scanner_src:
        faults.append("CONTROL did not remove the scanner animal guard")
    elif not source_faults(bad_scanner, bridge_src):
        faults.append("CONTROL removed the scanner animal guard but the "
                      "border passed")

    bad_output = scanner_src.replace(
        "                && !(person instanceof IsoAnimal)\n", "", 1)
    if bad_output == scanner_src:
        faults.append("CONTROL did not remove the emitted-row animal guard")
    elif not source_faults(bad_output, bridge_src):
        faults.append("CONTROL removed the emitted-row animal guard but the "
                      "border passed")

    bad_bridge = re.sub(r"\s*\|\|\s*person\s+instanceof\s+IsoAnimal",
                        "", bridge_src, count=1)
    if bad_bridge == bridge_src:
        faults.append("CONTROL did not remove the combat animal guard")
    elif not source_faults(scanner_src, bad_bridge):
        faults.append("CONTROL removed the animal guard but the border passed")

    if faults:
        for fault in faults:
            print("FAULT: " + fault)
        return 1
    print("155) animals leave the person path before classification and P-row output")
    return 0


if __name__ == "__main__":
    sys.exit(main())
