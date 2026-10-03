"""Native observation areas, independent of the saved simulation definition."""
from __future__ import annotations

import re
import struct
from pathlib import Path

import world_lab as Lab


def validate(value, definition):
    Lab.fields(value, {"schema", "sites"}, "observer layout")
    Lab.require(value["schema"] == "sao-study-observer-layout/1", "observer layout schema differs")
    sites = value["sites"]
    Lab.require(isinstance(sites, list) and 1 <= len(sites) <= 4, "expected 1..4 observer areas")
    extent = definition["extent"]
    left, top = extent["minCellX"] * 256, extent["minCellY"] * 256
    right, bottom = left + extent["cellsX"] * 256, top + extent["cellsY"] * 256
    identities, positions, subjects = set(), set(), set()
    for site in sites:
        Lab.require(isinstance(site, dict), "observer area must be an object")
        Lab.fields(site, {"id", "label", "x", "y", "z"}
                   | ({"subjectId"} if "subjectId" in site else set()), "observer area")
        if "subjectId" in site:
            subject = site["subjectId"]
            Lab.require(isinstance(subject, str) and 0 < len(subject) <= 128
                        and subject.strip() == subject
                        and all(33 <= ord(char) < 127 for char in subject)
                        and subject not in subjects, "invalid or duplicate observer subject")
            subjects.add(subject)
        Lab.require(isinstance(site["id"], str) and re.fullmatch(r"[a-z][a-z0-9-]{0,47}", site["id"])
                    and site["id"] not in identities, "invalid or duplicate observer area id")
        Lab.require(isinstance(site["label"], str) and 0 < len(site["label"]) <= 160
                    and all(32 <= ord(char) < 127 for char in site["label"]), "invalid observer area label")
        Lab.number(site["x"], left, right, "observer x")
        Lab.number(site["y"], top, bottom, "observer y")
        Lab.number(site["z"], -32, 32, "observer z")
        Lab.require(site["x"] < right and site["y"] < bottom and site["z"] < 32,
                    "observer area leaves world bounds")
        position = tuple(struct.unpack(">f", struct.pack(">f", site[key]))[0] for key in ("x", "y", "z"))
        Lab.require(left <= position[0] < right and top <= position[1] < bottom and -32 <= position[2] < 32,
                    "native observer coordinates leave world bounds")
        Lab.require(position not in positions, "observer areas share a native position")
        identities.add(site["id"]); positions.add(position)
    return value


def from_receipt(receipt, definition):
    present = {key for key in ("observerLayout", "observerLayoutSha256") if key in receipt}
    Lab.require(len(present) in (0, 2), "observer layout receipt is incomplete")
    if not present:
        return None
    value = validate(receipt["observerLayout"], definition)
    Lab.require(Lab.seal(value) == receipt["observerLayoutSha256"], "observer layout seal differs")
    return value


def select(path, previous, definition):
    inherited = from_receipt(previous or {}, definition)
    if path is None:
        return inherited
    path = Path(path)
    Lab.require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 8192,
                "invalid observer layout file")
    return validate(Lab.load(path), definition)


def bind(receipt, layout):
    if layout is not None:
        receipt.update(observerLayout=layout, observerLayoutSha256=Lab.seal(layout))


def sites(receipt, definition):
    layout = from_receipt(receipt, definition)
    return layout["sites"] if layout is not None else definition["observation"].get("sites", [])


def resize(cache, selected):
    """Change only the isolated renderer's two dimensions before native startup."""
    path = Path(cache) / "options.ini"
    text = path.read_text(encoding="utf-8")
    width, height = (1920, 1080) if len(selected) > 1 else (960, 540)
    for key, value in (("width", width), ("height", height)):
        pattern = rf"(?m)^{key}=.*$"
        Lab.require(len(re.findall(pattern, text)) == 1, "renderer dimension missing or duplicated")
        text = re.sub(pattern, f"{key}={value}", text)
    path.write_text(text, encoding="utf-8")


def verify_evidence(layout, evidence):
    expected = [(site["id"], site["label"], index) for index, site in enumerate(layout["sites"])]
    state = evidence["state"]
    Lab.require([(s["id"], s["label"], s["slot"]) for s in state.get("sites", [])] == expected,
                "native observer areas differ from sealed layout")
    if len(expected) > 1:
        Lab.require([(s["id"], s["label"], s["slot"]) for s in evidence["viewport"].get("views", [])]
                    == expected, "native regional pixels missing from sealed layout")
