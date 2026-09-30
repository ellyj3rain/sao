"""Typed experimental desired outcomes; methods remain actor-owned."""
from __future__ import annotations

import math
import re


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
