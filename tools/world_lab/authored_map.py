"""Strict, local-only packaging of installed PZ 256-square authored map cells.

No installed asset is a repository artifact. Native source files are read from
the selected installation and copied only into the caller's isolated package.
"""
from __future__ import annotations

import hashlib
import math
from pathlib import Path
import re
import struct

CELL = 256
MAX_CELLS = 64
MAX_FILE = 64 * 1024 * 1024


def require(condition, message):
    if not condition:
        raise ValueError("authored map: " + message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


class Literal:
    """Accept table literals, never execute source Lua or its expressions."""
    number = r"-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
    token = re.compile(r'''\s+|--\[\[.*?\]\]|--[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[A-Za-z_][A-Za-z_0-9]*|''' + number + r'|[{}\[\]=,;().:]', re.S)

    def __init__(self, source):
        require(len(source) <= 16 * 1024 * 1024, "oversized Lua metadata")
        self.tokens = []
        end = 0
        for match in self.token.finditer(source):
            require(not source[end:match.start()].strip(), "unsupported Lua metadata syntax")
            token = match.group()
            if not token.isspace() and not token.startswith("--"):
                self.tokens.append(token)
            end = match.end()
        require(not source[end:].strip(), "unsupported trailing Lua metadata syntax")
        require(len(self.tokens) <= 2000000, "excessive metadata tokens")
        self.at = 0

    def take(self, expected=None):
        require(self.at < len(self.tokens), "truncated Lua metadata")
        value = self.tokens[self.at]
        self.at += 1
        require(expected is None or value == expected, "unexpected Lua metadata token: " + value)
        return value

    def peek(self):
        return self.tokens[self.at] if self.at < len(self.tokens) else None

    def value(self, depth=0):
        require(depth <= 16, "deeply nested Lua metadata")
        token = self.take()
        if token == "{":
            array, mapping = [], {}
            while self.peek() != "}":
                if self.peek() == "[":
                    self.take("[")
                    key = self.value(depth + 1)
                    self.take("]")
                    self.take("=")
                elif self.at + 1 < len(self.tokens) and self.tokens[self.at + 1] == "=":
                    key = self.take()
                    require(re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", key), "invalid metadata key")
                    self.take("=")
                else:
                    array.append(self.value(depth + 1))
                    key = None
                if key is not None:
                    require(isinstance(key, str) and key not in mapping, "duplicate/non-string metadata key")
                    mapping[key] = self.value(depth + 1)
                if self.peek() in (",", ";"):
                    self.take()
                else:
                    require(self.peek() == "}", "missing metadata separator")
            self.take("}")
            require(not array or not mapping, "mixed metadata table")
            return mapping if mapping else array
        if token.startswith(('"', "'")):
            body = token[1:-1]
            escapes = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'"}
            def escape(match):
                text = match.group()[1:]
                if text.isdigit():
                    require(int(text) <= 255, "invalid Lua decimal escape")
                    return chr(int(text))
                require(text in escapes, "unsupported Lua string escape")
                return escapes[text]
            return re.sub(r"\\(?:[0-9]{1,3}|.)", escape, body)
        if token in ("true", "false"):
            return token == "true"
        require(re.fullmatch(self.number, token), "executable/unknown Lua metadata value: " + token)
        value = float(token) if any(c in token for c in ".eE") else int(token)
        require(math.isfinite(value), "non-finite Lua metadata")
        return value

    def assignment(self, name, local=False):
        if local:
            self.take("local")
        self.take(name)
        self.take("=")
        return self.value()

    def done(self):
        require(self.at == len(self.tokens), "unexpected executable metadata suffix")


def metadata_table(blob, name):
    parser = Literal(blob.decode("utf-8-sig"))
    rows = parser.assignment(name)
    parser.done()
    require(isinstance(rows, list), "metadata root must be an ordered array")
    return rows


def numeric(value, label):
    require(type(value) in (int, float) and math.isfinite(value)
            and abs(value) <= 1000000, "invalid " + label)
    return value


def zone_bounds(row):
    require(isinstance(row, dict) and isinstance(row.get("name"), str)
            and isinstance(row.get("type"), str), "malformed native zone")
    properties = row.get("properties", {})
    require(isinstance(properties, dict) or properties == [], "invalid native zone properties")
    properties = properties or {}
    z = numeric(row.get("z"), "zone floor")
    require(type(z) is int and -32 <= z <= 31, "invalid native zone floor")
    geometry = row.get("geometry")
    if geometry:
        require(geometry in ("point", "polygon", "polyline"), "unsupported zone geometry")
        points = row.get("points")
        require(isinstance(points, list) and 2 <= len(points) <= 32768
                and len(points) % 2 == 0, "invalid zone points")
        points = [numeric(p, "zone point") for p in points]
        require(geometry != "polygon" or len(points) >= 6, "short zone polygon")
        require(geometry != "polyline" or len(points) >= 4, "short zone polyline")
        width = numeric(row.get("lineWidth", properties.get("LineWidth", 0)), "line width")
        require(width >= 0, "negative zone line width")
        # Conservatively include the stroke. No shape or coordinates are clipped.
        margin = math.ceil(width) if geometry == "polyline" else 0
        return (math.floor(min(points[::2])) - margin, math.floor(min(points[1::2])) - margin,
                math.ceil(max(points[::2])) + margin + 1, math.ceil(max(points[1::2])) + margin + 1)
    x, y = numeric(row.get("x"), "zone x"), numeric(row.get("y"), "zone y")
    width, height = numeric(row.get("width"), "zone width"), numeric(row.get("height"), "zone height")
    require(width >= 0 and height >= 0, "negative native zone size")
    return x, y, x + width, y + height


def intersects(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]


def contains(outer, inner):
    return outer[0] <= inner[0] and outer[1] <= inner[1] and outer[2] >= inner[2] and outer[3] >= inner[3]


def extent_bounds(extent):
    x, y = extent["minCellX"], extent["minCellY"]
    return x * CELL, y * CELL, (x + extent["cellsX"]) * CELL, (y + extent["cellsY"]) * CELL


class Binary:
    def __init__(self, blob, label):
        require(0 < len(blob) <= MAX_FILE, "empty/oversized " + label)
        self.blob, self.at, self.label = blob, 0, label

    def take(self, size):
        require(0 <= size <= len(self.blob) - self.at, "truncated " + self.label)
        data = self.blob[self.at:self.at + size]
        self.at += size
        return data

    def integer(self):
        return struct.unpack("<i", self.take(4))[0]

    def count(self, limit=100000):
        value = self.integer()
        require(0 <= value <= limit, "invalid count in " + self.label)
        return value

    def string(self):
        end = self.blob.find(b"\n", self.at)
        require(self.at <= end <= self.at + 4096, "unterminated string in " + self.label)
        return self.take(end - self.at + 1)[:-1].decode("utf-8").strip()

    def done(self):
        require(self.at == len(self.blob), "trailing bytes in " + self.label)


def header(blob, x, y):
    """LOTH version 1, cross-checked against installed POTLotHeader.load."""
    data = Binary(blob, "lotheader")
    require(data.take(4) == b"LOTH" and data.integer() == 1,
            "only native LOTH version 1 is supported")
    tiles = [data.string() for _ in range(data.count())]
    require(tiles and all(tiles), "missing tile dictionary")
    width, height, low, high = [data.integer() for _ in range(4)]
    require(width == 8 and height == 8 and -32 <= low <= high <= 31,
            "lotheader chunk dimensions/floors differ")
    rooms = []
    for _ in range(data.count()):
        name, z = data.string(), data.integer()
        # Cross-cell room metadata may outlive this cell's nonempty tile floors.
        require(-32 <= z <= 31, "room floor outside native range")
        rects = []
        for _ in range(data.count(65536)):
            rx, ry, w, h = [data.integer() for _ in range(4)]
            require(w > 0 and h > 0 and all(abs(n) <= 65536 for n in (rx, ry, w, h)),
                    "invalid room rectangle")
            rects.append([x * CELL + rx, y * CELL + ry, x * CELL + rx + w, y * CELL + ry + h])
        require(rects, "empty authored room")
        for _ in range(data.count(65536)):
            data.take(12)  # native meta-object type and room-relative x/y
        rooms.append({"name": name, "z": z, "rects": rects})
    buildings, assigned = [], set()
    for _ in range(data.count()):
        indices = [data.integer() for _ in range(data.count(65536))]
        require(indices and all(0 <= i < len(rooms) and i not in assigned for i in indices)
                and len(indices) == len(set(indices)), "invalid building room reference")
        assigned.update(indices)
        rectangles = [rect for i in indices for rect in rooms[i]["rects"]]
        buildings.append([min(r[0] for r in rectangles), min(r[1] for r in rectangles),
                          max(r[2] for r in rectangles), max(r[3] for r in rectangles)])
    data.take(32 * 32)  # preserved native zombie-density map
    data.done()
    return {"tiles": len(tiles), "minLevel": low, "maxLevel": high,
            "rooms": rooms, "buildings": buildings}


def lotpack(blob, info):
    """Validate all native 8x8 chunk streams and their tile references."""
    data = Binary(blob, "lotpack")
    require(data.take(4) == b"LOTP" and data.integer() == 1, "unsupported lotpack format")
    require(data.integer() == 1024, "lotpack must contain 1024 native chunks")
    offsets = [struct.unpack("<q", data.take(8))[0] for _ in range(1024)]
    require(offsets[0] == data.at and offsets == sorted(set(offsets))
            and offsets[-1] < len(blob), "invalid lotpack chunk offsets")
    squares = 64 * (info["maxLevel"] - info["minLevel"] + 1)
    for index, offset in enumerate(offsets):
        require(data.at == offset, "lotpack chunk overlap/gap")
        end = offsets[index + 1] if index + 1 < len(offsets) else len(blob)
        seen = 0
        while seen < squares:
            size = data.integer()
            if size == -1:
                run = data.integer()
                require(0 < run <= squares - seen, "invalid lotpack empty run")
                seen += run
            else:
                require(0 <= size <= 4096, "invalid lotpack tile stack")
                seen += 1
                if size > 1:
                    data.integer()  # native room number, not a tile index
                    for _ in range(size - 1):
                        require(0 <= data.integer() < info["tiles"], "invalid lotpack tile index")
            require(data.at <= end, "lotpack chunk stream exceeds next offset")
        require(data.at == end, "trailing lotpack chunk data")
    data.done()


def chunkdata(blob):
    data = Binary(blob, "chunkdata")
    require(data.take(2) == b"\x00\x01", "unsupported chunkdata version")
    for _ in range(1024):
        kind = data.take(1)[0]
        require(kind <= 4, "invalid native chunk kind")
        if kind == 2:
            require(all(v < 32 for v in data.take(64)), "invalid native square bits")
    data.done()


def safe_read(root, relative):
    require(isinstance(relative, str) and "\\" not in relative
            and not Path(relative).is_absolute() and all(p not in ("", ".", "..") for p in relative.split("/")),
            "unsafe source path")
    root = Path(root).resolve()
    path = root / relative
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root),
            "missing/escaped native source: " + relative)
    require(0 < path.stat().st_size <= MAX_FILE, "empty/oversized native source: " + relative)
    return path.read_bytes()


def source_name(name):
    require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 ,_()'-]{0,95}", name)
            and name == name.strip(), "sourceMap must name one installed media/maps directory")


def cell_names(extent):
    require(extent["cellsX"] * extent["cellsY"] <= MAX_CELLS,
            "authored extent exceeds 64-cell packaging budget")
    for x in range(extent["minCellX"], extent["minCellX"] + extent["cellsX"]):
        for y in range(extent["minCellY"], extent["minCellY"] + extent["cellsY"]):
            yield x, y, (f"{x}_{y}.lotheader", f"world_{x}_{y}.lotpack", f"chunkdata_{x}_{y}.bin")


def map_info(blob):
    values = {}
    for line in blob.decode("utf-8-sig").splitlines():
        if not line.strip():
            continue
        require("=" in line, "malformed source map.info")
        key, value = line.split("=", 1)
        require(key not in values, "duplicate source map.info key")
        values[key] = value.strip()
    require(values.get("fixed2x") == "true", "authored source requires fixed2x=true")
    require(values.get("lots", "NONE") == "NONE", "source map has a lots dependency; select the actual cell-bearing map")
    require("Cell size is 256x256" in values.get("description", ""), "source map is not declared 256-square native format")
    return values


def binary_building(blob):
    """Validate the native PZBY header, attributes and all tile-stack streams."""
    data = Binary(blob, "basement PZBY")
    require(data.take(4) == b"PZBY" and data.integer() == 0, "unsupported PZBY format")
    tiles = [data.string() for _ in range(data.count())]
    width, height, levels = [data.integer() for _ in range(3)]
    require(1 <= width <= 64 and 1 <= height <= 64 and 1 <= levels <= 32, "invalid PZBY dimensions")
    rooms = data.count()
    for _ in range(rooms):
        data.string()
        require(0 <= data.integer() < levels, "invalid PZBY room floor")
        for _ in range(data.count(65536)):
            x, y, w, h = [data.integer() for _ in range(4)]
            require(0 <= x < width * 8 and 0 <= y < height * 8 and w > 0 and h > 0
                    and x + w <= width * 8 and y + h <= height * 8, "PZBY room leaves asset")
        data.take(data.count(65536) * 12)
    for _ in range(data.count()):
        for _ in range(data.count()):
            require(0 <= data.integer() < rooms, "invalid PZBY building room reference")
    offsets = [struct.unpack("<q", data.take(8))[0] for _ in range(width * height)]
    require(offsets[0] == data.at and offsets == sorted(set(offsets)) and offsets[-1] < len(blob),
            "invalid PZBY chunk offsets")
    for index, offset in enumerate(offsets):
        require(data.at == offset, "PZBY chunk overlap/gap")
        end = offsets[index + 1] if index + 1 < len(offsets) else len(blob)
        for attributes in (True, False):
            seen, squares = 0, levels * 64
            while seen < squares:
                size = data.integer()
                if size == -1:
                    run = data.integer()
                    require(0 < run <= squares - seen, "invalid PZBY empty run")
                    seen += run
                else:
                    require(0 <= size <= 4096, "invalid PZBY tile stack")
                    seen += 1
                    if size > 1:
                        if attributes:
                            data.integer()
                        else:
                            for _ in range(size - 1):
                                require(0 <= data.integer() < len(tiles), "invalid PZBY tile index")
                require(data.at <= end, "PZBY stream exceeds next offset")
        require(data.at == end, "trailing PZBY chunk data")
    data.done()
    return {"widthChunks": width, "heightChunks": height, "levels": levels}


def basements(blob, original_name):
    parser = Literal(blob.decode("utf-8-sig"))
    definitions = parser.assignment("procedural_basements", local=True)
    locations = parser.assignment("procedural_basement_spawn_locations", local=True)
    access = parser.assignment("procedural_basement_access", local=True)
    expected = ["local", "api", "=", "Basements", ".", "getAPIv1", "(", ")"]
    for token in expected:
        parser.take(token)
    for method, table in (("addAccessDefinitions", "procedural_basement_access"),
                          ("addBasementDefinitions", "procedural_basements"),
                          ("addSpawnLocations", "procedural_basement_spawn_locations")):
        for token in ("api", ":", method, "("):
            parser.take(token)
        require(parser.value() == original_name, "basement registration names another map")
        for token in (",", table, ")"):
            parser.take(token)
    parser.done()
    require(isinstance(definitions, dict) and isinstance(access, dict) and isinstance(locations, list),
            "invalid basement definition tables")
    for table in (definitions, access):
        require(len(table) <= 1024, "excessive basement definitions")
        for name, row in table.items():
            require(re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{0,95}", name)
                    and isinstance(row, dict) and set(row) == {"width", "height", "stairx", "stairy", "stairDir"},
                    "unsupported basement definition/path")
            require(all(type(row[k]) is int and -256 <= row[k] <= 512
                        for k in ("width", "height", "stairx", "stairy"))
                    and row["width"] > 0 and row["height"] > 0 and row["stairDir"] in ("N", "W", ""),
                    "invalid basement definition dimensions")
    return definitions, locations, access


# The installed metazoneHandler explicitly does not register these objects.
# Their terrain semantics reside in the unchanged native chunk/tile data.
UNREGISTERED_OBJECTS = {"Vegitation", "DeepForest", "Forest", "TownZone", "Farm", "FarmLand", "TrailerPark", "RoomTone"}


def selected_metadata(blob, variable, bounds, filename):
    rows = metadata_table(blob, variable)
    selected = []
    admission = (bounds[0] - 100, bounds[1] - 100, bounds[2] + 100, bounds[3] + 100)
    for row in rows:
        region = zone_bounds(row)
        if not intersects(bounds, region):
            continue
        if filename != "objects.lua" or row["type"] not in UNREGISTERED_OBJECTS:
            require(contains(admission, region) and region[2] - region[0] <= 1202
                    and region[3] - region[1] <= 1202,
                    f"extent would lose native zone {filename}:{row['type']}:{row['name']} at {region}; select a complete region")
            if row["type"] == "Basement":
                require(contains(bounds, region), "extent cuts a basement placement")
        selected.append(row)
    return selected, len(rows)


def check_source_override(blob, bounds):
    """Do not silently omit an authored map's procedural border dependency."""
    parser = Literal(blob.decode("utf-8-sig"))
    for token in ("worldgen", "["):
        parser.take(token)
    require(parser.value() == "static_modules", "unsupported native source override")
    for token in ("]", "=", "{"):
        parser.take(token)
    while parser.peek() != "}":
        for token in ("{", "position", "="):
            parser.take(token)
        position = parser.value()
        require(isinstance(position, dict) and position and set(position) <= {"xmin", "xmax", "ymin", "ymax"},
                "unsupported source override rectangle")
        region = [position.get("xmin", -1000000), position.get("ymin", -1000000),
                  position.get("xmax", 1000000) + 1, position.get("ymax", 1000000) + 1]
        require(all(type(n) is int and abs(n) <= 1000001 for n in region)
                and region[0] < region[2] and region[1] < region[3], "invalid source override bounds")
        require(not intersects(bounds, region), "extent intersects a source WorldGenOverride; native override composition is unsupported")
        parser.take(",")
        kind = parser.take()
        require(kind in ("biome", "prefab"), "unsupported source override module")
        for token in ("=", "worldgen", ".", "biomes" if kind == "biome" else "prefabs", "."):
            parser.take(token)
        require(re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", parser.take()), "invalid source override module name")
        if parser.peek() == ",":
            parser.take()
        parser.take("}")
        if parser.peek() == ",":
            parser.take()
        else:
            require(parser.peek() == "}", "missing source override separator")
    parser.take("}")
    parser.done()


def prepare(game, definition, map_name, lua, canonical):
    """Return exact package-relative bytes and a source provenance receipt."""
    source_name(definition["sourceMap"])
    game = Path(game).resolve()
    directory = "media/maps/" + definition["sourceMap"]
    source = game / directory
    require(source.is_dir() and not source.is_symlink() and source.resolve().is_relative_to(game / "media/maps"),
            "missing/escaped installed sourceMap")
    bounds = extent_bounds(definition["extent"])
    cells = list(cell_names(definition["extent"]))
    files, inputs = {}, {}
    map_prefix = "media/maps/" + map_name + "/"

    def read(relative):
        blob = safe_read(game, relative)
        inputs[relative] = {"sha256": digest(blob), "bytes": len(blob)}
        if relative.startswith(directory + "/") and relative.rsplit("/", 1)[1] in (
                "map.info", "objects.lua", "regions.lua", "roomtones.lua", "spawnOrigins.lua", "basements.lua", "WorldGenOverride.lua"):
            # Original metadata remains inert, outside every native media loader,
            # so offline verification can reproduce each selected table exactly.
            files["_source_map/" + relative.rsplit("/", 1)[1]] = blob
        return blob

    map_info(read(directory + "/map.info"))
    if (source / "WorldGenOverride.lua").exists():
        check_source_override(read(directory + "/WorldGenOverride.lua"), bounds)
    # Inspect the whole header catalog, including buildings rooted outside the
    # requested cells. Otherwise an overlapping outside building can disappear.
    catalog = sorted(source.glob("*.lotheader"))
    require(1 <= len(catalog) <= 10000, "invalid source header catalog")
    selected_names = {names[0] for _, _, names in cells}
    summaries, catalog_seals = {}, {}
    for path in catalog:
        match = re.fullmatch(r"(-?\d+)_(-?\d+)\.lotheader", path.name)
        require(match is not None, "invalid native header filename")
        x, y = map(int, match.groups())
        blob = safe_read(source, path.name)
        info = header(blob, x, y)
        catalog_seals[path.name] = digest(blob)
        for building in info["buildings"]:
            if intersects(bounds, building):
                require(path.name in selected_names and contains(bounds, building),
                        f"extent cuts building rooted in {path.name} at {building}")
        if path.name in selected_names:
            require(all(contains(bounds, rect) for room in info["rooms"] for rect in room["rects"]),
                    "extent cuts an authored room")
            summaries[path.name] = info
    require(set(summaries) == selected_names, "missing selected native cell header")
    cell_receipts = []
    for x, y, names in cells:
        info = summaries[names[0]]
        blobs = [read(directory + "/" + name) for name in names]
        require(digest(blobs[0]) == catalog_seals[names[0]], "source header changed while packaging")
        lotpack(blobs[1], info)
        chunkdata(blobs[2])
        for name, blob in zip(names, blobs):
            files[map_prefix + name] = blob
        cell_receipts.append({"x": x, "y": y, "rooms": len(info["rooms"]),
                              "buildings": len(info["buildings"]),
                              "roomNames": sorted({room["name"] for room in info["rooms"]})})
    metadata = {}
    zones = []
    for filename, variable in (("objects.lua", "objects"), ("regions.lua", "regions"),
                               ("roomtones.lua", "objects"), ("spawnOrigins.lua", "objects")):
        path = source / filename
        # Require explicit empty tables when there are no zones/regions/tones;
        # a missing companion must not silently erase survival context.
        if filename == "spawnOrigins.lua" and not path.exists():
            continue
        blob = read(directory + "/" + filename)
        selected, total = selected_metadata(blob, variable, bounds, filename)
        files[map_prefix + filename] = (variable + " = " + lua(selected) + "\n").encode("utf-8")
        metadata[filename] = {"sourceRows": total, "selectedRows": len(selected), "rowsSha256": digest(canonical(selected))}
        zones.extend(selected)
    has_basements = any(row["type"] == "Basement" for row in zones)
    if (source / "basements.lua").exists():
        definitions, locations, access = basements(read(directory + "/basements.lua"), definition["sourceMap"])
        # Native explicit placements require more than x/y clipping (stair offsets
        # and rotated footprints). Refuse this unimplemented format explicitly.
        require(not locations, "explicit basement spawn-location table is unsupported")
        for row in zones:
            if row["type"] == "Basement":
                name = row.get("properties", {}).get("Access")
                require(name is None or name in access, "unknown basement access dependency")
        for table, asset_dir in ((definitions, "binmap"), (access, "basement_access")):
            for name in table:
                relative = "media/" + asset_dir + "/" + name + ".pzby"
                blob = read(relative)
                binary_building(blob)
                files[relative] = blob
        script = ("local api = Basements.getAPIv1()\n"
                  + "api:addAccessDefinitions(" + lua(map_name) + "," + lua(access) + ")\n"
                  + "api:addBasementDefinitions(" + lua(map_name) + "," + lua(definitions) + ")\n")
        files[map_prefix + "basements.lua"] = script.encode("utf-8")
        metadata["basements.lua"] = {"definitions": len(definitions), "accessDefinitions": len(access), "explicitLocations": 0}
    else:
        require(not has_basements, "basement zones lack native definitions")
    receipt = {"schema": "sao-authored-map-source/1", "sourceMap": definition["sourceMap"],
               "extent": definition["extent"], "cells": cell_receipts, "metadata": metadata,
               "headerCatalog": {"count": len(catalog_seals), "sha256": digest(canonical(catalog_seals))},
               "inputs": inputs, "outputs": {name: digest(blob) for name, blob in sorted(files.items())}}
    return files, receipt


def verify(version, definition, map_name, receipt, lua, canonical):
    require(isinstance(receipt, dict) and set(receipt) == {"schema", "sourceMap", "extent", "cells", "metadata", "headerCatalog", "inputs", "outputs"},
            "invalid source receipt fields")
    require(receipt["schema"] == "sao-authored-map-source/1"
            and receipt["sourceMap"] == definition["sourceMap"] and receipt["extent"] == definition["extent"],
            "source receipt identity differs")
    outputs, inputs = receipt["outputs"], receipt["inputs"]
    require(isinstance(outputs, dict) and 1 <= len(outputs) <= 3072 and isinstance(inputs, dict),
            "invalid authored inventory")
    directory = "media/maps/" + definition["sourceMap"] + "/"
    prefix = "media/maps/" + map_name + "/"
    expected = set()
    source_inputs = set()
    bounds = extent_bounds(definition["extent"])

    def read(relative, original=None):
        blob = safe_read(version, relative)
        require(outputs.get(relative) == digest(blob), "authored output seal differs: " + relative)
        expected.add(relative)
        if original is not None:
            require(inputs.get(original) == {"sha256": digest(blob), "bytes": len(blob)},
                    "copied native source differs: " + original)
            source_inputs.add(original)
        return blob

    map_info(read("_source_map/map.info", directory + "map.info"))
    if "_source_map/WorldGenOverride.lua" in outputs:
        check_source_override(read("_source_map/WorldGenOverride.lua", directory + "WorldGenOverride.lua"), bounds)
    cell_receipts = []
    for x, y, names in cell_names(definition["extent"]):
        blobs = [read(prefix + name, directory + name) for name in names]
        info = header(blobs[0], x, y)
        require(all(contains(bounds, rect) for room in info["rooms"] for rect in room["rects"]),
                "sealed extent cuts an authored room")
        lotpack(blobs[1], info)
        chunkdata(blobs[2])
        cell_receipts.append({"x": x, "y": y, "rooms": len(info["rooms"]), "buildings": len(info["buildings"]),
                              "roomNames": sorted({room["name"] for room in info["rooms"]})})
    require(receipt["cells"] == cell_receipts, "authored cell receipt differs")
    zones, metadata = [], {}
    for filename, variable in (("objects.lua", "objects"), ("regions.lua", "regions"),
                               ("roomtones.lua", "objects"), ("spawnOrigins.lua", "objects")):
        raw = "_source_map/" + filename
        if filename == "spawnOrigins.lua" and raw not in outputs:
            continue
        blob = read(raw, directory + filename)
        selected, total = selected_metadata(blob, variable, bounds, filename)
        require(read(prefix + filename) == (variable + " = " + lua(selected) + "\n").encode("utf-8"),
                "native metadata selection differs: " + filename)
        metadata[filename] = {"sourceRows": total, "selectedRows": len(selected), "rowsSha256": digest(canonical(selected))}
        zones.extend(selected)
    if "_source_map/basements.lua" in outputs:
        definitions, locations, access = basements(read("_source_map/basements.lua", directory + "basements.lua"), definition["sourceMap"])
        require(not locations, "unsupported explicit basement locations")
        for row in zones:
            if row["type"] == "Basement":
                name = row.get("properties", {}).get("Access")
                require(name is None or name in access, "unknown basement access dependency")
        for table, asset_dir in ((definitions, "binmap"), (access, "basement_access")):
            for name in table:
                relative = "media/" + asset_dir + "/" + name + ".pzby"
                binary_building(read(relative, relative))
        script = ("local api = Basements.getAPIv1()\n"
                  + "api:addAccessDefinitions(" + lua(map_name) + "," + lua(access) + ")\n"
                  + "api:addBasementDefinitions(" + lua(map_name) + "," + lua(definitions) + ")\n")
        require(read(prefix + "basements.lua") == script.encode("utf-8"), "basement registration differs")
        metadata["basements.lua"] = {"definitions": len(definitions), "accessDefinitions": len(access), "explicitLocations": 0}
    else:
        require(not any(row["type"] == "Basement" for row in zones), "missing basement producer")
    require(metadata == receipt["metadata"] and expected == set(outputs) and source_inputs == set(inputs),
            "authored source/output inventory differs")
    catalog = receipt["headerCatalog"]
    require(isinstance(catalog, dict) and set(catalog) == {"count", "sha256"}
            and type(catalog["count"]) is int and len(cell_receipts) <= catalog["count"] <= 10000
            and isinstance(catalog["sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", catalog["sha256"]),
            "invalid native header catalog seal")
    return expected
