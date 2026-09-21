#!/usr/bin/env python3
r"""Border 178 - native hydration establishes truth without awarding use.

This border runs the shipped Lua ledger in Project Zomboid's Kahlua VM,
weaves the installed ItemPickerJava bytes, and starts the shipped jar as a real
premain agent. It distinguishes observed stock from executable availability,
exercises exact-source reservations only with a hand-authored accessible
control, rejects incomplete protocol input, retries loaded reconciliation, and
proves the durable working set is bounded.
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
WORLD = ROOT / "mod/42.20/media/lua/shared/SAO_WorldSources.lua"
PLACES = ROOT / "mod/42.20/media/lua/shared/SAO_Places.lua"
BRIDGE = ROOT / "java/src/com/sao/bridge/SAOBridge.java"
JAVA = ROOT / "java/src/com/sao/engine/SAOWorldSources.java"
WEAVE = ROOT / "java/src/com/sao/agent/SAOLootDensityWeave.java"
MAIN = ROOT / "java/src/com/sao/Main.java"
AGENT = ROOT / "java/src/com/sao/agent/SAOAgent.java"
RUNNER = TOOLS / "luacheck/LuaRun.java"
WEAVE_CHECK = TOOLS / "javacheck/WorldSourceWeaveCheck.java"
OUT = ROOT / "java/out/luacheck"
JAR = ROOT / "java/dist/SAOAgent.jar"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
ZB = PZ_DIR / "ZombieBuddy.jar"
PZ_JAVA = PZ_DIR / "jre64/bin/java.exe"
STDLIB = PZ_DIR / "stdlib.lua"


def snapshot(cx, cy, revision, sources, status="OBSERVED", mode="test"):
    lines = [
        f"H|protocol=SAOWS1|status={status}|detail=|mode={mode}|cx={cx}"
        f"|cy={cy}|revision={revision}|sources={len(sources)}"
    ]
    for source in sources:
        quantities = "".join(
            f"|q:{name}={quantity:.6f}"
            for name, quantity in source.get("quantities", {}).items())
        lines.append(
            "S|id={id}|fp={fp}|rev={rev}|kind={kind}|x={x}|y={y}|z=0"
            "|building={building}|explored=1|state=available|access={access}"
            "|container={container}{quantities}".format(
                id=source["id"], fp=source["fp"], rev=source["rev"],
                x=source["x"], y=source["y"], building=source["building"],
                kind=source.get("kind", "container"),
                access=source.get("access", "unknown"),
                container=source.get("container", "counter"),
                quantities=quantities,
            )
        )
        for item in source.get("items", []):
            lines.append(
                "I|source={source}|id={id}|type={type}|uses=1|amount={amount:.6f}"
                "|fluid={fluid}|poison=0|rotten=0|cats={cats}".format(
                    source=source["id"], id=item["id"], type=item["type"],
                    amount=item["amount"], fluid=item.get("fluid", ""),
                    cats=item["cats"])
            )
    lines.append("E")
    return "\n".join(lines) + "\n"


UNKNOWN_ID = "C:unknown-token:0"
UNKNOWN = snapshot(1, 2, "unknown-1", [{
    "id": UNKNOWN_ID, "fp": "unknown-fp", "rev": "unknown-r1",
    "x": 8, "y": 16, "building": 42,
    "quantities": {"food": 1},
    "items": [{"id": 101, "type": "Base.Apple", "amount": 0,
               "cats": "food"}],
}], status="HYDRATED", mode="native-offscreen")

LOCK_ID = "C:lock-token:0"
ACCESSIBLE_LOCK = snapshot(2, 3, "lock-1", [{
    "id": LOCK_ID, "fp": "lock-fp", "rev": "lock-r1",
    "x": 16, "y": 24, "building": 43, "access": "accessible",
    "quantities": {"food": 1, "water": 1},
    "items": [{"id": 201, "type": "Base.Soup", "amount": 1,
               "fluid": "Water", "cats": "food,water"}],
}])

CONCURRENT_A = "C:concurrent-a:0"
CONCURRENT_B = "C:concurrent-b:0"
ACCESSIBLE_TWO = snapshot(3, 4, "concurrent-1", [
    {
        "id": CONCURRENT_A, "fp": "concurrent-a-fp", "rev": "a-r1",
        "x": 24, "y": 32, "building": 44, "access": "accessible",
        "quantities": {"food": 1},
        "items": [{"id": 301, "type": "Base.Apple", "amount": 0,
                   "cats": "food"}],
    },
    {
        "id": CONCURRENT_B, "fp": "concurrent-b-fp", "rev": "b-r1",
        "x": 25, "y": 32, "building": 44, "access": "accessible",
        "quantities": {"food": 1},
        "items": [{"id": 302, "type": "Base.Banana", "amount": 0,
                   "cats": "food"}],
    },
])

OLD_ID = "C:replacement-old:0"
NEW_ID = "C:replacement-new:0"
REPLACE_OLD = snapshot(7, 7, "replace-1", [{
    "id": OLD_ID, "fp": "old-fp", "rev": "old-r1",
    "x": 56, "y": 56, "building": 47,
    "quantities": {"food": 1},
    "items": [{"id": 401, "type": "Base.Apple", "amount": 0,
               "cats": "food"}],
}])
REPLACE_NEW = snapshot(7, 7, "replace-2", [{
    "id": NEW_ID, "fp": "new-fp", "rev": "new-r1",
    "x": 56, "y": 56, "building": 47,
    "quantities": {"food": 1},
    "items": [{"id": 402, "type": "Base.Apple", "amount": 0,
               "cats": "food"}],
}])

MOVE_ID = "C:moved-token:0"
MOVE_OLD = snapshot(8, 8, "move-1", [{
    "id": MOVE_ID, "fp": "move-fp-1", "rev": "move-r1",
    "x": 64, "y": 64, "building": 48,
    "quantities": {"food": 1},
    "items": [{"id": 501, "type": "Base.Apple", "amount": 0,
               "cats": "food"}],
}])
MOVE_NEW = snapshot(8, 8, "move-2", [{
    "id": MOVE_ID, "fp": "move-fp-2", "rev": "move-r1",
    "x": 65, "y": 64, "building": 48,
    "quantities": {"food": 1},
    "items": [{"id": 501, "type": "Base.Apple", "amount": 0,
               "cats": "food"}],
}])

RETRY_ID = "C:retry-token:0"
RETRY_OK = snapshot(9, 10, "retry-1", [{
    "id": RETRY_ID, "fp": "retry-fp", "rev": "retry-r1",
    "x": 72, "y": 80, "building": 49,
    "quantities": {"food": 1},
    "items": [{"id": 601, "type": "Base.Apple", "amount": 0,
               "cats": "food"}],
}])
BUSY = snapshot(9, 10, "", [], status="BUSY", mode="none")

PROTECT_ID = "C:protected-token:0"
PROTECTED = snapshot(1000, 1000, "protected-1", [{
    "id": PROTECT_ID, "fp": "protected-fp", "rev": "protected-r1",
    "x": 8000, "y": 8000, "building": 99, "access": "accessible",
    "quantities": {"food": 1},
    "items": [{"id": 701, "type": "Base.Apple", "amount": 0,
               "cats": "food"}],
}])

TRUNCATED = (
    "H|protocol=SAOWS1|status=OBSERVED|detail=|mode=test|cx=7|cy=7"
    "|revision=corrupt|sources=0\n")

PRELUDE = r'''
SAO = { History = { countyHours = function() return 12 end },
        Log = { line = function() end } }
_G.__stores = {}
ModData = { getOrCreate = function(key)
    __stores[key] = __stores[key] or {}
    return __stores[key]
end }
_G.__handlers = {}
Events = setmetatable({}, { __index = function(t, key)
    local slot = {
        Add = function(fn) __handlers[key] = fn end,
        Remove = function(fn)
            if __handlers[key] == fn then __handlers[key] = nil end
        end,
    }
    rawset(t, key, slot)
    return slot
end })
_G.__records, _G.__bodies = {}, {}
SAO.Identity = { get = function(id) return __records[tostring(id)] end }
SAO.Body = {
  get = function(id) return __bodies[tostring(id)] end,
  hasRepresentation = function(id) return __bodies[tostring(id)] ~= nil end,
}
SAO.Standing = { mayAttemptBelieved = function() return true end }
SAO.Perception = { _known = {}, knownPlaces = function(id)
    return SAO.Perception._known[tostring(id)] or {}
end }
SAO.Places = { at = function(x, y)
    if x == 12 and y == 20 then
        return { id = 42, cx = 12, cy = 20, minX = 8, minY = 16,
                 maxX = 16, maxY = 24 }
    end
    return nil
end }
'''


PROBE_TEMPLATE = r'''(function()
  local checks = {}
  local function check(name, condition)
    checks[#checks + 1] = name .. "=" .. tostring(condition and true or false)
  end
  local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
  end
  local function learn(actor, place)
    actor = tostring(actor)
    __records[actor] = __records[actor] or { id=actor }
    __bodies[actor] = __bodies[actor] or {}
    local sources, revision, access, facts =
        SAO.WorldSources.beliefSnapshot(place)
    SAO.Perception._known[actor] = { [place.id] = {
        cx=place.cx, cy=place.cy, minX=place.minX, minY=place.minY,
        maxX=place.maxX, maxY=place.maxY, sources=sources,
        sourceRevision=revision, sourceAccess=access, sourceFacts=facts } }
    return __bodies[actor]
  end
  local placeUnknown = { id = 42, cx = 12, cy = 20,
      minX = 8, minY = 16, maxX = 16, maxY = 24 }
  local placeLock = { id = 43, cx = 20, cy = 28,
      minX = 16, minY = 24, maxX = 24, maxY = 32 }
  local placeTwo = { id = 44, cx = 28, cy = 36,
      minX = 24, minY = 32, maxX = 32, maxY = 40 }
  local placeProtected = { id = 99, cx = 8004, cy = 8004,
      minX = 8000, minY = 8000, maxX = 8008, maxY = 8008 }

  local hydrateText = %(unknown)s
  SAOJavaBridge = {
    hydrateWorldChunk = function() return hydrateText end,
    observeWorldChunk = function() return %(busy)s end,
    worldSourceStatus = function() return "ready" end,
  }

  local demanded = SAO.WorldSources.demandPlace(placeUnknown)
  local observed = SAO.WorldSources.observedAt(placeUnknown)
  local available = SAO.WorldSources.availableAt(placeUnknown)
  check("demand_observes", demanded and observed.food == 1)
  check("unknown_unavailable", available.food == nil)
  check("exact_item", SAO.WorldSources.source(%(unknown_id)s).items["101"].type
      == "Base.Apple")

  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(lock)s))
  local bodyA, bodyB = learn("a",placeLock), learn("b",placeLock)
  local lock = SAO.WorldSources.beginAction(
      placeLock,"food","a",bodyA,1,"standing")
  local cross = SAO.WorldSources.beginAction(
      placeLock,"water","b",bodyB,0.01,"standing")
  check("source_wide_lock", lock ~= nil and cross == nil)
  check("release_restores", SAO.WorldSources.release(lock.id, "control")
      and SAO.WorldSources.availableAt(placeLock).food == 1)

  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(two)s))
  bodyA, bodyB = learn("a",placeTwo), learn("b",placeTwo)
  local first = SAO.WorldSources.beginAction(
      placeTwo,"food","a",bodyA,1,"standing")
  local second = SAO.WorldSources.beginAction(
      placeTwo,"food","b",bodyB,1,"standing")
  check("separate_sources_concurrent", first and second
      and first.sourceId ~= second.sourceId)
  SAO.WorldSources.release(first.id, "control")
  SAO.WorldSources.release(second.id, "control")

  SAO.Perception._known.a = { [42] = { cx = 12, cy = 20,
      sources = { food = true }, sourceAccess = { food = true } } }
  SAO.Perception._known.b = { [42] = { cx = 12, cy = 20,
      sources = { food = true }, sourceAccess = {} } }
  check("private_access_gate",
      SAO.WorldSources.nearestBelieved("a", 10, 20, "food", 50) ~= nil
      and SAO.WorldSources.nearestBelieved("b", 10, 20, "food", 50) == nil)

  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(replace_old)s))
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(replace_new)s))
  local missing = SAO.WorldSources.source(%(old_id)s)
  check("replacement_new_identity", missing.state == "conflicted"
      and missing.conflict.reason == "native-source-missing"
      and SAO.WorldSources.source(%(new_id)s).state == "available")

  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(move_old)s))
  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(move_new)s))
  local moved = SAO.WorldSources.source(%(move_id)s)
  check("moved_identity_conflicts", moved.state == "conflicted"
      and moved.conflict.reason == "physical-fingerprint-changed")

  local beforeRevision = SAO.WorldSources.source(%(new_id)s).revision
  local incomplete = SAO.WorldSources.parse(%(truncated)s)
  if incomplete then SAO.WorldSources.applySnapshot(incomplete) end
  check("truncated_rejected", incomplete == nil
      and SAO.WorldSources.source(%(new_id)s).revision == beforeRevision)

  local observeCalls = 0
  SAOJavaBridge.observeWorldChunk = function()
    observeCalls = observeCalls + 1
    if observeCalls == 1 then return %(busy)s end
    return %(retry_ok)s
  end
  __handlers.LoadGridsquare({
      getX = function() return 72 end,
      getY = function() return 80 end,
  })
  for _ = 1, 6 do SAO.WorldSources.processLoadedObservations() end
  check("loaded_retry", observeCalls == 2
      and SAO.WorldSources.source(%(retry_id)s) ~= nil)

  SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(%(protected)s))
  local keeperBody = learn("keeper",placeProtected)
  local protected = SAO.WorldSources.beginAction(
      placeProtected,"food","keeper",keeperBody,1,"standing")
  for i = 1, 270 do
    local cx = 2000 + i
    local id = "C:retention-" .. tostring(i) .. ":0"
    local text = "H|protocol=SAOWS1|status=OBSERVED|detail=|mode=test|cx="
      .. tostring(cx) .. "|cy=0|revision=r" .. tostring(i) .. "|sources=1\n"
      .. "S|id=" .. id .. "|fp=f" .. tostring(i) .. "|rev=r1|kind=container"
      .. "|x=" .. tostring(cx * 8) .. "|y=0|z=0|building="
      .. tostring(10000 + i)
      .. "|explored=1|state=available|access=unknown|container=counter"
      .. "|q:food=1.000000\n"
      .. "I|source=" .. id .. "|id=" .. tostring(10000 + i)
      .. "|type=Base.Apple|uses=1|amount=0.000000|fluid=|poison=0"
      .. "|rotten=0|cats=food\nE\n"
    SAO.WorldSources.applySnapshot(SAO.WorldSources.parse(text))
  end
  local state = __stores.SurvivorAwareness_WorldSources
  check("bounded_chunks", count(state.chunks) <= 256
      and count(state.sources) <= 256)
  check("reserved_chunk_protected", protected ~= nil
      and SAO.WorldSources.source(%(protect_id)s) ~= nil)
  SAO.WorldSources.release(protected.id, "retention-control")

  local receiptBody = learn("receipt",placeProtected)
  for i = 1, 2055 do
    local receipt = SAO.WorldSources.beginAction(
        placeProtected,"food","receipt",receiptBody,1,"standing")
    if receipt then SAO.WorldSources.release(receipt.id, "receipt-control") end
  end
  check("bounded_results", count(state.results) <= 2048
      and count(state.reservations) <= 2048
      and count(state.resultByActor) <= 2048)
  check("schema", state.schema == 5)
  return table.concat(checks, "|")
end)()'''


SUBSTITUTIONS = {
    "unknown": json.dumps(UNKNOWN), "busy": json.dumps(BUSY),
    "unknown_id": json.dumps(UNKNOWN_ID), "lock": json.dumps(ACCESSIBLE_LOCK),
    "two": json.dumps(ACCESSIBLE_TWO), "replace_old": json.dumps(REPLACE_OLD),
    "replace_new": json.dumps(REPLACE_NEW), "old_id": json.dumps(OLD_ID),
    "new_id": json.dumps(NEW_ID), "move_old": json.dumps(MOVE_OLD),
    "move_new": json.dumps(MOVE_NEW), "move_id": json.dumps(MOVE_ID),
    "truncated": json.dumps(TRUNCATED), "retry_ok": json.dumps(RETRY_OK),
    "retry_id": json.dumps(RETRY_ID), "protected": json.dumps(PROTECTED),
    "protect_id": json.dumps(PROTECT_ID),
}
PROBE = PROBE_TEMPLATE % SUBSTITUTIONS
EXPECTED = {
    "demand_observes", "unknown_unavailable", "exact_item",
    "source_wide_lock", "release_restores", "separate_sources_concurrent",
    "private_access_gate", "replacement_new_identity",
    "moved_identity_conflicts", "truncated_rejected", "loaded_retry",
    "bounded_chunks", "reserved_chunk_protected", "bounded_results", "schema",
}


def compile_runner():
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(RUNNER)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0, (done.stderr or done.stdout)


def kahlua_probe():
    ok, detail = compile_runner()
    if not ok:
        return None, "LuaRun compile failed: " + detail[:500]
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for cls in OUT.glob("LuaRun*.class"):
            shutil.copy2(cls, work / cls.name)
        prelude = work / "prelude.lua"
        prelude.write_text(PRELUDE, encoding="utf-8")
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(prelude), str(WORLD), "--", PROBE],
            cwd=work, capture_output=True, text=True, timeout=300)
    lines = (done.stdout or "").strip().splitlines()
    value = lines[-1][6:] if lines and lines[-1].startswith("VALUE ") else None
    return value, (done.stdout or "") + (done.stderr or "")


def weave_probe():
    with tempfile.TemporaryDirectory() as tmp:
        cp = os.pathsep.join(map(str, (PZ, ZB, JAR)))
        compiled = subprocess.run(
            [str(JDK / "javac.exe"), "-cp", cp, "-d", tmp, str(WEAVE_CHECK)],
            capture_output=True, text=True, timeout=300)
        if compiled.returncode:
            return False, (compiled.stderr or compiled.stdout)[:800]
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", os.pathsep.join((cp, tmp)),
             "WorldSourceWeaveCheck"], capture_output=True, text=True,
            timeout=300)
        output = (done.stdout or "") + (done.stderr or "")
        return "WEAVE PASS" in output, output


def premain_probe():
    source = """\
import com.sao.engine.SAOWorldSources;
public final class WorldSourcePremainCheck {
    public static void main(String[] args) {
        System.out.println(SAOWorldSources.status());
    }
}
"""
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        path = work / "WorldSourcePremainCheck.java"
        path.write_text(source, encoding="utf-8")
        cp = os.pathsep.join(map(str, (PZ, ZB, JAR)))
        compiled = subprocess.run(
            [str(JDK / "javac.exe"), "-cp", cp, "-d", tmp, str(path)],
            capture_output=True, text=True, timeout=300)
        if compiled.returncode:
            return False, (compiled.stderr or compiled.stdout)[:800]
        done = subprocess.run(
            [str(PZ_JAVA), f"-javaagent:{JAR}=sao", "-cp",
             os.pathsep.join((cp, tmp)), "WorldSourcePremainCheck"],
            capture_output=True, text=True, timeout=300)
        output = (done.stdout or "") + (done.stderr or "")
        return (done.returncode == 0 and "weave=ready" in output
                and "target=retransformed" in output), output


def installed_chunk_size():
    done = subprocess.run(
        [str(JDK / "javap.exe"), "-classpath", str(PZ), "-constants",
         "zombie.iso.IsoChunkMap"], capture_output=True, text=True, timeout=120)
    match = re.search(r"CHUNK_SIZE_IN_SQUARES\s*=\s*(\d+)", done.stdout or "")
    return int(match.group(1)) if match else None


def manifest_is_retransformable():
    with zipfile.ZipFile(JAR) as archive:
        text = archive.read("META-INF/MANIFEST.MF").decode("utf-8", "replace")
    return ("Can-Retransform-Classes: true" in text
            and "Can-Redefine-Classes: true" in text)


def main():
    faults = []
    print("=" * 74)
    print("NATIVE HYDRATION ESTABLISHES TRUTH WITHOUT AWARDING USE")
    print("=" * 74)
    required = (WORLD, PLACES, BRIDGE, JAVA, WEAVE, MAIN, AGENT, RUNNER,
                WEAVE_CHECK, JAR, PZ, ZB, PZ_JAVA, STDLIB, JDK / "java.exe")
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        print("  SKIPPED - missing " + ", ".join(missing))
        return 0

    world_text = WORLD.read_text(encoding="utf-8", errors="replace")
    places_text = PLACES.read_text(encoding="utf-8", errors="replace")
    bridge_text = BRIDGE.read_text(encoding="utf-8", errors="replace")
    java_text = JAVA.read_text(encoding="utf-8", errors="replace")
    weave_text = WEAVE.read_text(encoding="utf-8", errors="replace")
    main_text = MAIN.read_text(encoding="utf-8", errors="replace")
    agent_text = AGENT.read_text(encoding="utf-8", errors="replace")

    for old in ("function Pl.offersNow", "function Pl.take(",
                "function Pl.nearestOffering", "TAKES_PER_ROOM"):
        if old in places_text:
            faults.append("legacy room/visit stock remains callable: " + old)
    for token in ("function WS.observedAt", "function WS.availableAt",
                  "function WS.beginAction", "function WS.release",
                  'source.access ~= "accessible"', "nearestBelieved",
                  "MAX_TRACKED_CHUNKS", "MAX_RESULTS", "MAX_PENDING_LOADS",
                  "MAX_PROJECTION_CHANGES",
                  "if not trimProjectionChanges(value) then return nil end",
                  "if #ordered >= MAX_PROJECTION_CHANGES then break end"):
        if token not in world_text:
            faults.append("bounded ledger contract is absent: " + token)
    for forbidden in ("function WS.commit", "consumeWorldSource"):
        if forbidden in world_text + bridge_text + java_text:
            faults.append("observation still contains native-use shortcut: " + forbidden)
    for forbidden in ("getEntityNetID()", ".doLoadGridsquare(", ".refs.add(",
                      ".removeFromWorld("):
        if forbidden in java_text:
            faults.append("unsafe native lifecycle/identity path remains: " + forbidden)
    for token in ("SOURCE_TOKEN", "ITEM_TOKEN", "UUID.randomUUID()",
                  "getModData().rawset", "WorldStreamer.instance.addJobInstant",
                  "loadInWorldStreamerThread", "chunk.Save(true)",
                  "doReuseGridsquares", 'source.access = "unsupported"',
                  "MAX_SOURCES_PER_CHUNK", "MAX_ITEMS_PER_SOURCE",
                  "MAX_CONTAINER_DEPTH", "scanVehicle(snapshot, vehicle, false)"):
        if token not in java_text:
            faults.append("native identity/lifecycle bound is absent: " + token)
    if 'TARGET = "zombie.inventory.ItemPickerJava"' not in weave_text \
            or 'METHOD = "getZombieDensityFactor"' not in weave_text:
        faults.append("loot-density weave targets the wrong engine seam")
    if "SAOLootDensityWeave.install()" not in main_text \
            or "SAOLootDensityWeave.install(instrumentation)" not in agent_text:
        faults.append("one Java load path omits the fail-closed density weave")

    size = installed_chunk_size()
    print(f"  installed chunk edge: {size}")
    if size != 8 or "local CHUNK_SIZE = 8" not in world_text \
            or "IsoChunkMap.CHUNK_SIZE_IN_SQUARES" not in java_text:
        faults.append("building/chunk mapping disagrees with installed 42.20.4")

    try:
        manifest_ok = manifest_is_retransformable()
    except Exception as exc:
        manifest_ok = False
        faults.append("agent manifest unreadable: " + str(exc))
    print("  agent manifest: " + ("PASS" if manifest_ok else "FAIL"))
    if not manifest_ok:
        faults.append("agent manifest does not authorize retransformation")

    woven, weave_output = weave_probe()
    print("  offline density weave: " + ("PASS" if woven else "FAIL"))
    if not woven:
        faults.append("installed ItemPickerJava bytes do not weave/link: "
                      + weave_output.replace("\n", " ")[:500])

    premain, premain_output = premain_probe()
    print("  premain retransformation: " + ("PASS" if premain else "FAIL"))
    if not premain:
        faults.append("real premain did not retransform loaded ItemPickerJava: "
                      + premain_output.replace("\n", " ")[:500])

    value, detail = kahlua_probe()
    results = {}
    if value:
        for item in value.split("|"):
            key, sep, answer = item.partition("=")
            if sep:
                results[key] = answer
    missing_checks = sorted(EXPECTED - results.keys())
    failed_checks = sorted(key for key in EXPECTED if results.get(key) != "true")
    ledger_ok = not missing_checks and not failed_checks
    print("  Kahlua ledger controls: " + ("PASS" if ledger_ok else "FAIL"))
    if not ledger_ok:
        faults.append("Kahlua controls missing=%r failed=%r value=%r detail=%s" %
                      (missing_checks, failed_checks, value,
                       detail.replace("\n", " ")[:800]))

    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    print("  178) demand hydrates bounded native ground and records exact identity;")
    print("       unknown access cannot establish availability or award use;")
    print("       loaded observation retries, replacement/movement conflict,")
    print("       and receipts compact")
    return 0


if __name__ == "__main__":
    sys.exit(main())
