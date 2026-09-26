#!/usr/bin/env python3
"""Launch a generated study package in an exclusive native single-player cache.

The installed graphics runtime still runs. An opt-in agent automates the loading
click and suppresses window show/focus in this process. Gameplay owners are intact.
"""
from __future__ import annotations

import argparse
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import struct
import subprocess
import sys
import uuid
import zlib

import world_lab as Lab


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def publish(path, value):
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(Lab.canonical(value))
    os.replace(temporary, path)


def prepare(package, destination, game, jdk, mod_paths):
    manifest, definition = Lab.verify_package(package)
    game, jdk = Path(game).resolve(), Path(jdk).resolve()
    destination = Path(destination).resolve()
    Lab.require(not destination.exists(), "run path already exists; use a new isolated run")
    Lab.require(digest(game / "projectzomboid.jar") == manifest["engine"]["jar"]["sha256"],
                "installed engine differs from package")
    Lab.require(os.name == "nt", "native runner currently requires Windows")
    folders = [Path(p).resolve() for p in mod_paths]
    Lab.require(len(folders) == len(set(folders)), "duplicate mod folders")
    Lab.require(all(p.is_dir() for p in folders), "mod source unavailable")
    Lab.require(all(not destination.is_relative_to(p) for p in [*folders, Path(package).resolve()]),
                "run output must be outside the package and every mod source")
    destination.mkdir(parents=True, exist_ok=False)
    cache = destination / "cache"
    user = destination / "home"
    mods = cache / "mods"
    mods.mkdir(parents=True)
    (user / ".zombie_buddy").mkdir(parents=True)
    approvals, ids, inventory = [], [], {}
    for source in [*folders, Path(package).resolve() / "mod" / manifest["mapName"]]:
        versioned = sorted(source.glob("42*/mod.info"))
        Lab.require(versioned, "versioned native mod metadata unavailable: " + source.name)
        metadata = dict(line.split("=", 1) for line in versioned[-1].read_text(encoding="utf-8-sig").splitlines()
                        if "=" in line and not line.startswith("#"))
        mod_id = metadata["id"]
        Lab.require(Lab.re.fullmatch(r"[A-Za-z0-9_.-]+", mod_id) and mod_id not in ids, "invalid or duplicate mod id")
        target = mods / mod_id
        shutil.copytree(source, target)
        metadata_root = target / versioned[-1].parent.relative_to(source)
        ids.append(mod_id)
        if "javaJarFile" in metadata:
            jar = (metadata_root / metadata["javaJarFile"]).resolve()
            Lab.require(jar.is_relative_to(target) and jar.is_file(), "mod jar leaves copied source")
            approvals.append({"id": mod_id, "jar_hash": digest(jar), "decision": True})
        inventory[mod_id] = {p.relative_to(target).as_posix(): digest(p)
                             for p in sorted(target.rglob("*")) if p.is_file()}
    Lab.require("SurvivorAwareness" in ids and "ZombieBuddy" in ids, "SAO and ZombieBuddy are required")
    (user / ".zombie_buddy/mod_approvals.json").write_bytes(
        Lab.canonical({"formatVersion": 2, "mods": approvals}))
    (mods / "default.txt").write_text("VERSION = 1,\nmods\n{\n"
        + "".join("    mod = " + mod_id + ",\n" for mod_id in ids) + "}\nmaps\n{\n}\n", encoding="utf-8")
    # B42 otherwise treats a brand-new cache as a pre-B42 migration and clears
    # default.txt. These copied mods already carry native B42 version folders.
    (mods / "reset-mods-42_00.txt").write_text("Prepared with B42 study mods.\n", encoding="utf-8")
    (cache / "options.ini").write_text("version=8\nwidth=960\nheight=540\nfullScreen=false\n"
        "borderless=false\nlanguage=EN\ntermsOfServiceVersion=1\nsoundVolume=0\nmusicVolume=0\n"
        "ambientVolume=0\nvehicleEngineVolume=0\nvsync=false\nuncappedFPS=false\n"
        "showSurvivalGuide=false\n", encoding="utf-8")
    classes = destination / "classes"
    classes.mkdir()
    subprocess.run([str(jdk / "javac.exe"), "-cp", os.pathsep.join(str(game / n)
                    for n in ("ZombieBuddy.jar", "projectzomboid.jar")), "-d", str(classes),
                    *(str(Lab.ROOT / ("tools/world_lab/" + name)) for name in
                      ("StudyLoadingAgent.java", "StudyObserver.java", "StudyViewCapture.java"))], check=True)
    agent_manifest = destination / "agent.mf"
    agent_manifest.write_text("Manifest-Version: 1.0\nPremain-Class: StudyLoadingAgent\nCan-Retransform-Classes: true\n\n", encoding="utf-8")
    agent = destination / "StudyLoadingAgent.jar"
    subprocess.run([str(jdk / "jar.exe"), "cfm", str(agent), str(agent_manifest), "-C", str(classes), "."], check=True)
    receipt = {"schema": "sao-study-run/1", "packageSha256": Lab.seal(manifest),
               "definitionSha256": manifest["definitionSha256"], "mapName": manifest["mapName"],
               "engineJarSha256": digest(game / "projectzomboid.jar"),
               "loadingAgentSha256": digest(agent), "mods": inventory,
               "datasetAdmission": "unreviewed", "status": "prepared"}
    publish(destination / "run.json", receipt)
    return cache, user, agent, manifest, definition


def terminal(log, attempt, save, hours, watch=False):
    """Native start/horizon/return must occur once and in this order."""
    prefix = r"\[StudyLaunch\] "
    starts = list(Lab.re.finditer(prefix + r"started attempt=(\d+) save=(\S+) hours=([\d.eE+-]+)", log))
    ends = list(Lab.re.finditer(prefix + r"horizon attempt=(\d+) save=(\S+) start=([\d.eE+-]+) end=([\d.eE+-]+)", log))
    returned = list(Lab.re.finditer(prefix + r"native-save-returned attempt=(\d+)", log))
    if watch:
        stops = list(Lab.re.finditer(r"\[StudyObserver\] stop hours=([\d.eE+-]+)", log))
        Lab.require(len(starts) == len(stops) == len(returned) == 1 and not ends,
                    "native observer stop receipt missing or duplicated")
        start, stop, saved = starts[0], stops[0], returned[0]
        first, last = float(start[3]), float(stop[1])
        Lab.require(int(start[1]) == int(saved[1]) == attempt and start[2] == save
                    and start.start() < stop.start() < saved.start(), "native stop identity or order differs")
        Lab.number(last, first, 1e9, "terminal hours")
        return {"startHours": first, "endHours": last, "nativeSaveReturned": True}
    Lab.require(len(starts) == len(ends) == len(returned) == 1, "native terminal receipt missing or duplicated")
    start, end, saved = starts[0], ends[0], returned[0]
    Lab.require(int(start[1]) == int(end[1]) == int(saved[1]) == attempt
                and start[2] == end[2] == save and start.start() < end.start() < saved.start(),
                "native terminal identity or order differs")
    first, last = float(start[3]), float(end[4])
    Lab.number(first, 0, 1e9, "start hours")
    Lab.number(last, first, 1e9, "terminal hours")
    Lab.require(float(end[3]) == first and last - first >= hours - 1e-9, "requested horizon was not reached")
    return {"startHours": first, "endHours": last, "nativeSaveReturned": True}


def runtime_errors(log, errors):
    found = [line.strip() for line in errors.splitlines()
             if "Lua fail." in line or "Exception" in line or "[Byte Buddy] ERROR" in line]
    found += [line.strip() for line in log.splitlines()
              if "ExceptionLogger" in line or "[StudyWorld] stopped" in line or "[StudyObserver] FAILED" in line]
    return found


def saved_state(cache, receipt, definition):
    root = cache / "Saves/Sandbox" / receipt["save"]
    Lab.require(root.resolve().parent == (cache / "Saves/Sandbox").resolve(), "unsafe native save")
    for name in ("map.bin", "map_t.bin", "map_ver.bin", "map_worldgen.bin", "map_sand.bin",
                 "map_meta.bin", "map_zone.bin", "global_mod_data.bin", "WorldDictionary.bin", "mods.txt"):
        Lab.require((root / name).is_file() and (root / name).stat().st_size > 0, "native save missing " + name)
    Lab.require(any((root / "map").rglob("*.bin")), "native save has no loaded chunks")
    mods = Lab.re.findall(r"^\s*mod\s*=\s*([^,\s]+)\s*,", (root / "mods.txt").read_text(), Lab.re.M)
    Lab.require(len(mods) == len(set(mods)) and set(mods) == set(receipt["mods"]), "saved mods differ from run")
    map_bytes = (root / "map_ver.bin").read_bytes()
    Lab.require(len(map_bytes) >= 8, "truncated map header")
    version, count = struct.unpack_from(">ii", map_bytes)
    Lab.require(version == 249 and 0 < count <= 65536 and len(map_bytes) == 8 + 2 * count,
                "saved map header differs")
    Lab.require(map_bytes[8:].decode("utf-16-be") == receipt["mapName"], "saved map differs")
    worldgen = (root / "map_worldgen.bin").read_bytes()
    Lab.require(len(worldgen) >= 10, "truncated worldgen header")
    magic, version, count = struct.unpack_from(">4sih", worldgen)
    Lab.require(magic == b"WGEN" and version == 249 and 0 < count <= 512 and len(worldgen) == 26 + count,
                "saved worldgen header differs")
    Lab.require(worldgen[10:10+count].decode("utf-8") == definition["seed"], "saved seed differs")
    extent = definition["extent"]
    Lab.require(struct.unpack_from(">iiii", worldgen, 10 + count) == (
        extent["minCellX"], extent["minCellY"], extent["minCellX"] + extent["cellsX"] - 1,
        extent["minCellY"] + extent["cellsY"] - 1), "saved bounds differ")
    if receipt.get("host") == "observer" and not (root / "players.db").exists():
        return {"count": 0, "observerPersisted": False}
    with closing(sqlite3.connect((root / "players.db").as_uri() + "?mode=ro", uri=True)) as database:
        Lab.require(database.execute("PRAGMA quick_check").fetchone() == ("ok",), "native player store damaged")
        if receipt.get("host") == "observer":
            count = database.execute("SELECT count(*) FROM localPlayers").fetchone()[0]
            Lab.require(count == 0, "observer host persisted a participating player")
            return {"count": count, "observerPersisted": False}
        player = database.execute("SELECT isDead,length(data) FROM localPlayers WHERE id=1").fetchone()
        Lab.require(player is not None and player[1] > 0, "native player store is empty")
        return {"id": 1, "alive": player[0] == 0}


def verify_inputs(cache, agent, receipt):
    Lab.require(digest(agent) == receipt["loadingAgentSha256"], "loading adapter changed")
    mods_root = cache / "mods"
    Lab.require({p.name for p in mods_root.iterdir() if p.is_dir()} == set(receipt["mods"]),
                "copied mod directories changed")
    for mod_id, files in receipt["mods"].items():
        root = (mods_root / mod_id).resolve()
        Lab.require(root.parent == mods_root.resolve(), "unsafe mod id")
        expected = dict(files)
        if mod_id == receipt["mapName"]:
            expected["42.20/media/lua/client/ZZStudyLaunch.lua"] = receipt["launchSha256"]
        Lab.require({p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()} == set(expected),
                    "copied mod inventory changed")
        for relative, content_hash in expected.items():
            source = (root / relative).resolve()
            Lab.require(source.is_relative_to(root) and digest(source) == content_hash, "copied mod content changed")


def verify_native_images(cache, receipt):
    image = cache / "Screenshots" / f"study-attempt-{receipt['launchNumber']:04d}.png"
    actual = {image.relative_to(cache).as_posix(): digest(image)} if image.is_file() else {}
    Lab.require(actual == receipt["nativeImages"], "native image inventory or content differs")


def native_png(data):
    """Validate complete native RGBA/RGB PNG chunks and bounded pixel data."""
    Lab.require(57 <= len(data) <= 16 * 1024 * 1024 and data[:8] == b"\x89PNG\r\n\x1a\n", "invalid native PNG")
    offset, chunks, compressed = 8, [], bytearray()
    width = height = channels = 0
    while offset < len(data):
        Lab.require(offset + 12 <= len(data), "truncated native PNG chunk")
        size = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset+4:offset+8]
        end = offset + 12 + size
        Lab.require(end <= len(data), "truncated native PNG data")
        payload = data[offset+8:end-4]
        Lab.require(zlib.crc32(kind + payload) == struct.unpack_from(">I", data, end-4)[0], "native PNG CRC differs")
        if not chunks:
            Lab.require(kind == b"IHDR" and size == 13, "native PNG header missing")
            width, height, depth, colour, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            Lab.require(0 < width <= 4096 and 0 < height <= 2160 and depth == 8 and colour in (2, 6)
                        and compression == filtering == interlace == 0, "unsupported native PNG layout")
            channels = 4 if colour == 6 else 3
        elif kind == b"IDAT":
            Lab.require(chunks[-1] in (b"IHDR", b"IDAT") or b"IDAT" not in chunks, "noncontiguous native PNG data")
            compressed.extend(payload)
        elif kind == b"IEND":
            Lab.require(size == 0 and end == len(data), "native PNG end differs")
        else:
            Lab.require(kind[0] & 32, "unknown native PNG critical chunk")
        chunks.append(kind)
        offset = end
    Lab.require(chunks[-1] == b"IEND" and compressed, "incomplete native PNG")
    expected = height * (width * channels + 1)
    decoder = zlib.decompressobj()
    try:
        pixels = decoder.decompress(compressed, expected + 1)
    except zlib.error as error:
        raise ValueError("invalid native PNG pixels") from error
    Lab.require(len(pixels) == expected and decoder.eof and not decoder.unused_data
                and not decoder.unconsumed_tail, "incomplete or excessive native PNG pixels")
    Lab.require(all(pixels[row * (width * channels + 1)] <= 4 for row in range(height)), "invalid native PNG filter")
    return width, height


def observer_evidence(destination, receipt=None):
    relative = (receipt or {}).get("observerDirectory", "")
    Lab.require(relative == "" or Lab.re.fullmatch(r"attempts/\d{4}", relative), "unsafe observer attempt directory")
    root = destination / relative
    state_path = root / "observer-state.json"
    view_path = root / "native-view/native.json"
    state, view = Lab.load(state_path), Lab.load(view_path)
    Lab.require(state["schema"] == "sao-study-observer/1" and state["detached"] is True
                and state.get("failure") is None and state.get("status", "active") in ("active", "stopping")
                and state["worldAdvanced"] is True and state["hours"] > state["startHours"]
                and state["nativeAlive"] is False and state["ghost"] is True
                and state["zombiesDontAttack"] is True and state["collidable"] is False
                and state["playerSqlId"] == -1 and state["suppressedBirths"] >= 1
                and state["suppressedSaves"] >= 1 and state["logicCalls"] > 0
                and all(state[k] == 0 for k in ("objects", "additions", "removals", "squareMemberships")),
                "native observer participation or advancement evidence failed")
    Lab.require(view["schema"] == "sao-native-viewport/1", "native viewport schema differs")
    Lab.integer(view["sequence"], 1, 2**53-1, "native viewport sequence")
    Lab.integer(view["capturedAtUnixMs"], 1, 2**53-1, "native viewport time")
    image = view["image"]
    Lab.require(Lab.re.fullmatch(r"study-live-\d{16}\.png", image["file"]), "unsafe native image name")
    image_path = root / "native-view" / image["file"]
    Lab.require(not image_path.is_symlink() and image_path.resolve().parent == view_path.parent.resolve()
                and 24 <= image_path.stat().st_size <= 16 * 1024 * 1024, "native image file invalid")
    data = image_path.read_bytes()
    Lab.require(data[:8] == b"\x89PNG\r\n\x1a\n" and digest(image_path) == image["sha256"],
                "native viewport image differs")
    width, height = native_png(data)
    Lab.require(0 < width <= 4096 and 0 < height <= 2160
                and (width, height) == (image["width"], image["height"]), "native viewport dimensions differ")
    return {"files": {p.relative_to(destination).as_posix(): digest(p)
                      for p in (state_path, view_path, image_path)}, "state": state, "viewport": view}


def verify_run(destination, package):
    destination = Path(destination).resolve()
    manifest, definition = Lab.verify_package(package)
    receipt = Lab.load(destination / "run.json")
    Lab.require(receipt["schema"] == "sao-study-run/1" and receipt["status"] == "completed"
                and receipt["datasetAdmission"] == "unreviewed" and receipt["exitCode"] == 0 and not receipt["runtimeErrors"]
                and receipt["packageSha256"] == Lab.seal(manifest), "completed package-bound run required")
    cache = destination / "cache"
    verify_inputs(cache, destination / "StudyLoadingAgent.jar", receipt)
    verify_native_images(cache, receipt)
    if receipt.get("host") == "observer":
        Lab.require(observer_evidence(destination, receipt) == receipt.get("observerEvidence"),
                    "sealed observer evidence differs")
    for section, boundary in (("saveFiles", cache / "Saves"), ("observations", cache / "Lua/StudyWorld")):
        Lab.require(receipt[section], "empty run inventory")
        for relative, expected in receipt[section].items():
            path = (cache / relative).resolve()
            Lab.require(path.is_relative_to(boundary) and path.is_file() and digest(path) == expected,
                        "run artifact differs: " + relative)
    Lab.require({p.relative_to(cache).as_posix() for p in (cache / "Saves").rglob("*") if p.is_file()}
                == set(receipt["saveFiles"]), "save inventory differs")
    Lab.require(saved_state(cache, receipt, definition) == receipt["player"], "player state report differs")
    attempt = destination / "attempts" / f"{receipt['launchNumber']:04d}"
    Lab.require(Lab.load(attempt / "report.json") == receipt, "closed run report differs")
    Lab.require(set(receipt["logs"]) == {"stdout.log", "stderr.log"}, "log inventory differs")
    for name, expected in receipt["logs"].items():
        Lab.require(name in ("stdout.log", "stderr.log") and digest(attempt / name) == expected, "run log differs")
    checked = terminal((attempt / "stdout.log").read_text(encoding="utf-8", errors="replace"),
                       receipt["launchNumber"], receipt["save"], receipt["hours"], receipt.get("watch", False))
    Lab.require(checked == receipt["terminal"], "terminal report differs")
    Lab.require(not runtime_errors(*( (attempt / name).read_text(encoding="utf-8", errors="replace")
                                     for name in ("stdout.log", "stderr.log"))), "runtime error in closed logs")
    observations = sorted(cache / p for p in receipt["observations"])
    Lab.require(len({p.parent for p in observations}) == 1, "multiple observation sessions")
    Lab.require(set(observations[0].parent.glob("*.json")) == set(observations), "observation inventory differs")
    inspection = Lab.inspect_frames(observations[0].parent, package)
    Lab.require(inspection == receipt["inspection"], "run inspection differs")
    last = Lab.load(observations[-1])
    Lab.require(receipt["observationFiles"] == len(observations) and receipt["lastSequence"] == last["sequence"]
                and receipt["lastHours"] == last["hours"] and receipt["save"] == last["save"],
                "observation report differs")
    Lab.require(checked["endHours"] - last["hours"] <= definition["observation"]["everyHours"] + 1e-6,
                "observation stopped before horizon")
    for path in observations:
        frame = Lab.load(path)
        Lab.require(set(frame["mods"]) == set(receipt["mods"]), "activated mods differ from copied mods")
        Lab.require(checked["startHours"] <= frame["hours"] <= checked["endHours"], "frame outside native run")
    return receipt


def run(args):
    destination, game = Path(args.out).resolve(), Path(args.game).resolve()
    previous = None
    if args.resume:
        Lab.require(not args.mod, "resume uses the original copied mods")
        manifest, definition = Lab.verify_package(args.package)
        previous = verify_run(destination, args.package)
        Lab.require(previous.get("host", "player") == args.host, "resume must retain the native host kind")
        if args.host == "observer":
            Lab.require(not args.replace_dead_player and previous["player"].get("count") == 0,
                        "observer continuation requires a playerless store")
        else:
            Lab.require(previous["player"]["alive"] or args.replace_dead_player,
                        "saved player is dead; use --replace-dead-player for native character creation")
            Lab.require(not (previous["player"]["alive"] and args.replace_dead_player), "living player cannot be replaced")
        Lab.require(previous["schema"] == "sao-study-run/1" and previous["status"] == "completed"
                    and previous["packageSha256"] == Lab.seal(manifest), "resume requires this completed study")
        Lab.require(digest(game / "projectzomboid.jar") == previous["engineJarSha256"], "resume engine changed")
        cache, user, agent = destination / "cache", destination / "home", destination / "StudyLoadingAgent.jar"
        Lab.require(digest(agent) == previous["loadingAgentSha256"], "resume loading adapter changed")
        for mod_id, files in previous["mods"].items():
            mod_root = cache / "mods" / mod_id
            expected = set(files)
            if mod_id == manifest["mapName"]:
                expected.add("42.20/media/lua/client/ZZStudyLaunch.lua")
            Lab.require({p.relative_to(mod_root).as_posix() for p in mod_root.rglob("*") if p.is_file()}
                        == expected, "copied mod inventory changed before resume")
            for relative, content_hash in files.items():
                source = cache / "mods" / mod_id / relative
                Lab.require(source.resolve().is_relative_to(cache / "mods") and digest(source) == content_hash,
                            "copied mod changed before resume")
        bootstrap = cache / "mods" / manifest["mapName"] / "42.20/media/lua/client/ZZStudyLaunch.lua"
        Lab.require(digest(bootstrap) == previous["launchSha256"], "run bootstrap changed before resume")
        for relative, content_hash in previous["saveFiles"].items():
            source = cache / relative
            Lab.require(source.resolve().is_relative_to(cache / "Saves") and digest(source) == content_hash,
                        "save changed before resume")
        # Native dependency loading can reorder the save's mods. ActiveMods
        # compares ordered lists; retain that verified order at the next boot
        # so Continue does not reset an already matching Lua environment.
        saved_mods = cache / "Saves/Sandbox" / previous["save"] / "mods.txt"
        shutil.copyfile(saved_mods, cache / "mods/default.txt")
        receipt = previous.copy()
        receipt["launchNumber"] = previous.get("launchNumber", 1) + 1
    else:
        cache, user, agent, manifest, definition = prepare(
            args.package, args.out, args.game, args.jdk, args.mod)
        receipt = Lab.load(destination / "run.json")
        receipt["launchNumber"] = 1
    attempt = destination / "attempts" / f"{receipt['launchNumber']:04d}"
    attempt.mkdir(parents=True, exist_ok=False)
    receipt["replacedPlayer"] = None
    if args.replace_dead_player:
        Lab.require(previous is not None, "replacement requires --resume")
        player_source = cache / "Saves/Sandbox" / previous["save"] / "players.db"
        shutil.copy2(player_source, attempt / "replaced-player.db")
        receipt["replacedPlayer"] = {"priorAttempt": previous["launchNumber"],
                                     "databaseSha256": digest(attempt / "replaced-player.db")}
    origin = next(p for p in definition["origins"] if p["profession"] == "unemployed")
    config = {"mapName": manifest["mapName"], "origin": {k: origin[k] for k in ("x", "y", "z")},
              "hours": args.hours, "attempt": receipt["launchNumber"],
              "observer": args.host == "observer", "watch": args.watch,
              "captureName": f"study-attempt-{receipt['launchNumber']:04d}.png"}
    if previous is not None:
        config["resumeSave"] = previous["save"]
        config["replaceDeadPlayer"] = args.replace_dead_player
    # Run control is separate from the content-sealed study observer.
    client = cache / "mods" / manifest["mapName"] / "42.20/media/lua/client"
    launch = "local RunConfig = " + Lab.lua(config) + "\n" + (
        Lab.ROOT / "tools/world_lab/StudyLaunch.lua").read_text(encoding="utf-8")
    (client / "ZZStudyLaunch.lua").write_bytes(launch.encode("utf-8"))
    (attempt / "launch.lua").write_bytes(launch.encode("utf-8"))
    sao_jars = list((cache / "mods").glob("*/42.20/media/java/SAO.jar"))
    Lab.require(len(sao_jars) == 1, "expected one copied SAO jar")
    command = [str(game / "jre64/bin/java.exe"),
               f"-Duser.home={user}", f"-Dstudy.attempt={receipt['launchNumber']}",
               "-Dstudy.showWindow=" + str(args.window == "visible").lower(), f"-javaagent:{agent}=isolated-study",
               f"-javaagent:{sao_jars[0]}=sao", "-agentlib:zbNative", "-Djava.awt.headless=true",
               "--enable-native-access=ALL-UNNAMED", "--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED",
               "-Xmx3072m", "-Dzomboid.steam=0", "-Dzomboid.znetlog=1", "-Djava.library.path=win64/;.",
               "-XX:-CreateCoredumpOnCrash", "-XX:-OmitStackTraceInFastThrow", "-XX:+UseZGC",
               "-cp", "./;projectzomboid.jar;ZombieBuddy.jar", "zombie.gameStates.MainScreenState",
               "-debug", "-nosteam", "-nosound", f"-cachedir={cache}"]
    if args.host == "observer":
        extent = definition["extent"]
        observer = {
            "observer": "true", "originX": origin["x"], "originY": origin["y"], "originZ": origin["z"],
            "minX": extent["minCellX"] * Lab.CELL, "minY": extent["minCellY"] * Lab.CELL,
            "maxX": (extent["minCellX"] + extent["cellsX"]) * Lab.CELL,
            "maxY": (extent["minCellY"] + extent["cellsY"]) * Lab.CELL,
            "observerControl": attempt / "observer-control.properties",
            "observerState": attempt / "observer-state.json", "viewDirectory": attempt / "native-view",
        }
        if previous:
            # Observer coordinates belong to the host receipt, never players.db.
            old = previous["observerEvidence"]["state"]
            observer.update(originX=old["residencyX"], originY=old["residencyY"], originZ=old["residencyZ"])
        command[1:1] = [f"-Dstudy.{key}={value}" for key, value in observer.items()]
    if args.trace_native:
        native_dump = attempt / "native-classes"
        native_dump.mkdir()
        command.insert(1, f"-Dnet.bytebuddy.dump={native_dump}")
    receipt.update(hours=args.hours, launchSha256=hashlib.sha256(launch.encode("utf-8")).hexdigest(),
                   window=args.window, status="starting", host=args.host, watch=args.watch,
                   sessionId=str(uuid.uuid4()), observerDirectory=attempt.relative_to(destination).as_posix())
    publish(destination / "run.json", receipt)
    startup = None
    if args.window == "hidden":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
    before_observations = set((cache / "Lua/StudyWorld").rglob("*.json"))
    with (attempt / "stdout.log").open("wb") as output, (attempt / "stderr.log").open("wb") as errors:
        process = subprocess.Popen(command, cwd=game, stdout=output, stderr=errors, startupinfo=startup)
        receipt.update(pid=process.pid, status="running")
        publish(destination / "run.json", receipt)
        print(json.dumps({"pid": process.pid, "run": str(destination), "status": "running"}), flush=True)
        try:
            code = process.wait(timeout=None if args.watch else args.timeout)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait(timeout=30)
            receipt.update(status="timed-out", exitCode=process.returncode)
        else:
            receipt.update(status="exited", exitCode=code)
    observations = sorted(set((cache / "Lua/StudyWorld").rglob("*.json")) - before_observations)
    receipt["observationFiles"] = len(observations)
    receipt["saveFiles"] = {p.relative_to(cache).as_posix(): digest(p)
                            for p in (cache / "Saves").rglob("*") if p.is_file()}
    log = (attempt / "stdout.log").read_text(encoding="utf-8", errors="replace")
    errors = (attempt / "stderr.log").read_text(encoding="utf-8", errors="replace")
    receipt["runtimeErrors"] = runtime_errors(log, errors)
    receipt["logs"] = {name: digest(attempt / name) for name in ("stdout.log", "stderr.log")}
    receipt["nativeImages"] = {p.relative_to(cache).as_posix(): digest(p)
                              for p in (cache / "Screenshots").glob(config["captureName"]) if p.is_file()}
    receipt["observations"] = {p.relative_to(cache).as_posix(): digest(p) for p in observations}
    receipt["inspection"] = None
    receipt["terminal"] = None
    if args.host == "observer":
        try:
            receipt["observerEvidence"] = observer_evidence(destination, receipt)
        except (ValueError, OSError, KeyError, TypeError) as error:
            receipt["runtimeErrors"].append("observer evidence: " + str(error))
    if observations:
        try:
            Lab.require(len({p.parent for p in observations}) == 1, "run wrote multiple observation sessions")
            receipt["inspection"] = Lab.inspect_frames(observations[0].parent, args.package)
            first, last = Lab.load(observations[0]), Lab.load(observations[-1])
            receipt.update(save=last["save"], lastSequence=last["sequence"], lastHours=last["hours"])
            receipt["terminal"] = terminal(log, receipt["launchNumber"], last["save"], args.hours, args.watch)
            receipt["player"] = saved_state(cache, receipt, definition)
            Lab.require(receipt["terminal"]["endHours"] - last["hours"]
                        <= definition["observation"]["everyHours"] + 1e-6, "observation stopped before horizon")
            for observed in observations:
                frame = Lab.load(observed)
                Lab.require(set(frame["mods"]) == set(receipt["mods"]), "activated mods differ from copied mods")
                Lab.require(receipt["terminal"]["startHours"] <= frame["hours"]
                            <= receipt["terminal"]["endHours"], "frame outside native run")
            if previous is not None:
                Lab.require(first["save"] == previous["save"] and first["sequence"] == previous["lastSequence"] + 1
                            and receipt["terminal"]["startHours"] >= previous["terminal"]["endHours"] - 1e-6,
                            "resume continuity differs")
                receipt["resumedFrom"] = {"attempt": previous["launchNumber"], "lastSequence": previous["lastSequence"],
                                          "terminalHours": previous["terminal"]["endHours"]}
        except (ValueError, sqlite3.Error) as error:
            receipt["runtimeErrors"].append(str(error))
    complete = (receipt["status"] == "exited" and receipt["exitCode"] == 0
                and receipt["terminal"]
                and receipt["saveFiles"] and receipt["inspection"] and not receipt["runtimeErrors"])
    if complete:
        receipt["status"] = "completed"
    elif receipt["status"] == "exited":
        receipt["status"] = "incomplete"
    publish(attempt / "report.json", receipt)
    publish(destination / "run.json", receipt)
    print(json.dumps({k: v for k, v in receipt.items() if k not in ("mods", "saveFiles", "observations")}, indent=2))
    return 0 if complete else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--verify", action="store_true", help="verify a completed run without launching")
    parser.add_argument("--game", type=Path)
    parser.add_argument("--jdk", type=Path)
    parser.add_argument("--mod", action="append", default=[], type=Path)
    parser.add_argument("--resume", action="store_true", help="reopen this tool's completed isolated run")
    parser.add_argument("--trace-native", action="store_true", help="retain transformed native classes in this attempt for diagnosis")
    parser.add_argument("--replace-dead-player", action="store_true",
                        help="with --resume, preserve the deceased database and create a native replacement character")
    parser.add_argument("--hours", type=float, default=1)
    parser.add_argument("--host", choices=("observer", "player"), default="observer")
    parser.add_argument("--watch", action="store_true", help="observe until a native stop command; no automatic horizon or timeout")
    parser.add_argument("--window", choices=("visible", "hidden"), default="visible",
                        help="use the native game renderer visibly, or keep its window hidden for batch runs")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    if args.verify:
        print(json.dumps(verify_run(args.out, args.package), allow_nan=False))
        return 0
    Lab.require(args.game is not None and args.jdk is not None, "launch requires --game and --jdk")
    Lab.number(args.hours, 1 / 3600, 24 * 365, "run hours")
    Lab.integer(args.timeout, 30, 86400, "wall-time limit")
    return run(args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(f"world_lab_run: {error}", file=sys.stderr)
        sys.exit(1)
