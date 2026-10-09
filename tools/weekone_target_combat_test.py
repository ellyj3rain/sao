#!/usr/bin/env python3
"""Installed Kahlua checks for Week One player-specific physical combat."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
PATCHES = Path(r"C:\Users\jleyv\Peanut Butter\AI Assisted Software Engineering Mass Repository\Projects\mod-patches")
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
BANDITS = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3268487204\mods\Bandits\42.20\media\lua")
SOURCE = ROOT / "mod/42.20/media/lua/client/SAO_WeekOneTargetCombat.lua"
CASES = ROOT / "tools/weekone_target_combat_cases.lua"
PATCH = PATCHES / "patches/010-weekone-player-combat/patch.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
OUT = ROOT / "_scratch/d2-leisure-01/weekone21/target-combat.json"
SOURCE_PINS = {
    "client/BanditUpdate.lua": "acf22fa36ccb54ae305eb41b17a58a0608b250851332b8d1a29cc2259423e3e8",
    "shared/BanditBrain.lua": "e04fc4112d9bcd112e5922c002d6550bf54b8e21b9a1272a0a7d1773befc27e4",
    "shared/BanditUtils.lua": "ab65995505dd93e1cd6be0d4f8cf0eda973736fbd30f68f62a0af9203038cf69",
    "shared/ZombieActions/ZASmack.lua": "2bceb5ef27fffe9262f4881c29a5727b8ddd11ee2bbd5e4931bac8e972aa37b0",
    "shared/ZombieActions/ZAPush.lua": "dcaa80fd559a2f5bf1f28c42bd6ef4b2ffec634a4ae22dcf47e09ed1679853ac",
    "shared/ZombieActions/ZAShoot.lua": "81d5f2427943d072682aa0d536f333fb9ac391f3a2ca832226f5228562bdf48a",
    "shared/PlayerDamageModel.lua": "c8811516bcf9e62908d22a40230cd5d569ae96e1b71d5d4948eba9c93b768108",
    "client/BanditPlayer.lua": "98f59643b2532cc310e565abe9529075805e4c0fd382f28b47b6b2886c3d4c1f",
}

CONTROLS = [
    ("source-hostile-branch", "brain.hostile = false",
     "brain.hostile = brain.hostile", "source global player loop retained stamped hostility"),
    ("source-hostile-p-branch", "brain.hostileP = false",
     "brain.hostileP = brain.hostileP", "source global player loop retained stamped hostility"),
    ("source-reassertion", "if brain.hostile == true or brain.hostileP == true then",
     "if false then", "source reassertion survived the next brain read"),
    ("source-body-quarantine", "and marker.SAOWeekOneBorn == brain.born",
     "and true", "body marker mismatch did not enter source quarantine"),
    ("replaced-source-get", "and BanditBrain.Get == wrapped.brainGet",
     "and true", "replaced source brain gate still reported ready"),
    ("different-player", "return decided and hostile == true",
     "return decided", "non-target player received hostile permission"),
    ("same-group", "and (actorGroup == nil or actorGroup ~= targetGroup)",
     "and true", "same-group player received hostile permission"),
    ("stale-body", "or marker.SAOWeekOneBorn ~= brain.born",
     "or false", "changed source body retained combat permission"),
    ("action-gate", "if allowed ~= true then return true end",
     "if false then return true end", "non-target player passed melee action boundary"),
    ("bullet-gate", "if permission ~= true then return false end",
     "if false then return false end", "bullet did not separate target from bystander"),
    ("line-target", "and T.canAttackPlayer(body, enemy) ~= true then return false end",
     "and false then return false end", "non-target player passed line-of-fire boundary"),
    ("incendiary", 'if kind ~= "foreign" and incendiary == true then',
     'if kind ~= "foreign" and false then',
     "incendiary ray bypassed bystander permission"),
    ("replaced-action", "if group[name] ~= replacement then return false end",
     "if false then return false end",
     "replaced physical gate still reported ready"),
    ("physical-reach", "or distance > reach + 0.1 then",
     "or false then", "out-of-range player received a melee task"),
    ("duplicate-player-id", "if matches > 1 then return nil, true end",
     "if matches > 1 then return player, false end",
     "duplicate source player ID passed melee boundary"),
    ("zombie-id-task", "if BanditZombie.Cache[eid] then return nil, \"source-id-collision\" end",
     "if false then return nil, \"source-id-collision\" end",
     "source zombie ID collision produced a player attack task"),
    ("zombie-id-action", "and BanditZombie.Cache[task.eid] then return nil, true end",
     "and false then return nil, true end",
     "source zombie ID collision passed player action boundary"),
    ("private-position", "or math.floor(sx) ~= seen.x",
     "or false", "moved target reused stale private sight"),
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def call(args: list[object], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(a) for a in args], cwd=cwd,
                          capture_output=True, text=True, timeout=120)


def main() -> int:
    for path in (SOURCE, CASES, PATCH, RUNNER, GAME / "projectzomboid.jar",
                 GAME / "stdlib.lua", JDK / "java.exe", JDK / "javac.exe"):
        if not path.is_file():
            raise RuntimeError(f"required source or installed engine missing: {path}")
    for relative, expected in SOURCE_PINS.items():
        path = BANDITS / relative
        if not path.is_file() or digest(path) != expected:
            raise RuntimeError(f"selected Bandits2 source changed: {path}")
    selected = {name: (BANDITS / name).read_text(encoding="utf-8-sig")
                for name in SOURCE_PINS}
    combat = selected["client/BanditUpdate.lua"].split(
        "local function ManageCombat(bandit)", 1)[1]
    source_read = combat.index("local brain = BanditBrain.Get(bandit)")
    player_loop = combat.index("if brain.hostile or brain.hostileP then")
    assert source_read < player_loop
    assert "brain.hostile =" not in combat[source_read:player_loop]
    assert "brain.hostileP =" not in combat[source_read:player_loop]
    assert "function BanditBrain.Get(zombie)" in selected["shared/BanditBrain.lua"]
    assert "return modData.brain" in selected["shared/BanditBrain.lua"]
    assert 'local task = {action="Smack"' in selected["client/BanditUpdate.lua"]
    assert 'local task = {action="Push"' in selected["client/BanditUpdate.lua"]
    assert 'local task = {action="Shoot"' in selected["shared/ZombieActions/ZAShoot.lua"] or \
        'BanditUtils.ManageLineOfFire(shooter, enemy, weaponItem)' in \
        selected["shared/ZombieActions/ZAShoot.lua"]
    assert 'PlayerDamageModel.BulletHit(shooter, item, victim)' in \
        selected["shared/BanditUtils.lua"]
    assert 'if Bandit.IsHostile(bandit) then' in selected["shared/ZombieActions/ZASmack.lua"]
    assert 'BanditZombie.Cache[task.eid] or BanditPlayer.GetPlayerById(task.eid)' in \
        selected["shared/ZombieActions/ZASmack.lua"]
    assert 'if Bandit.IsHostile(bandit) then' in selected["shared/ZombieActions/ZAPush.lua"]
    original = SOURCE.read_text(encoding="utf-8")
    receipt = {"status": "INCOMPLETE", "sourcePins": {
        str(path): digest(path) for path in (SOURCE, CASES, PATCH, RUNNER)},
        "installedSourcePins": SOURCE_PINS,
        "sourceBoundary": "Installed Bandits2 42.20 action shapes; source physical callbacks mocked under installed Kahlua, native game and multiplayer still unobserved",
        "checks": []}
    with tempfile.TemporaryDirectory(prefix="sao-target-combat-") as temp:
        work = Path(temp)
        (work / "stdlib.lua").write_bytes((GAME / "stdlib.lua").read_bytes())
        build = call([JDK / "javac.exe", "-cp", GAME / "projectzomboid.jar",
                      "-d", work, RUNNER], work)
        if build.returncode:
            raise RuntimeError("installed Kahlua runner compile: " + build.stderr)

        def run(name: str, source: str) -> str:
            candidate = work / "candidate.lua"
            candidate.write_text(source, encoding="utf-8")
            done = call([JDK / "java.exe", "-cp",
                         f"{GAME / 'projectzomboid.jar'};{work}",
                         "LuaRun", CASES, candidate, PATCH, "--",
                         "__safeTargetCombat()"], work)
            output = done.stdout + done.stderr
            receipt["checks"].append({"name": name, "exitCode": done.returncode,
                                      "output": output[-1400:]})
            if done.returncode:
                raise RuntimeError(name + ": " + output)
            return output

        current = run("current", original)
        if "VALUE PASS" not in current:
            raise RuntimeError("current target combat failed: " + current)
        for name, before, after, failure in CONTROLS:
            if original.count(before) != 1:
                raise RuntimeError(f"inverse anchor drift: {name}")
            result = run(name, original.replace(before, after, 1))
            if "VALUE FAIL:" not in result or failure not in result:
                raise RuntimeError(f"{name} did not fail for its contract: {result}")
    receipt["status"] = "PASS"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"PASS Week One exact player combat, {len(CONTROLS)} inverses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
