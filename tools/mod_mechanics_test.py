#!/usr/bin/env python3
"""Installed TienCoolers physical processing on exact off-slot native inventories.

Runs installed shared/client/server Lua in installed Kahlua with real engine
bodies, nested containers, item definitions, Food.updateAge, world time, ice
charge and strict native person capture/wake. UI, network sends and event dispatch
are explicit offline fixtures. Production Body/BodySnapshot execute all five
checkpoint callers; population facts, queue readiness and teardown are controlled
surrounding services. No game launch, real save, training or mod copying.
Cooler-aware dormant meal selection remains outside this loaded/wake slice.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
HERE = ROOT / "tools/mod_mechanics_checks"
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
MOD = Path(os.environ.get("SAO_TIEN_COOLERS_DIR",
    r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3794455791\mods\TienCoolers\42"))
OWNER = ROOT / "mod/42.20/media/lua/client/SAO_ModMechanics.lua"
BODY = ROOT / "mod/42.20/media/lua/client/SAO_Body.lua"
SNAPSHOT = ROOT / "mod/42.20/media/lua/shared/SAO_BodySnapshot.lua"
IDENTITY = ROOT / "mod/42.20/media/lua/shared/SAO_Identity.lua"
PREFLIGHT = ROOT / "tools/native_proof_preflight.py"
LUA_READER = ROOT / "tools/lua_read.py"
SOURCES = [HERE / "ModMechanicsProbe.java", ROOT / "tools/luacheck/MovementCrossingProbe.java"]
INSTALLED_LUA = [MOD / "media/lua" / part for part in (
    "shared/TienCoolers/TienCooler_Shared.lua",
    "client/TienCoolers/TienCooler_Client.lua",
    "server/TienCoolers/TienCooler_Server.lua")]
FIXTURES = [HERE / part for part in ("prelude.lua", "absence.lua", "cases.lua", "body_prelude.lua", "body_cases.lua", "death_cases.lua")]
JARS = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", ROOT / "mod/42.20/media/java/SAO.jar"]
CONTROLS = [
    ("allow-living-runtime-forget", 'if not rec or rec.dead ~= true then return false, "actor-not-dead" end',
     'if false then return false, "actor-not-dead" end', "living_actor_cannot_forget_cooler_runtime"),
    ("retain-dead-cooler-body", '    if not rec or rec.dead ~= true then return false, "actor-not-dead" end\n    runtime[id] = nil',
     '    if not rec or rec.dead ~= true then return false, "actor-not-dead" end\n    -- controlled retained runtime',
     "actual_death_releases_living_cooler_runtime"),
    ("retain-dead-cooler-log-scratch", '    if not rec or rec.dead ~= true then return false, "actor-not-dead" end\n    runtime[id] = nil\n    lastFailures[id] = nil',
     '    if not rec or rec.dead ~= true then return false, "actor-not-dead" end\n    runtime[id] = nil\n    -- controlled retained dedup scratch',
     "death_drops_cooler_log_dedup_scratch"),
    ("forget-unresolved-native-pass", 'return type(state) == "table" and state.coolerFailure or nil',
     "return nil", "clock_only_failure_retry_cannot_certify_checkpoint"),
    ("accept-retained-old-world", 'if not cell or (not cell:getObjectList():contains(body)\n            and not cell:getAddList():contains(body)) then',
     "if false then", "retained_old_native_world_cannot_process_inventory"),
    ("refuse-retained-unload-checkpoint", "local checkpointUnloaded = snapshotRec == rec and SAO.Body.unloaded\n        and SAO.Body.unloaded[id] == true",
     "local checkpointUnloaded = false",
     "authenticated_unloaded_inventory_can_reach_final_checkpoint"),
    ("accept-arbitrary-detached-checkpoint", "local checkpointUnloaded = snapshotRec == rec and SAO.Body.unloaded\n        and SAO.Body.unloaded[id] == true",
     "local checkpointUnloaded = snapshotRec == rec",
     "detached_checkpoint_requires_canonical_unload_journal"),
    ("lose-foreign-inventory-callback", "    for id in pairs(SAO.Body.foreign or {}) do ids[tostring(id)] = true end",
     "    -- controlled omission of owned foreign inventory",
     "both_owned_offslot_inventories_receive_native_baseline"),
    ("accept-foreign-token", "\n        or data.SAOExternalToken ~= rec.bodyOwnerToken", "",
     "foreign_actor_token_mismatch_refuses_checkpoint"),
    ("invent-multiplayer-authority", "if isClient() or isServer() then return true, \"multiplayer-unowned\" end",
     "if false then return true, \"multiplayer-unowned\" end",
     "multiplayer_endpoints_do_not_invent_npc_inventory_authority"),
    ("mask-native-update-error", "return false, \"cooler-update-error\"\n    end\n    runtime[id] =", "return true, \"cooler-update-error\"\n    end\n    runtime[id] =",
     "native_update_error_refuses_partial_checkpoint"),
    ("omit-installed-physics", "local completed, found = pcall(CF.processTopLevel, inventory)", "local completed, found = true, false",
     "both_owned_offslot_inventories_receive_native_baseline"),
    ("steal-player-slot-authority", "    for slot = 0, 3 do\n        if getSpecificPlayer(slot) == body then return nil, \"native-player-owned\" end\n    end",
     "    -- controlled omission of native player slot boundary",
     "native_player_inventory_retains_installed_authority"),
]
BODY_CONTROLS = [
    ("omit-body-checkpoint-mechanics", "if SAO.ModMechanics and SAO.ModMechanics.beforeSnapshot then",
     "if false then", "body_active_save_orders_cooler_before_native_capture"),
]
IDENTITY_CONTROLS = [
    ("omit-death-cooler-caller", "if SAO.ModMechanics and SAO.ModMechanics.forget then",
     "if false then", "actual_death_releases_living_cooler_runtime"),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    print("Border 230: Carried cooler physics and native checkpoint owners")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--required", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not PREFLIGHT.is_file():
        print("FAILED cooler proof: owned proof inputs absent: " + str(PREFLIGHT))
        return 1
    from native_proof_preflight import presence, causal_controls
    owned = [OWNER, BODY, SNAPSHOT, IDENTITY, PREFLIGHT, LUA_READER, Path(__file__).resolve(), *SOURCES, *FIXTURES, JARS[2]]
    installed = [*INSTALLED_LUA, *JARS[:2], GAME / "stdlib.lua", MOD / "mod.info", MOD / "media/scripts/TienCooler_items.txt",
        GAME / "media/scripts/generated/items/container.txt", GAME / "media/scripts/generated/items/food.txt"]
    readiness = presence(owned, [*installed, JDK / "javac.exe", JDK / "java.exe"], args.required, "cooler proof")
    if readiness is not None:
        return readiness
    from lua_read import function_body
    inputs = [*owned, *installed]
    with tempfile.TemporaryDirectory(prefix="sao-mod-mechanics-") as directory:
        work = Path(directory)
        out = (args.output or work / "receipt").resolve()
        out.mkdir(parents=True, exist_ok=True)
        receipt = {"boundary": __doc__, "runs": [], "controls": [],
            "preflight": causal_controls(ROOT, Path(__file__).resolve(), owned,
                env_updates={"PZ_DIR": "{absent-engine}", "SAO_TIEN_COOLERS_DIR": "{absent-extension}", "JDK_BIN": "{absent-jdk}"},
                missing_owned=BODY),
            "inputs_before": {str(p.resolve()): digest(p) for p in inputs},
            "versions": {"mod_info": dict(line.split("=", 1) for line in (MOD / "mod.info").read_text().splitlines() if "=" in line)},
            "dormant_limit": "Native wake can reconcile saved cooler clocks; native dormant meal selection/consumption precedes this Lua pass."}
        shared_text = INSTALLED_LUA[0].read_text(encoding="utf-8-sig")
        receipt["versions"]["shared_api"] = re.search(r'CF.VERSION\s*=\s*"([^"]+)"', shared_text).group(1)
        cp = os.pathsep.join(map(str, JARS))
        shutil.copy2(GAME / "stdlib.lua", work / "stdlib.lua")

        def command(label, argv):
            done = subprocess.run(list(map(str, argv)), cwd=work, capture_output=True,
                text=True, encoding="utf-8", errors="replace", timeout=60)
            receipt["runs"].append({"name": label, "argv": list(map(str, argv)), "cwd": str(work),
                "exit": done.returncode, "stdout": done.stdout, "stderr": done.stderr})
            (out / "verification.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
            return done

        def execute(label, owner, body=BODY, identity=IDENTITY):
            caller = function_body(identity.read_text(encoding="utf-8-sig"), "Identity.markDead")
            if caller is None:
                raise RuntimeError("Owned Identity.markDead caller is absent")
            death = work / (label + "-identity.lua")
            death.write_text("local Identity = SAO.Identity\nlocal function log(_) end\nfunction Identity.markDead(" + caller + "end\n", encoding="utf-8")
            argv = [JDK / "java.exe", "-Duser.home=" + str(work), "-Djava.awt.headless=true",
                "--enable-native-access=ALL-UNNAMED", "-cp", str(work) + os.pathsep + cp,
                "ModMechanicsProbe", GAME, MOD, FIXTURES[0], owner, FIXTURES[1], *INSTALLED_LUA,
                FIXTURES[2], FIXTURES[3], SNAPSHOT, body, FIXTURES[4], death, FIXTURES[5]]
            return command(label, argv)

        try:
            done = command("compile", [JDK / "javac.exe", "-encoding", "UTF-8", "-cp", cp, "-d", work, *SOURCES])
            if done.returncode:
                raise RuntimeError("Native probe compilation failed: " + done.stderr[-4000:])
            done = execute("candidate", OWNER)
            checks = dict(re.findall(r"^CHECK ([a-z0-9_]+)=(true|false)$", done.stdout, re.M))
            expected = set(re.findall(r'check\("([a-z0-9_]+)"', "\n".join(p.read_text() for p in FIXTURES[1:])))
            if done.returncode or set(checks) != expected or any(v != "true" for v in checks.values()) or "MOD_MECHANICS_NATIVE_OK" not in done.stdout:
                raise RuntimeError(f"Native candidate exit {done.returncode}; missing {sorted(expected - set(checks))}; "
                    + done.stdout[-5000:] + done.stderr[-4000:])
            receipt["cases"] = len(checks)
            receipt["physical_cases"] = len(re.findall(r'check\("([a-z0-9_]+)"',
                "\n".join(p.read_text() for p in FIXTURES[1:3])))
            receipt["body_caller_cases"] = len(re.findall(r'check\("([a-z0-9_]+)"', FIXTURES[4].read_text()))
            receipt["death_caller_cases"] = len(re.findall(r'check\("([a-z0-9_]+)"', FIXTURES[5].read_text()))
            source = OWNER.read_text(encoding="utf-8-sig")
            for label, before, after, target in CONTROLS:
                if source.count(before) != 1:
                    raise RuntimeError(label + ": mutation anchor must match exactly once")
                changed = source.replace(before, after, 1)
                path = work / (label + ".lua")
                path.write_text(changed, encoding="utf-8")
                done = execute(label, path)
                if done.returncode == 0 or "CHECK " + target + "=false" not in done.stdout:
                    raise RuntimeError(label + ": named defect control did not fail: " + target)
                receipt["controls"].append({"name": label, "target": target, "verdict": "false",
                    "source_sha256": hashlib.sha256(changed.encode()).hexdigest()})
            source = BODY.read_text(encoding="utf-8-sig")
            for label, before, after, target in BODY_CONTROLS:
                if source.count(before) != 1:
                    raise RuntimeError(label + ": mutation anchor must match exactly once")
                changed = source.replace(before, after, 1)
                path = work / (label + ".lua")
                path.write_text(changed, encoding="utf-8")
                done = execute(label, OWNER, path)
                if done.returncode == 0 or "CHECK " + target + "=false" not in done.stdout:
                    raise RuntimeError(label + ": named defect control did not fail: " + target)
                receipt["controls"].append({"name": label, "target": target, "verdict": "false",
                    "owner": "production Body caller", "source_sha256": hashlib.sha256(changed.encode()).hexdigest()})
            source = IDENTITY.read_text(encoding="utf-8-sig")
            for label, before, after, target in IDENTITY_CONTROLS:
                if source.count(before) != 1:
                    raise RuntimeError(label + ": mutation anchor must match exactly once")
                changed = source.replace(before, after, 1)
                path = work / (label + ".lua")
                path.write_text(changed, encoding="utf-8")
                done = execute(label, OWNER, identity=path)
                if done.returncode == 0 or "CHECK " + target + "=false" not in done.stdout:
                    raise RuntimeError(label + ": named death-caller defect control did not fail: " + target)
                receipt["controls"].append({"name": label, "target": target, "verdict": "false",
                    "owner": "production Identity death caller", "source_sha256": hashlib.sha256(changed.encode()).hexdigest()})
            receipt["status"] = "passed"
        except Exception as failure:
            receipt["status"] = "failed"
            receipt["error"] = str(failure)
        receipt["inputs_after"] = {str(p.resolve()): digest(p) for p in inputs}
        receipt["inputs_unchanged"] = receipt["inputs_before"] == receipt["inputs_after"]
        if not receipt["inputs_unchanged"]:
            receipt["status"] = "failed"
            receipt["error"] = "Protected focused-test inputs changed during execution"
        (out / "verification.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: receipt.get(k) for k in ("status", "cases", "error", "inputs_unchanged")}))
        if receipt["status"] == "passed":
            print("CONTROLS", len(receipt["controls"]), "installed source/native engine; no game launch")
        return 0 if receipt["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
