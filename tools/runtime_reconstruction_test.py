#!/usr/bin/env python3
"""Border 170: durable owners reconstruct, runtime objects do not cross worlds."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / "mod/42.20/media/lua"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
GRAPH_PROBE = ROOT / "tools/luacheck/RuntimeReconstructionProbe.java"
RESET_PROBE = ROOT / "tools/luacheck/RuntimeResetProbe.java"
LUA_RUN = ROOT / "tools/luacheck/LuaRun.java"


CONTROLLER_HOST = r'''
local function event()
 local e={handlers={}}
 function e.Add(fn)
  for _,known in ipairs(e.handlers) do if known==fn then return end end
  e.handlers[#e.handlers+1]=fn
 end
 function e.Remove(fn)
  for i=#e.handlers,1,-1 do if e.handlers[i]==fn then table.remove(e.handlers,i) end end
 end
 function e.fire() local copy={} for i,fn in ipairs(e.handlers) do copy[i]=fn end
  for _,fn in ipairs(copy) do fn() end end
 function e.count() return #e.handlers end
 return e
end
Events=setmetatable({}, {__index=function(t,k) local e=event() rawset(t,k,e) return e end})
getSpecificPlayer=function() return nil end
getTimestampMs=function() return 1 end
SandboxVars={SurvivorAwareness={}}
SAO={
 Log={EVERY=600,line=function() end,tally=function() end,flush=function() end},
 Standing={sameGroup=function() return false end,playerKey=function() return nil end},
 Perception={EARSHOT=30,beliefs={},forget=function() end,describe=function() return '' end},
 Body={active={},foreign={},get=function() return nil end,hasRepresentation=function() return false end},
 Identity={all=function() return {} end}, Voice={forget=function() end},
 Locomotion={cancel=function() end}, History={ticks=function() return 0 end},
}
__corpses=0
SAOJavaBridge={ensureCorpse=function() __corpses=__corpses+1 return 'DIED' end}
'''

CONTROLLER_CASE = r'''(function()
 assert(Events.OnSave.count()==1,'save callback missing or duplicated')
 SAO.Controller.pendingCorpses={p={body={},atHostTick=0}}
 Events.OnSave.fire()
 assert(__corpses==1 and SAO.Controller.pendingCorpses.p==nil,
  'save did not turn transient death into engine corpse')
 assert(SAO.Controller.lastCorpseSaveReport.completed==1
  and SAO.Controller.lastCorpseSaveReport.pending==0,'save report wrong')
 SAOJavaBridge=nil
 SAO.Controller.pendingCorpses={q={body={},atHostTick=0}}
 local report=SAO.Controller.flushPendingCorpses()
 assert(report.pending==1 and SAO.Controller.pendingCorpses.q,
  'failed corpse conversion lost exact body')
 return 'PASS'
end)()'''


def method(class_name: str, signature: str) -> str:
    result = subprocess.run(
        [str(JDK / "javap.exe"), "-c", "-p", "-classpath",
         str(GAME / "projectzomboid.jar"), class_name],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode:
        raise RuntimeError(result.stderr)
    lines = result.stdout.splitlines()
    start = next(i for i, line in enumerate(lines) if signature in line)
    end = next((i for i in range(start + 1, len(lines))
                if re.match(r"^  (public|private|protected|static) ", lines[i])), len(lines))
    return "\n".join(lines[start:end])


def engine_contract() -> None:
    init = method("zombie.world.moddata.GlobalModData", "public void init()")
    enter = method("zombie.gameStates.IngameState", "public void enter()")
    exit_body = method("zombie.gameStates.IngameState", "public void exit()")
    offsets = lambda body, term: [int(value) for value in re.findall(
        r"^\s*(\d+):.*" + re.escape(term) + r".*$", body, re.M)]
    assert offsets(init, "Method reset:()V")[0] < offsets(init, "Method load:()V")[0] \
        < offsets(init, "String OnInitGlobalModData")[0]
    assert offsets(enter, "String OnGameStart")[0] < offsets(enter, "String OnLoad")[0]
    assert offsets(exit_body, "Method zombie/Lua/LuaManager.init:()V")[0] \
        < offsets(exit_body, "Method zombie/Lua/LuaManager.LoadDirBase:()V")[0]
    print("ENGINE lifecycle: ModData reset/load/init event; fresh Lua before next world; game start before load")


def build_java(work: Path) -> None:
    cp = str(GAME / "projectzomboid.jar")
    result = subprocess.run(
        [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", cp,
         "-d", str(work), str(GRAPH_PROBE), str(LUA_RUN)],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode:
        raise RuntimeError("probe compile failed\n" + result.stdout + result.stderr)
    reset_cp = cp + ";" + str(ROOT / "mod/42.20/media/java/SAO.jar")
    result = subprocess.run(
        [str(JDK / "javac.exe"), "-encoding", "UTF-8", "-cp", reset_cp,
         "-d", str(work), str(RESET_PROBE)],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode:
        raise RuntimeError("reset probe compile failed\n" + result.stdout + result.stderr)


def graph_run(work: Path, root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(JDK / "java.exe"), "-cp", str(GAME / "projectzomboid.jar") + ";" + str(work),
         "RuntimeReconstructionProbe", str(root)],
        cwd=work, capture_output=True, text=True, timeout=90,
    )


def controller_run(work: Path, source: str) -> subprocess.CompletedProcess[str]:
    host = work / "controller-host.lua"
    controller = work / "controller.lua"
    host.write_text(CONTROLLER_HOST, encoding="utf-8")
    controller.write_text(source, encoding="utf-8")
    return subprocess.run(
        [str(JDK / "java.exe"), "-cp", str(GAME / "projectzomboid.jar") + ";" + str(work),
         "LuaRun", str(host), str(controller), "--", CONTROLLER_CASE],
        cwd=work, capture_output=True, text=True, timeout=90,
    )


def mirror_with(work: Path, module: str, source: str) -> Path:
    mirror = work / ("mirror-" + module.lower())
    if mirror.exists():
        shutil.rmtree(mirror)
    shared = mirror / "mod/42.20/media/lua/shared"
    shared.mkdir(parents=True)
    for name in ("Branching", "GraphPersistence", "Integration", "History",
                 "Identity", "Rand", "Places"):
        original = (LUA / "shared" / f"SAO_{name}.lua").read_text(encoding="utf-8")
        (shared / f"SAO_{name}.lua").write_text(source if name == module else original,
                                                 encoding="utf-8")
    return mirror


def main() -> int:
    required = [GAME / "projectzomboid.jar", GAME / "stdlib.lua", JDK / "java.exe",
                JDK / "javac.exe", JDK / "javap.exe", GRAPH_PROBE, RESET_PROBE,
                LUA_RUN, ROOT / "mod/42.20/media/java/SAO.jar"]
    if not all(path.is_file() for path in required):
        print("Border 170 SKIPPED: installed engine, JDK, probes or shipped jar absent")
        return 0
    faults: list[str] = []
    try:
        engine_contract()
        with tempfile.TemporaryDirectory(prefix="sao-runtime-reconstruction-") as tmp:
            work = Path(tmp)
            shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")
            build_java(work)

            production = graph_run(work, ROOT)
            if production.returncode or "RUNTIME_RECONSTRUCTION_OK" not in production.stdout:
                print(production.stdout + production.stderr)
                faults.append("production graph reconstruction")
            else:
                print("GRAPH production: durable history and runtime callbacks reconstruct")

            controls = []
            persistence = (LUA / "shared/SAO_GraphPersistence.lua").read_text(encoding="utf-8")
            old = "    store.branching.surfaces = nil"
            controls.append(("serialized callbacks", "GraphPersistence",
                persistence.replace(old, "    store.branching.surfaces = store.branching.surfaces or {}", 1)))
            history = (LUA / "shared/SAO_History.lua").read_text(encoding="utf-8")
            old = "H.onInitGlobalModData = function() H.rebindWorld() end"
            controls.append(("prior-world clock cache", "History",
                history.replace(old, "H.onInitGlobalModData = function() end", 1)))
            integration = (LUA / "shared/SAO_Integration.lua").read_text(encoding="utf-8")
            old = "    Integration.extensions[id] = installer"
            controls.append(("unstable extension identity", "Integration",
                integration.replace(old,
                    "    Integration.extensions[id .. tostring(installer)] = installer", 1)))
            old = "    if Integration.extensions[id] == nil\n        and extensionCount() >= EXTENSION_CEILING then"
            controls.append(("unbounded extension registry", "Integration",
                integration.replace(old, "    if false then", 1)))
            for label, module, changed in controls:
                mirror = mirror_with(work, module, changed)
                result = graph_run(work, mirror)
                rejected = result.returncode != 0
                print("CONTROL " + label + ": " + ("REJECTED" if rejected else "SURVIVED"))
                if not rejected:
                    faults.append(label)

            controller_source = (LUA / "client/SAO_Controller.lua").read_text(encoding="utf-8")
            result = controller_run(work, controller_source)
            if result.returncode or "VALUE PASS" not in result.stdout:
                print(result.stdout + result.stderr)
                faults.append("save-time corpse completion")
            else:
                print("CORPSE production: pre-save grace is completed, failed conversion retained")
            changed = controller_source.replace(
                "    Events.OnSave.Add(Ctl.onSavePendingCorpses)", "", 1)
            result = controller_run(work, changed)
            rejected = result.returncode != 0 or "VALUE PASS" not in result.stdout
            print("CONTROL missing save callback: " + ("REJECTED" if rejected else "SURVIVED"))
            if not rejected:
                faults.append("missing save callback")

            reset_cp = str(GAME / "projectzomboid.jar") + ";" \
                + str(ROOT / "mod/42.20/media/java/SAO.jar") + ";" + str(work)
            result = subprocess.run([str(JDK / "java.exe"), "-cp", reset_cp,
                                     "RuntimeResetProbe"], capture_output=True,
                                    text=True, timeout=90, cwd=work)
            if result.returncode or "RUNTIME_RESET_OK" not in result.stdout:
                print(result.stdout + result.stderr)
                faults.append("native runtime reset")
            else:
                print("NATIVE production: process singleton releases all body/world maps")
    except Exception as error:
        print("FAULT: " + str(error))
        faults.append("probe error")

    if faults:
        print("Border 170 FAULT: " + ", ".join(dict.fromkeys(faults)))
        return 1
    print("  170) runtime reconstruction: PASS -- serialization, reconstruction, "
          "corpse save boundary and world teardown")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
