#!/usr/bin/env python3
"""Compose pinned Week One controls into SAO's owned registration files.

The dotted option IDs remain saved-world data. SAO owns the default for its
integrated original-strike control; the pinned source fragment stays intact.
"""
from __future__ import annotations

from collections import OrderedDict
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "mod/42.20/media"
SOURCE = ROOT / "tools/weekone_sandbox_controls/bandits-week-one-42.20-sandbox-options.txt"
INSTALLED = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3403180543\mods\BanditsWeekOne\42.20\media\sandbox-options.txt")
SOURCE_SHA256 = "eb6ea76f70b22af0fb68bc5a26445fdfa23992434e88f8d51d4fb71b0fba6ff9"
OPTIONS = MEDIA / "sandbox-options.txt"
PAGES = MEDIA / "lua/shared/SAO_WeekOneSandboxPages.lua"
LOCALE = MEDIA / "lua/shared/Translate/EN/Sandbox.json"

# Source declaration order is retained inside each page. The ID remains the
# source ID so saved worlds and the selected Week One producer read one value.
PAGE_BY_SUFFIX = OrderedDict([
    ("StartTime", "SAO_WeekOne_Start"),
    ("StartBabe", "SAO_WeekOne_Start"),
    ("StartRide", "SAO_WeekOne_Start"),
    ("InhabitantsPopMultiplier", "SAO_WeekOne_People"),
    ("StreetsPopMultiplier", "SAO_WeekOne_People"),
    ("ArmyPopMultiplier", "SAO_WeekOne_People"),
    ("BanditsPopMultiplier", "SAO_WeekOne_People"),
    ("InhabitantsPistolChance", "SAO_WeekOne_People"),
    ("StreetsPistolChance", "SAO_WeekOne_People"),
    ("VehiclesMax", "SAO_WeekOne_Roads"),
    ("VehiclesSpeed", "SAO_WeekOne_Roads"),
    ("PoliceCooldown", "SAO_WeekOne_Response"),
    ("SWATCooldown", "SAO_WeekOne_Response"),
    ("MedicsCooldown", "SAO_WeekOne_Response"),
    ("HazmatCooldown", "SAO_WeekOne_Response"),
    ("FiremanCooldown", "SAO_WeekOne_Response"),
    ("PriceMultiplier", "SAO_WeekOne_Exchange"),
    ("PriceInflation", "SAO_WeekOne_Exchange"),
    ("EventFinalSolution", "SAO_WeekOne_Events"),
    ("EventBoeing", "SAO_WeekOne_Events"),
    ("EventStrafe", "SAO_WeekOne_Events"),
    ("EventBombing", "SAO_WeekOne_Events"),
    ("EventGas", "SAO_WeekOne_Events"),
    ("EventArson", "SAO_WeekOne_Events"),
])
PAGE_LABELS = OrderedDict([
    ("SAO_WeekOne_Start", "SAO / Week One / Start"),
    ("SAO_WeekOne_People", "SAO / Week One / People"),
    ("SAO_WeekOne_Roads", "SAO / Week One / Roads"),
    ("SAO_WeekOne_Response", "SAO / Week One / Response"),
    ("SAO_WeekOne_Exchange", "SAO / Week One / Exchange"),
    ("SAO_WeekOne_Events", "SAO / Week One / Events"),
])
OPTION_LABELS = OrderedDict([
    ("StartTime", "Week One timeline"),
    ("StartBabe", "Nearby independent survivor"),
    ("StartRide", "Starting vehicle"),
    ("InhabitantsPopMultiplier", "Inhabitants"),
    ("StreetsPopMultiplier", "People on the streets"),
    ("ArmyPopMultiplier", "Army presence"),
    ("BanditsPopMultiplier", "Hostile presence"),
    ("InhabitantsPistolChance", "Inhabitants with handguns (%)"),
    ("StreetsPistolChance", "People on the streets with handguns (%)"),
    ("VehiclesMax", "Concurrent driven vehicles"),
    ("VehiclesSpeed", "Driven vehicle speed"),
    ("PoliceCooldown", "Police response interval (minutes)"),
    ("SWATCooldown", "SWAT response interval (minutes)"),
    ("MedicsCooldown", "Medical response interval (minutes)"),
    ("HazmatCooldown", "Hazmat response interval (minutes)"),
    ("FiremanCooldown", "Fire response interval (minutes)"),
    ("PriceMultiplier", "Purchase price multiplier"),
    ("PriceInflation", "Daily price inflation (%)"),
    ("EventFinalSolution", "Original Week One strike"),
    ("EventBoeing", "Aircraft crash"),
    ("EventStrafe", "Strafing runs"),
    ("EventBombing", "Bombing runs"),
    ("EventGas", "Gas attacks"),
    ("EventArson", "Arson"),
])
START_TIME_LABELS = [
    "One week", "Two weeks", "One month", "Three months", "One year", "Ten years",
]
OPTION_TOOLTIPS = {
    "StartTime": "Shifts the Week One schedule relative to the world's start. The selected scenario and calendar stay in the native start flow.",
    "StartBabe": "Adds an independent adult survivor near the selected Week One start. Proximity does not create a relationship; their choices develop during play.",
    "StartRide": "Offers a starting vehicle when a suitable road location is available.",
    "EventFinalSolution": "The original Week One strike setting is retained for saved-world compatibility. The SAO creator chooses no strike or the SAO strike for a new world; existing worlds keep their recorded producer.",
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source_text() -> str:
    raw = SOURCE.read_bytes()
    if sha(raw) != SOURCE_SHA256:
        raise ValueError("sealed Week One sandbox fragment changed")
    if INSTALLED.is_file() and sha(INSTALLED.read_bytes()) != SOURCE_SHA256:
        raise ValueError("installed Week One sandbox fragment changed")
    return raw.decode("utf-8-sig")


def canonical_source_text() -> str:
    # The installed file writes `option ID = {`; the D2 merger and its native
    # merged registrations use `option ID {`. Source values stay pinned here.
    text, count = re.subn(r"(?m)^(option\s+BanditsWeekOne\.[A-Za-z0-9_]+)\s*=\s*\{",
                          r"\1 {", source_text())
    if count != 24:
        raise ValueError("Week One option declaration syntax changed")
    return text.replace("\r\n", "\n")


def owned_source_text() -> str:
    # The original strike stays available by explicit selection. New SAO
    # worlds do not inherit the source mod's automatic strike default.
    text, count = re.subn(
        r"(option BanditsWeekOne\.EventFinalSolution \{\s*"
        r"type = boolean, default = )true(,)",
        r"\1false\2", canonical_source_text())
    if count != 1:
        raise ValueError("Week One strike source default changed")
    return text


def layout() -> OrderedDict[str, tuple[str, str]]:
    return OrderedDict(("BanditsWeekOne." + suffix, ("BanditsWeekOne", page))
                       for suffix, page in PAGE_BY_SUFFIX.items())


def source_rows(parse) -> list[dict]:
    rows = [row for row in parse(canonical_source_text()) if row["kind"] == "block"]
    ids = [row["id"] for row in rows]
    if len(rows) != 24 or ids != list(layout()):
        raise ValueError("Week One option set or source order changed")
    return rows


def compose_sandbox(text: str, parse, repage_options, merge_header) -> str:
    source_rows(parse)
    expected = layout()
    present = {row["id"]: row for row in parse(text) if row["kind"] == "block"
               and row.get("id") in expected}
    if present and len(present) != 24:
        raise ValueError("partial Week One registration in canonical sandbox")
    repaged = repage_options(owned_source_text(), expected, True)
    owned = {row["id"]: row for row in parse(repaged) if row["kind"] == "block"}
    if present:
        for key, row in present.items():
            attrs = {child["key"]: child["value"] for child in row["children"]
                     if child["kind"] == "value"}
            want = {child["key"]: child["value"] for child in owned[key]["children"]
                    if child["kind"] == "value"}
            if row["type"] != "option" or attrs != want:
                if key != "BanditsWeekOne.EventFinalSolution" or attrs != dict(
                        want, default="true"):
                    raise ValueError("Week One option definition changed: " + key)
                migrated, count = re.subn(r"\bdefault\s*=\s*true\b",
                                          "default = false", row["raw"])
                if count != 1 or text.count(row["raw"]) != 1:
                    raise ValueError("ambiguous Week One strike registration")
                text = text.replace(row["raw"], migrated, 1)
        return text
    merged, _ = merge_header([text, repaged], "option", 1)
    return merged


def page_map_text(parse) -> str:
    source_rows(parse)
    lines = [
        "-- Generated by tools/weekone_sandbox_controls.py from the pinned Week One option fragment.",
        "SAO = SAO or {}",
        'SAO.WeekOneSandboxPages = {schema="sao.weekone-sandbox-pages/1", options={',
    ]
    for key, (original, owned) in layout().items():
        suffix = key.split(".", 1)[1]
        lines.append('[' + json.dumps(key) + ']={sourceId="BanditsWeekOne",originalPage="'
                     + original + '",ownedPage="' + owned + '",preferOwned=true,hasTooltip='
                     + ('true' if suffix in OPTION_TOOLTIPS else 'false') + '},')
    lines += ["}}", "return SAO.WeekOneSandboxPages", ""]
    return "\n".join(lines)


def locale_entries() -> OrderedDict[str, str]:
    entries = OrderedDict(("Sandbox_" + key, label)
                          for key, label in PAGE_LABELS.items())
    for suffix, label in OPTION_LABELS.items():
        key = "Sandbox_BanditsWeekOne." + suffix
        entries[key] = label
        alias = "Sandbox_SAO_WeekOne_Control_" + suffix
        entries[alias] = label
        if suffix in OPTION_TOOLTIPS:
            entries[key + "_tooltip"] = OPTION_TOOLTIPS[suffix]
            entries[alias + "_tooltip"] = OPTION_TOOLTIPS[suffix]
    for index, label in enumerate(START_TIME_LABELS, 1):
        entries["Sandbox_BanditsWeekOne.StartTime_option" + str(index)] = label
        entries["Sandbox_SAO_WeekOne_Control_StartTime_option" + str(index)] = label
    entries["Sandbox_SAO_WeekOne_CreatorChoice"] = (
        "Choose no strike or the SAO strike in the character creator after these settings. "
        "That choice sets the producer for this new world."
    )
    return entries


def compose_locale(text: str) -> str:
    current = json.loads(text)
    if not isinstance(current, dict):
        raise ValueError("Sandbox translation is not a JSON object")
    expected = locale_entries()
    present = {key for key in expected if key in current}
    for key in present:
        if current[key] != expected[key]:
            raise ValueError("Week One English sandbox translation changed: " + key)
    if present == set(expected):
        return text
    additions_needed = OrderedDict((key, value) for key, value in expected.items()
                                   if key not in present)
    ending = "\r\n" if "\r\n" in text else "\n"
    last = text.rfind("}")
    if last < 0 or text[last + 1:].strip():
        raise ValueError("Sandbox translation end changed")
    prefix = text[:last].rstrip()
    if not prefix.endswith('"'):
        raise ValueError("Sandbox translation last value changed")
    additions = ("," + ending + ("," + ending).join(
        "  " + json.dumps(key) + ": " + json.dumps(value, ensure_ascii=False)
        for key, value in additions_needed.items()))
    result = prefix + additions + ending + text[last:]
    if json.loads(result) != dict(current, **expected):
        raise ValueError("Week One English translation composition failed")
    return result


def main() -> int:
    import d2_source_registration as reg
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    expected = {
        OPTIONS: compose_sandbox(OPTIONS.read_text(encoding="utf-8"), reg.parse,
                                 reg.repage_options, reg.merge_header).replace("\r\n", "\n"),
        PAGES: page_map_text(reg.parse),
        LOCALE: compose_locale(LOCALE.read_text(encoding="utf-8")),
    }
    changed = []
    for path, value in expected.items():
        before = path.read_bytes().decode("utf-8") if path.exists() else None
        if before != value:
            changed.append(str(path))
            if args.apply:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(value.encode("utf-8"))
    receipt = {
        "schema": "sao.weekone-sandbox-controls/1",
        "status": "APPLIED" if args.apply else ("PASS" if not changed else "DRIFT"),
        "selectedSource": str(INSTALLED), "sourceSha256": SOURCE_SHA256,
        "optionCount": len(PAGE_BY_SUFFIX), "pageCount": len(PAGE_LABELS),
        "changed": changed,
        "outputs": {str(path): sha(value.encode("utf-8")) for path, value in expected.items()},
    }
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(receipt["status"], len(PAGE_BY_SUFFIX), "Week One controls", len(changed), "changed files")
    return 0 if args.apply or not changed else 1


if __name__ == "__main__":
    raise SystemExit(main())
