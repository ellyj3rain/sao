"""Typed experimental desired outcomes; methods remain actor-owned."""
from __future__ import annotations

import math
import re
from datetime import date


def validate_initial_life_history(value, people, sandbox):
    """Dated source episodes bind to admission ordinals; Admissions stamps owner IDs."""
    def require(condition, message):
        if not condition:
            raise ValueError(message)
    def text(v, maximum):
        if not isinstance(v, str) or not v or any(ord(c) < 32 or ord(c) == 127 for c in v):
            return False
        try:
            return len(v.encode("utf-16-le")) // 2 <= maximum
        except UnicodeEncodeError:
            return False
    def word(v):
        return text(v, 96) and re.fullmatch(r"[A-Za-z0-9_:.\-]+", v) is not None
    def dated(v):
        require(isinstance(v, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", v), "invalid life-history date")
        try:
            return date.fromisoformat(v)
        except ValueError as error:
            raise ValueError("invalid life-history date") from error
    def unit(v, low=0):
        return type(v) in (int, float) and math.isfinite(v) and low <= v <= 1
    verbs = {"typically-contains", "may-contain", "contains", "affords", "supports", "is-a", "enables", "may-cause"}
    require(isinstance(people, dict) and people, "initialLifeHistory requires initialPeopleBySite")
    require(isinstance(value, list) and 1 <= len(value) <= 128, "initialLifeHistory requires1..128 person bindings")
    seen, start_dates = set(), set()
    for row in value:
        require(isinstance(row, dict) and set(row) == {"siteId", "actorOrdinal", "startDate", "birthYear", "episodes"}, "invalid life-history person fields")
        require(isinstance(row["siteId"], str) and row["siteId"] in people and type(row["actorOrdinal"]) is int
                and 1 <= row["actorOrdinal"] <= people[row["siteId"]], "life history references an unstaged person")
        binding = (row["siteId"], row["actorOrdinal"])
        require(binding not in seen, "duplicate life-history person")
        seen.add(binding)
        start = dated(row["startDate"])
        start_dates.add(start)
        require(start.year < 1994 and type(row["birthYear"]) is int and 1 <= row["birthYear"] <= start.year, "invalid life-history birth/start year")
        # Sandbox date options use one-based month/day. Native GameTime is the
        # final year/date authority at admission, including custom earlier starts.
        for key, actual in (("StartMonth", start.month), ("StartDay", start.day)):
            if key in sandbox:
                require(type(sandbox[key]) is int and sandbox[key] == actual, "life-history start differs from sandbox date")
        require(isinstance(row["episodes"], list) and len(row["episodes"]) <= 64, "life history permits0..64 episodes")
        ids = set()
        for episode in row["episodes"]:
            required = {"id", "occurredOn", "acquiredOn", "participants", "subject", "action", "description", "valence", "salience", "sourceId", "sourceSha256", "provenance"}
            require(isinstance(episode, dict) and required <= episode.keys() and episode.keys() <= required | {"relations"}, "invalid life-history episode fields")
            require(text(episode["id"], 128) and episode["id"] not in ids, "invalid or duplicate life-history episode")
            ids.add(episode["id"])
            occurred, acquired = dated(episode["occurredOn"]), dated(episode["acquiredOn"])
            require(occurred.year >= row["birthYear"] and occurred <= acquired <= start, "life-history episode chronology differs")
            require(word(episode["subject"]) and word(episode["action"]) and text(episode["description"], 2048)
                    and text(episode["sourceId"], 512) and isinstance(episode["sourceSha256"], str)
                    and re.fullmatch(r"[0-9a-f]{64}", episode["sourceSha256"])
                    and episode["provenance"] in ("real", "authored-synthetic")
                    and unit(episode["valence"], -1) and unit(episode["salience"]), "invalid life-history content or provenance")
            participants = episode["participants"]
            require(isinstance(participants, list) and len(participants) <= 16
                    and all(text(p, 128) for p in participants) and len(set(participants)) == len(participants), "invalid life-history participants")
            relations = episode.get("relations", [])
            require(isinstance(relations, list) and len(relations) <= 16, "invalid life-history relations")
            edges = set()
            for edge in relations:
                require(isinstance(edge, dict) and {"from", "relation", "into", "confidence"} <= edge.keys()
                        and edge.keys() <= {"from", "relation", "into", "confidence", "affirmed"}, "invalid life-history relation fields")
                require(word(edge["from"]) and word(edge["into"]) and isinstance(edge["relation"], str) and edge["relation"] in verbs
                        and unit(edge["confidence"]) and ("affirmed" not in edge or type(edge["affirmed"]) is bool), "invalid life-history relation")
                identity = (edge["from"], edge["relation"], edge["into"])
                require(identity not in edges, "duplicate life-history relation")
                edges.add(identity)
    require(len(start_dates) == 1, "life-history people have different world start dates")


def validate_initial_loose_items(value, observation, extent):
    """Physical floor fixtures; no actor, inventory or knowledge assignment."""
    def require(condition, message):
        if not condition:
            raise ValueError(message)
    sites = {site["id"]: site for site in observation.get("sites", [])}
    require(isinstance(value, list) and 1 <= len(value) <= 32,
            "initialLooseItems requires1..32 declared placements")
    seen, total = set(), 0
    for row in value:
        require(isinstance(row, dict) and set(row) == {"id", "siteId", "x", "y", "z", "fullType", "count"},
                "invalid initial loose item fields")
        require(isinstance(row["id"], str) and re.fullmatch(r"[a-z][a-z0-9-]{0,47}", row["id"])
                and row["id"] not in seen, "invalid or duplicate initial loose item id")
        seen.add(row["id"])
        require(isinstance(row["siteId"], str) and row["siteId"] in sites,
                "initial loose item references unknown site")
        require(isinstance(row["fullType"], str) and len(row["fullType"]) <= 128
                and re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*\.[A-Za-z][A-Za-z0-9_]*", row["fullType"]),
                "initial loose item requires a native module.item fullType")
        require(all(type(row[k]) is int for k in ("x", "y", "z", "count")),
                "initial loose item coordinates and count must be integers")
        site = sites[row["siteId"]]
        require(row["z"] == site["z"] and max(abs(row["x"] - site["x"]), abs(row["y"] - site["y"])) <= 16,
                "initial loose item must be within16 tiles of its site on the same floor")
        require(extent["minCellX"] * 256 <= row["x"] < (extent["minCellX"] + extent["cellsX"]) * 256
                and extent["minCellY"] * 256 <= row["y"] < (extent["minCellY"] + extent["cellsY"]) * 256,
                "initial loose item leaves the world extent")
        require(1 <= row["count"] <= 8, "initial loose item count must be1..8")
        total += row["count"]
    require(total <= 64, "initial loose item total exceeds64")


def validate_initial_awareness(value, people):
    """Explicit personal reports, addressed to a staged native admission ordinal."""
    def require(condition, message):
        if not condition:
            raise ValueError(message)
    def text(value):
        return isinstance(value, str) and 0 < len(value) <= 128 and not any(ord(c) < 32 or ord(c) == 127 for c in value)
    require(isinstance(people, dict) and people, "initialAwareness requires initialPeopleBySite")
    require(isinstance(value, list) and 1 <= len(value) <= 128, "initialAwareness requires1..128 person bindings")
    seen = set()
    for row in value:
        require(isinstance(row, dict) and set(row) == {"siteId", "actorOrdinal", "entries"}, "invalid initial awareness person fields")
        require(isinstance(row["siteId"], str) and row["siteId"] in people
                and type(row["actorOrdinal"]) is int and 1 <= row["actorOrdinal"] <= people[row["siteId"]],
                "initial awareness references an unstaged person")
        key = (row["siteId"], row["actorOrdinal"])
        require(key not in seen, "duplicate initial awareness person")
        seen.add(key)
        require(isinstance(row["entries"], list) and len(row["entries"]) <= 8, "initial awareness permits0..8 reports")
        ids = set()
        for entry in row["entries"]:
            require(isinstance(entry, dict) and set(entry) == {"id", "kind", "affirmed", "sourceId", "sourceAtHours", "receivedAtHours", "certainty"}, "invalid initial awareness report fields")
            require(text(entry["id"]) and entry["id"] not in ids and text(entry["sourceId"]), "invalid or duplicate initial awareness source")
            ids.add(entry["id"])
            require(entry["kind"] in ("outbreak", "turned") and type(entry["affirmed"]) is bool
                    and entry["certainty"] in ("reported", "witnessed"), "invalid initial awareness proposition")
            require(all(type(entry[k]) in (int, float) and math.isfinite(entry[k]) for k in ("sourceAtHours", "receivedAtHours"))
                    and 0 <= entry["sourceAtHours"] <= entry["receivedAtHours"], "invalid initial awareness chronology")


def validate_initial_threats(value, observation, extent):
    def require(condition, message):
        if not condition:
            raise ValueError(message)
    sites = {site["id"]: site for site in observation.get("sites", [])}
    require(isinstance(value, list) and 1 <= len(value) <= 12, "initialThreats requires1..12 declared placements")
    seen, total = set(), 0
    for row in value:
        require(isinstance(row, dict) and set(row) == {"id", "siteId", "x", "y", "z", "count"}, "invalid initial threat fields")
        require(isinstance(row["id"], str) and re.fullmatch(r"[a-z][a-z0-9-]{0,47}", row["id"])
                and row["id"] not in seen, "invalid or duplicate initial threat id")
        seen.add(row["id"])
        require(isinstance(row["siteId"], str) and row["siteId"] in sites, "initial threat references unknown site")
        site = sites[row["siteId"]]
        require(all(type(row[key]) is int for key in ("x", "y", "z", "count")), "initial threat coordinates and count must be integers")
        require(row["z"] == site["z"] and 8 <= max(abs(row["x"] - site["x"]), abs(row["y"] - site["y"])) <= 96,
                "initial threat must be8..96 tiles from its site on the same floor")
        require(extent["minCellX"] * 256 <= row["x"] < (extent["minCellX"] + extent["cellsX"]) * 256
                and extent["minCellY"] * 256 <= row["y"] < (extent["minCellY"] + extent["cellsY"]) * 256,
                "initial threat leaves the world extent")
        require(1 <= row["count"] <= 32, "initial threat count must be1..32")
        total += row["count"]
    require(total <= 128, "initial threat total exceeds128")


def validate_initial_people(value, observation, sandbox, origins):
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    sites = observation.get("sites", []) if isinstance(observation, dict) else []
    require(isinstance(sites, list) and 1 <= len(sites) <= 4
            and all(isinstance(site, dict) and {"id", "x", "y", "z"} <= site.keys()
                    for site in sites), "initialPeopleBySite requires declared sites")
    site_ids = {site["id"] for site in sites}
    require(isinstance(value, dict) and 1 <= len(value) <= 4 and set(value) <= site_ids,
            "initialPeopleBySite references an unknown site")
    require(all(type(count) is int and 1 <= count <= 500 for count in value.values()),
            "initialPeopleBySite counts must be integers in1..500")
    require(sandbox.get("SurvivorAwareness.Enable", True) is True,
            "initialPeopleBySite requires enabled population generation")
    require(sandbox.get("SurvivorAwareness.PopulationGoverned") is True
            and type(sandbox.get("SurvivorAwareness.Population")) is int
            and 1 <= sandbox["SurvivorAwareness.Population"] <= 500
            and sum(value.values()) == sandbox["SurvivorAwareness.Population"],
            "initialPeopleBySite must total the governed native population")
    covered = set()
    for origin in origins:
        distances = sorted(((origin["x"] - site["x"]) ** 2 + (origin["y"] - site["y"]) ** 2,
                            site["id"]) for site in sites if origin["z"] == site["z"])
        if distances and distances[0][0] < 48 ** 2 and (len(distances) == 1
                or distances[0][0] != distances[1][0]):
            covered.add(distances[0][1])
    require(set(value) <= covered, "initialPeopleBySite has no unambiguous native origin for a site")


def validate_resource_objectives(value, observation):
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    sites = observation.get("sites", []) if isinstance(observation, dict) else []
    require(isinstance(sites, list) and sites, "resourceObjectives require declared observation sites")
    site_ids = {site["id"] for site in sites if isinstance(site, dict) and isinstance(site.get("id"), str)}
    require(isinstance(value, list) and 1 <= len(value) <= 12,
            "resourceObjectives: expected1..12 desired outcomes")
    seen = set()
    required = {"id", "revision", "siteId", "actorOrdinal", "category", "target", "unit"}
    for row in value:
        require(isinstance(row, dict) and required <= row.keys()
                and row.keys() <= required | {"deadlineAfterHours"}, "invalid resource objective fields")
        name = row["id"]
        require(isinstance(name, str) and re.fullmatch(r"[a-z][a-z0-9_-]{0,79}", name),
                "invalid resource objective id")
        require(name not in seen, "duplicate resource objective id")
        seen.add(name)
        require(type(row["revision"]) is int and 1 <= row["revision"] <= 1000000,
                "invalid resource objective revision")
        require(isinstance(row["siteId"], str) and row["siteId"] in site_ids,
                "resource objective references unknown site")
        require(type(row["actorOrdinal"]) is int and 1 <= row["actorOrdinal"] <= 128,
                "invalid regional actor ordinal")
        category, target, unit = row["category"], row["target"], row["unit"]
        require(type(target) in (int, float) and math.isfinite(target) and 0 < target <= 128,
                "invalid resource objective target")
        require((category == "food" and unit == "usable-food-item" and int(target) == target)
                or (category == "water" and unit == "native-clean-fluid-amount"),
                "resource objective category and unit disagree")
        if "deadlineAfterHours" in row:
            deadline = row["deadlineAfterHours"]
            require(type(deadline) in (int, float) and math.isfinite(deadline) and 0 < deadline <= 87600,
                    "invalid resource objective relative deadline")
