#!/usr/bin/env python3
"""Build isolated native study maps and inspect their actual runtime observations.

This tool authors initial conditions. PZ and the installed execution owners
produce the world and its behavior. Building a package never produces a run,
a judgment, or a training example.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "tools/world_lab/StudyWorld.lua"
SCHEMA = "sao-study-world/1"
FRAME = "sao-study-observation/1"
CELL = 256
CHUNK = 8


def require(condition, message):
    if not condition:
        raise ValueError(message)


def fields(value, names, where):
    require(isinstance(value, dict) and set(value) == set(names),
            f"{where}: expected fields {', '.join(sorted(names))}")


def integer(value, minimum, maximum, where):
    require(type(value) is int and minimum <= value <= maximum,
            f"{where}: expected integer {minimum}..{maximum}")
    return value


def number(value, minimum, maximum, where):
    require(type(value) in (int, float) and math.isfinite(value)
            and minimum <= value <= maximum, f"{where}: out of range")
    return value


def canonical(value):
    return json.dumps(value, ensure_ascii=True, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def seal(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def decode(source):
    def floating(literal):
        value = float(literal)
        require(math.isfinite(value), "non-finite JSON number")
        return value

    def pairs(items):
        value = {}
        for key, item in items:
            require(key not in value, f"duplicate JSON key: {key}")
            value[key] = item
        return value
    return json.loads(source,
                      object_pairs_hook=pairs, parse_float=floating,
                      parse_constant=lambda s: (_ for _ in ()).throw(ValueError(s)))


def load(path):
    return decode(Path(path).read_text(encoding="utf-8-sig"))


def validate(value):
    fields(value, {"schema", "id", "seed", "extent", "origins", "sandbox", "generation",
                   "observation"}, "world")
    require(value["schema"] == SCHEMA, "unsupported world schema")
    require(isinstance(value["id"], str)
            and re.fullmatch(r"[a-z][a-z0-9-]{0,47}", value["id"]), "invalid world id")
    require(isinstance(value["seed"], str) and 0 < len(value["seed"]) <= 128
            and all(32 <= ord(c) < 127 for c in value["seed"]), "invalid seed")
    extent = value["extent"]
    fields(extent, {"minCellX", "minCellY", "cellsX", "cellsY"}, "extent")
    for axis in "XY":
        start = integer(extent["minCell" + axis], -250, 250, "minimum cell")
        size = integer(extent["cells" + axis], 1, 501, "cell count")
        require(start + size - 1 <= 250, "extent exceeds supported generation coordinates")
    lo_x, lo_y = extent["minCellX"] * CELL, extent["minCellY"] * CELL
    hi_x, hi_y = lo_x + extent["cellsX"] * CELL, lo_y + extent["cellsY"] * CELL

    def point(row, where):
        integer(row["x"], lo_x, hi_x - 1, where + " x")
        integer(row["y"], lo_y, hi_y - 1, where + " y")
        integer(row["z"], -32, 31, where + " z")

    origins = value["origins"]
    require(isinstance(origins, list) and 1 <= len(origins) <= 4096,
            "origins: expected 1..4096 points")
    for row in origins:
        fields(row, {"x", "y", "z", "profession"}, "origin")
        point(row, "origin")
        require(isinstance(row["profession"], str)
                and re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,79}", row["profession"]),
                "invalid origin profession")
    require(any(row["profession"] == "unemployed" for row in origins),
            "origins require an explicit unemployed fallback for native character creation")
    generation = value["generation"]
    require(isinstance(generation, dict)
            and {"roads"} <= generation.keys()
            and generation.keys() <= {"roads", "staticModules"}, "invalid generation fields")
    roads = value["generation"]["roads"]
    require(isinstance(roads, dict) and len(roads) <= 32, "invalid road definitions")
    for key, road in roads.items():
        require(re.fullmatch(r"[a-z][a-z0-9_]{0,79}", key), "invalid native road name")
        fields(road, {"p", "filter_edge"}, "native road parameters")
        number(road["p"], 1e-9, 1, "road probability per cell")
        number(road["filter_edge"], 0, 1e12, "native road edge filter")
    if "staticModules" in generation:
        modules = generation["staticModules"]
        require(isinstance(modules, list) and 1 <= len(modules) <= 128,
                "staticModules: expected 1..128 ordered regions")
        for module in modules:
            require(isinstance(module, dict)
                    and (set(module) == {"position", "biome"}
                         or set(module) == {"position", "prefab"}),
                    "static module requires position and exactly one biome or prefab")
            position = module["position"]
            fields(position, {"xmin", "xmax", "ymin", "ymax"}, "static module position")
            for axis, low, high in (("x", lo_x, hi_x), ("y", lo_y, hi_y)):
                start = integer(position[axis + "min"], low, high - 1, "static module minimum")
                integer(position[axis + "max"], start, high - 1, "static module maximum")
            name = module.get("biome", module.get("prefab"))
            require(isinstance(name, str) and re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,79}", name),
                    "invalid native static module name")
    options = value["sandbox"]
    require(isinstance(options, dict), "sandbox must be an option map")
    for key, val in options.items():
        require(re.fullmatch(r"[A-Za-z][A-Za-z0-9_.]{0,95}", key) is not None,
                "invalid sandbox key")
        require(type(val) in (bool, int, float, str), "sandbox values must be scalar")
        if type(val) in (int, float):
            number(val, -1e9, 1e9, "sandbox value")
        if type(val) is str:
            require(len(val) <= 512, "sandbox string too long")
    obs = value["observation"]
    fields(obs, {"everyHours", "maxPeople", "maxProcesses", "windows"}, "observation")
    number(obs["everyHours"], 1 / 3600, 720, "observation period")
    integer(obs["maxPeople"], 1, 100000, "people capture budget")
    integer(obs["maxProcesses"], 1, 4096, "process capture budget")
    require(isinstance(obs["windows"], list) and 1 <= len(obs["windows"]) <= 64,
            "expected 1..64 observation windows")
    count = 0
    ids = set()
    for row in obs["windows"]:
        fields(row, {"id", "x", "y", "z", "width", "height"}, "observation window")
        require(isinstance(row["id"], str)
                and re.fullmatch(r"[a-z][a-z0-9-]{0,47}", row["id"]), "invalid window id")
        require(row["id"] not in ids, "duplicate window id")
        ids.add(row["id"])
        point(row, "window")
        width = integer(row["width"], 1, 256, "window width")
        height = integer(row["height"], 1, 256, "window height")
        require(row["x"] + width <= hi_x and row["y"] + height <= hi_y,
                "window extends outside world")
        count += width * height
    require(count <= 65536, "observation windows exceed 65536-square capture budget")
    return value


def lua(value):
    """Data-only Lua literal; never interpolate supplied text as Lua source."""
    if value is None:
        return "nil"
    if type(value) is bool:
        return "true" if value else "false"
    if type(value) in (int, float):
        require(math.isfinite(value), "non-finite Lua value")
        return repr(value)
    if isinstance(value, str):
        return '"' + "".join(chr(b) if 32 <= b < 127 and b not in (34, 92)
                             else f"\\{b:03d}" for b in value.encode("utf-8")) + '"'
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("[" + lua(k) + "]=" + lua(v)
                               for k, v in sorted(value.items())) + "}"
    raise ValueError("unsupported Lua value")


def static_modules_source(generation):
    """The native loader consumes these regions in their definition order."""
    modules = generation.get("staticModules")
    if modules is None:
        return None
    return ("-- Native static modules: first matching inclusive region wins.\n"
            "local definitions = " + lua(modules) + "\n"
            "local modules = {}\n"
            "for i, definition in ipairs(definitions) do\n"
            "    local module = { position = definition.position }\n"
            "    if definition.biome then\n"
            "        module.biome = assert(worldgen.biomes[definition.biome], 'unknown native biome: ' .. definition.biome)\n"
            "        assert(not module.biome.parent, 'static modules require a complete native base biome')\n"
            "    else\n"
            "        module.prefab = assert(worldgen.prefabs[definition.prefab], 'unknown native prefab: ' .. definition.prefab)\n"
            "    end\n"
            "    modules[i] = module\n"
            "end\n"
            "worldgen.static_modules = modules\n").encode("utf-8")


def engine_evidence(game, generation=None):
    game = Path(game)
    sources = {
        "jar": game / "projectzomboid.jar",
        "mapFormat": game / "media/maps/Muldraugh, KY/map.info",
        "boundsWriter": game / "media/lua/client/OptionScreens/WorldSelect.lua",
        "proceduralMap": game / "media/maps/challengemaps/The Forest/map.info",
    }
    if generation and generation.get("staticModules"):
        sources["staticModuleExample"] = game / "media/maps/Muldraugh, KY/WorldGenOverride.lua"
        for module in generation["staticModules"]:
            kind = "biome" if "biome" in module else "prefab"
            name = module[kind]
            directory = "biomes/worldgen" if kind == "biome" else "prefabs"
            namespace = "biomes" if kind == "biome" else "prefabs"
            pattern = re.compile(r'worldgen\.' + namespace + r'\[\s*["\']' + re.escape(name) + r'["\']\s*\]\s*=')
            matches = [path for path in (game / "media/lua/server/WorldGen" / directory).glob("*.lua")
                       if pattern.search(path.read_text(encoding="utf-8"))]
            require(len(matches) == 1, "unknown or ambiguous installed native " + kind + ": " + name)
            sources["staticModule/" + kind + "/" + name] = matches[0]
    data = {key: path.read_bytes() for key, path in sources.items()}
    require(b"Cell size is 256x256" in data["mapFormat"]
            and b"Chunk size is 8x8" in data["mapFormat"], "engine map format differs")
    require(all(name.encode() in data["boundsWriter"] for name in (
        "setMinXCell", "setMaxXCell", "setMinYCell", "setMaxYCell", "setSeedString")),
        "native world-generation interface differs")
    require(b"lots=NONE" in data["proceduralMap"], "native procedural map definition differs")
    return {key: {"sha256": hashlib.sha256(blob).hexdigest(), "bytes": len(blob)}
            for key, blob in data.items()}


def build(value, destination, game):
    validate(value)
    destination = Path(destination).resolve()
    require(not destination.exists(), "output already exists; select a new package path")
    evidence = engine_evidence(game, value["generation"])
    subject = seal(value)
    map_name = "Study-" + value["id"] + "-" + subject[:12]
    observer = TEMPLATE.read_text(encoding="utf-8")
    observer_hash = hashlib.sha256(observer.encode("utf-8")).hexdigest()
    config = {**value, "definitionSha256": subject, "mapName": map_name,
              "engineJarSha256": evidence["jar"]["sha256"],
              "observerSha256": observer_hash,
              "cellSize": CELL, "chunkSize": CHUNK}
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".world-build-", dir=destination.parent))
    try:
        mod = staging / "mod" / map_name
        version = mod / "42.20"
        maps = version / "media/maps" / map_name
        client = version / "media/lua/client"
        maps.mkdir(parents=True)
        client.mkdir(parents=True)
        # MapGroups tests the common maps directory before visiting the version
        # directory. Keep it present in archives so native Continue finds this map.
        common_maps = mod / "common/media/maps"
        common_maps.mkdir(parents=True)
        (common_maps / ".keep").write_text("Native map discovery root.\n", encoding="utf-8")
        metadata = (f"name=Study world: {value['id']}\nid={map_name}\n"
                    "author=ellyj3rain\nversionMin=42.20\nversionMax=42.20\n"
                    "require=SurvivorAwareness\n"
                    "description=Native generated study world and explicit runtime observations.\n")
        (mod / "mod.info").write_text(metadata, encoding="utf-8")
        (version / "mod.info").write_text(metadata, encoding="utf-8")
        (maps / "map.info").write_text(
            f"title={map_name}\nlots=NONE\nfixed2x=true\ndescription=Native study world\n",
            encoding="utf-8")
        override = static_modules_source(value["generation"])
        if override is not None:
            (maps / "WorldGenOverride.lua").write_bytes(override)
        points = {}
        for point in value["origins"]:
            points.setdefault(point["profession"], []).append(
                {"posX": point["x"], "posY": point["y"], "posZ": point["z"]})
        (maps / "spawnpoints.lua").write_text(
            "function SpawnPoints() return " + lua(points) + " end\n", encoding="utf-8")
        (maps / "spawnregions.lua").write_text(
            "function SpawnRegions() return " + lua([{
                "name": map_name, "file": f"media/maps/{map_name}/spawnpoints.lua"
            }]) + " end\n", encoding="utf-8")
        runtime = "local Config = " + lua(config) + "\n" + observer
        (client / (map_name + ".lua")).write_bytes(runtime.encode("utf-8"))
        (staging / "definition.json").write_bytes(canonical(value) + b"\n")
        manifest = {"schema": "sao-study-package/1", "definitionSha256": subject,
                    "mapName": map_name, "engine": evidence, "observerSha256": observer_hash,
                    "status": "built-unobserved", "datasetAdmission": "unreviewed",
                    "files": {p.relative_to(staging).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted(staging.rglob("*")) if p.is_file()}}
        (staging / "package.json").write_bytes(canonical(manifest) + b"\n")
        staging.rename(destination)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    return manifest


def verify_package(path):
    """Check package content and embedded configuration without executing Lua."""
    path = Path(path).resolve()
    manifest = load(path / "package.json")
    fields(manifest, {"schema", "definitionSha256", "mapName", "engine", "observerSha256",
                      "status", "datasetAdmission", "files"}, "package")
    require(manifest["schema"] == "sao-study-package/1"
            and manifest["status"] == "built-unobserved"
            and manifest["datasetAdmission"] == "unreviewed", "invalid package standing")
    require(isinstance(manifest["files"], dict) and 1 <= len(manifest["files"]) <= 100,
            "invalid package inventory")
    actual = {p.relative_to(path).as_posix() for p in path.rglob("*")
              if p.is_file() and p != path / "package.json"}
    require(actual == set(manifest["files"]), "package inventory differs")
    for relative, digest in manifest["files"].items():
        source = path / relative
        require(not source.is_symlink() and source.resolve().is_relative_to(path),
                "package file leaves package")
        require(source.stat().st_size <= 64 * 1024 * 1024, "oversized package file")
        require(hashlib.sha256(source.read_bytes()).hexdigest() == digest,
                "package content changed: " + relative)
    definition = validate(load(path / "definition.json"))
    subject = seal(definition)
    map_name = "Study-" + definition["id"] + "-" + subject[:12]
    require(manifest["definitionSha256"] == subject and manifest["mapName"] == map_name,
            "package definition differs")
    runtime = path / "mod" / map_name / "42.20/media/lua/client" / (map_name + ".lua")
    header, observer = runtime.read_bytes().split(b"\n", 1)
    require(hashlib.sha256(observer).hexdigest() == manifest["observerSha256"],
            "package observer differs")
    config = {**definition, "definitionSha256": subject, "mapName": map_name,
              "engineJarSha256": manifest["engine"]["jar"]["sha256"],
              "observerSha256": manifest["observerSha256"], "cellSize": CELL, "chunkSize": CHUNK}
    require(header == ("local Config = " + lua(config)).encode("utf-8"),
            "embedded world configuration differs")
    override = path / "mod" / map_name / "42.20/media/maps" / map_name / "WorldGenOverride.lua"
    expected_override = static_modules_source(definition["generation"])
    require((expected_override is None and not override.exists())
            or (expected_override is not None and override.is_file()
                and override.read_bytes() == expected_override), "native terrain override differs from definition")
    return manifest, definition


def bind_frame(frame, package):
    manifest, definition = package
    require(frame["definitionSha256"] == manifest["definitionSha256"]
            and frame["observerSha256"] == manifest["observerSha256"]
            and frame["packageEngineJarSha256"] == manifest["engine"]["jar"]["sha256"]
            and frame["map"] == manifest["mapName"], "observation package identity differs")
    require(frame["extent"] == definition["extent"]
            and frame["generation"] == definition["generation"]
            and frame["sandbox"] == definition["sandbox"], "observation configuration differs")
    obs = definition["observation"]
    windows = [{k: w[k] for k in ("id", "x", "y", "z", "width", "height")}
               for w in frame["windows"]]
    require(windows == obs["windows"], "observation windows differ from definition")
    require(len(frame["people"]) <= obs["maxPeople"]
            and len(frame["processes"]) <= obs["maxProcesses"], "observation exceeds definition budget")


def validate_frame(frame):
    fields(frame, {"schema", "definitionSha256", "packageEngineJarSha256", "observerSha256",
                   "engineVersion", "map", "save", "sequence", "hours", "session",
                   "datasetAdmission", "extent", "sandbox", "generation", "source", "mods", "windows",
                   "people", "processes", "population", "coverage"}, "observation")
    require(frame["schema"] == FRAME, "unsupported observation schema")
    for key in ("definitionSha256", "packageEngineJarSha256", "observerSha256"):
        require(isinstance(frame[key], str) and re.fullmatch(r"[0-9a-f]{64}", frame[key]),
                "invalid observation hash: " + key)
    for key in ("engineVersion", "map", "save", "session"):
        require(isinstance(frame[key], str) and 0 < len(frame[key]) <= 512,
                "invalid observation identity: " + key)
    require(frame["source"] == "loaded-native-world", "unsupported observation source")
    require(frame["datasetAdmission"] == "unreviewed", "observation claims approval")
    integer(frame["sequence"], 1, 2**53 - 1, "observation sequence")
    number(frame["hours"], 0, 1e9, "observation time")
    require(isinstance(frame["mods"], list) and len(frame["mods"]) <= 10000
            and all(isinstance(m, str) and 0 < len(m) <= 512 for m in frame["mods"]),
            "invalid loaded mod identifiers")
    coverage = frame["coverage"]
    fields(coverage, {"requestedSquares", "loadedSquares", "unavailableSquares",
                      "peopleComplete", "processesComplete", "physicalCoverage",
                      "observerMovesWorld", "organizationAvailable", "totalProcesses",
                      "omittedFields", "omittedFieldCount"}, "coverage")
    require(coverage["physicalCoverage"] == "loaded-squares-only"
            and coverage["observerMovesWorld"] is False, "invalid physical coverage claim")
    for key in ("peopleComplete", "processesComplete", "organizationAvailable"):
        require(type(coverage[key]) is bool, "coverage flag must be Boolean")
    for key in ("requestedSquares", "loadedSquares", "unavailableSquares"):
        integer(coverage[key], 0, 65536, "coverage " + key)
    require(isinstance(coverage["omittedFields"], list)
            and len(coverage["omittedFields"]) <= 256
            and all(isinstance(p, str) for p in coverage["omittedFields"]), "invalid omitted paths")
    integer(coverage["omittedFieldCount"], len(coverage["omittedFields"]), 2**53 - 1,
            "omitted field count")
    windows = frame["windows"]
    require(isinstance(windows, list) and 1 <= len(windows) <= 64, "invalid observation windows")
    fields(frame["extent"], {"minCellX", "minCellY", "cellsX", "cellsY"}, "observed extent")
    for key, value in frame["extent"].items():
        integer(value, -250 if key.startswith("min") else 1,
                250 if key.startswith("min") else 501, "observed extent " + key)
    definition = {"schema": SCHEMA, "id": "inspection", "seed": "inspection",
                  "extent": frame["extent"], "sandbox": frame["sandbox"],
                  "generation": frame["generation"],
                  "origins": [{"x": frame["extent"]["minCellX"] * CELL,
                               "y": frame["extent"]["minCellY"] * CELL,
                               "z": 0, "profession": "unemployed"}],
                  "observation": {"everyHours": 1, "maxPeople": 100000, "maxProcesses": 4096,
                                  "windows": []}}
    requested = loaded = missing = 0
    for window in windows:
        fields(window, {"id", "x", "y", "z", "width", "height", "squares", "unavailable"},
               "captured window")
        spec = {k: window[k] for k in ("id", "x", "y", "z", "width", "height")}
        for key in ("x", "y", "z"):
            integer(window[key], -100000, 100000, "window " + key)
        for key in ("width", "height"):
            integer(window[key], 1, 256, "window " + key)
        definition["observation"]["windows"].append(spec)
        require(isinstance(window["squares"], list), "captured squares must be a list")
        integer(window["unavailable"], 0, 65536, "unavailable squares")
        coordinates = set()
        for square in window["squares"]:
            require(isinstance(square, dict) and {"x", "y", "z", "outside", "solid",
                    "solidTrans", "floor", "objects"} <= set(square)
                    and set(square) <= {"x", "y", "z", "outside", "solid", "solidTrans",
                                        "floor", "objects", "floorSprite"}, "invalid square fields")
            integer(square["x"], window["x"], window["x"] + window["width"] - 1, "square x")
            integer(square["y"], window["y"], window["y"] + window["height"] - 1, "square y")
            require(type(square["z"]) is int and square["z"] == window["z"], "square floor differs")
            coordinate = (square["x"], square["y"], square["z"])
            require(coordinate not in coordinates, "duplicate captured square")
            coordinates.add(coordinate)
            require(all(type(square[k]) is bool for k in ("outside", "solid", "solidTrans", "floor")),
                    "square flags must be Boolean")
            require(isinstance(square["objects"], list) and all(isinstance(o, dict)
                    and set(o) <= {"objectName", "sprite", "open", "north"}
                    and all(type(v) is bool if k in ("open", "north") else isinstance(v, str)
                            for k, v in o.items()) for o in square["objects"]), "invalid native objects")
            require("floorSprite" not in square or isinstance(square["floorSprite"], str),
                    "invalid floor sprite")
        require(len(coordinates) + window["unavailable"] == window["width"] * window["height"],
                "window coverage does not reconcile")
        requested += window["width"] * window["height"]
        loaded += len(coordinates)
        missing += window["unavailable"]
    validate(definition)
    require((requested, loaded, missing) == (coverage["requestedSquares"], coverage["loadedSquares"],
                                            coverage["unavailableSquares"]), "coverage counts differ")
    population = frame["population"]
    fields(population, {"total", "captured", "dead", "represented", "unrepresented"}, "population")
    for key, value in population.items():
        integer(value, 0, 2**53 - 1, "population " + key)
    require(population["represented"] + population["unrepresented"] == population["total"]
            and population["dead"] <= population["total"], "population counts differ")
    require(isinstance(frame["people"], list) and len(frame["people"]) <= 100000,
            "invalid captured population")
    seen = set()
    for person in frame["people"]:
        require(isinstance(person, dict) and {"id", "representation", "record", "positionSource", "context"} <= set(person)
                and set(person) <= {"id", "representation", "record", "positionSource", "context", "x", "y", "z"},
                "invalid captured person")
        context = person["context"]
        fields(context, {"controllerAvailable", "perceptionAvailable", "controller", "beliefs"}, "person context")
        for flag, store in (("controllerAvailable", "controller"), ("perceptionAvailable", "beliefs")):
            require(type(context[flag]) is bool and isinstance(context[store], dict)
                    and (context[flag] or not context[store]), "invalid personal inspection coverage")
        require(isinstance(person["id"], str) and person["id"] and person["id"] not in seen,
                "duplicate or invalid person id")
        seen.add(person["id"])
        require(isinstance(person["record"], dict), "person record must be an object")
        require(person["representation"] in ("represented", "unrepresented")
                and person["positionSource"] in ("native-body", "durable-record"), "invalid person coverage")
        if person["positionSource"] == "native-body":
            require(person["representation"] == "represented" and {"x", "y", "z"} <= set(person),
                    "native body position lacks representation")
        for key in ("x", "y", "z"):
            if key in person:
                number(person[key], -1e9, 1e9, "person position")
    require(population["captured"] == len(seen) <= population["total"]
            and coverage["peopleComplete"] == (len(seen) == population["total"]), "captured population differs")
    if coverage["peopleComplete"]:
        require(sum(p["representation"] == "represented" for p in frame["people"])
                == population["represented"], "represented population differs")
    require(isinstance(frame["processes"], list) and len(frame["processes"]) <= 4096,
            "invalid captured processes")
    seen = set()
    for process in frame["processes"]:
        fields(process, {"id", "record"}, "process")
        require(isinstance(process["id"], str) and process["id"] and process["id"] not in seen
                and isinstance(process["record"], dict), "invalid process record")
        seen.add(process["id"])
    integer(coverage["totalProcesses"], len(seen), 2**53 - 1, "total processes")
    require(coverage["processesComplete"] == (len(seen) == coverage["totalProcesses"]),
            "process coverage differs")
    require(coverage["organizationAvailable"] or coverage["totalProcesses"] == 0,
            "unavailable organization owner has processes")
    return frame


def inspect_frames(path, package_path=None):
    """Stream one collection session with bounded memory and explicit coverage."""
    path = Path(path)
    package = verify_package(package_path) if package_path is not None else None
    paths = sorted(path.glob("*.json")) if path.is_dir() else [path]
    count = 0
    first_hours = None
    previous = None
    run = None
    for source in paths:
        require(source.stat().st_size <= 64 * 1024 * 1024, "oversized observation")
        frame = validate_frame(load(source))
        if package is not None:
            bind_frame(frame, package)
        identity = (frame["definitionSha256"], frame["save"], frame["map"], frame["session"],
                    seal({key: frame[key] for key in ("extent", "sandbox", "generation", "mods", "engineVersion",
                          "packageEngineJarSha256", "observerSha256")}))
        if run is None:
            run = identity
            first_hours = frame["hours"]
        require(identity == run, "different world, session or source configuration in observations")
        if previous is not None:
            require(frame["sequence"] > previous["sequence"], "duplicate or reversed observation")
            require(frame["hours"] >= previous["hours"], "world time reversed")
        count += 1
        previous = frame
    require(count, "no runtime observations")
    return {"schema": "sao-study-inspection/1", "frames": count,
            "definitionSha256": run[0], "save": run[1], "map": run[2],
            "session": run[3], "firstHours": first_hours, "lastHours": previous["hours"],
            "coverage": previous["coverage"], "population": previous["population"],
            "packageSha256": seal(package[0]) if package is not None else None,
            "datasetAdmission": "unreviewed", "behavioralVerdict": None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("validate")
    check.add_argument("definition", type=Path)
    package = sub.add_parser("build")
    package.add_argument("definition", type=Path)
    package.add_argument("--out", required=True, type=Path)
    package.add_argument("--game", required=True, type=Path)
    inspect = sub.add_parser("inspect")
    inspect.add_argument("observations", type=Path)
    inspect.add_argument("--package", type=Path, help="bind observations to this exact package")
    args = parser.parse_args()
    if args.command == "validate":
        value = validate(load(args.definition))
        result = {"definitionSha256": seal(value), "extent": value["extent"],
                  "status": "valid-definition", "datasetAdmission": "unreviewed"}
    elif args.command == "build":
        result = build(load(args.definition), args.out, args.game)
    else:
        result = inspect_frames(args.observations, args.package)
    print(json.dumps(result, indent=2, allow_nan=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print(f"world_lab: {error}", file=sys.stderr)
        sys.exit(1)
