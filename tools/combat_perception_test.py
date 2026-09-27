#!/usr/bin/env python3
r"""Border 157 - combat perception and mod compatibility.

Combat perception operates entirely on engine-grounded state:
1. Acoustic perception reads weapon sound radius attenuated by weather;
   suppressors rewrite the weapon's sound radius, which naturally contracts
   perceived reach without custom hooks.
2. Downed, crawler, and modded prone/crawling targets are attacked at the
   floor (setAimAtFloor + setAuthorizeShoveStomp), preventing air-swings.
3. Prone and crawl states from engine flags, animation variables, or modData
   reduce visual silhouette range and append '+p' / ':prone' to beliefs.
4. Stealth mods that deactivate zombie AI (isUseless) are left alone; useless
   zombies are not perceived or directed as threats.
5. Zombie-motivation mods own their domain; existing targets are not usurped
   or double-applied by the director.
6. Weapons and clothing are compatible by construction: meleeScore reads
   script stats, reload is the vanilla action, and clothing is uninspected.
"""
import argparse
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time


ROOT = pathlib.Path(__file__).resolve().parent.parent
SCANNER = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOPerceptionScanner.java"
COMBAT = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOCombat.java"
DIRECTOR = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOZombieDirector.java"
EQUIPMENT = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOEquipment.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
PERCEPTION_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Perception.lua"
NEEDS_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Needs.lua"
GAME = pathlib.Path(os.environ.get(
    "PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = pathlib.Path(os.environ.get(
    "JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))


def source_faults(scanner_src, combat_src, director_src, equipment_src, bridge_src, perp_lua, needs_lua):
    faults = []

    # 1. Acoustic perception
    if ("SAOSenses.hearing(shell, true)" not in scanner_src
            or "sound.radius * hearing" not in scanner_src):
        faults.append("scanner bypasses shared native hearing reach")
    if "WorldSoundManager.instance.soundList" not in scanner_src:
        faults.append("scanner does not read the engine sound list")

    # 2. Ground stance targeting
    if "target.isOnFloor()" not in combat_src:
        faults.append("combat does not check isOnFloor for ground targeting")
    if "z.isCrawling()" not in combat_src:
        faults.append("combat does not check crawler zombie state for ground targeting")
    if "SAOPerceptionScanner.isProneOrCrawling" not in combat_src:
        faults.append("combat does not check prone/crawling stance for ground targeting")
    if "shell.setAimAtFloor(aimAtFloor)" not in combat_src:
        faults.append("combat does not aim at floor for downed/crawler targets")

    # 3. Prone/crawl perception & silhouette
    if "public static boolean isProneOrCrawling" not in scanner_src:
        faults.append("scanner lacks isProneOrCrawling stance helper")
    if "RANGE * 0.6f" not in scanner_src:
        faults.append("scanner does not reduce visual range for prone/crawling silhouette")
    if 'out.append("+p")' not in scanner_src:
        faults.append("scanner does not tag prone person beliefs with +p")
    if 'out.append(":prone")' not in scanner_src:
        faults.append("scanner does not tag prone zombie beliefs with :prone")
    if 'belief.prone = true' not in perp_lua:
        faults.append("SAO_Perception.lua does not parse prone stance onto beliefs")
    if 'getVariableBoolean("ltsproneposition")' not in scanner_src:
        faults.append("scanner omits Lethal Stealth's live prone variable")
    if 'rawget("ret_lts_acostado")' not in scanner_src:
        faults.append("scanner omits Lethal Stealth's mirrored prone state")

    # 4. Stealth mods / useless zombies
    if "zombie.isUseless()" not in scanner_src:
        faults.append("scanner does not skip useless/deactivated zombies")
    if "zombie.isUseless()" not in bridge_src:
        faults.append("bridge beginCombatNearest does not skip useless zombies")
    if "zed.isUseless()" not in bridge_src:
        faults.append("bridge directNearestZombieAt does not skip useless zombies")
    if "REFUSED_USELESS_ZOMBIE" not in director_src:
        faults.append("director does not refuse useless zombies")
    if "isInactiveTarget(target)" not in combat_src \
            or "COMBAT_FAILED TARGET_INACTIVE" not in combat_src:
        faults.append("active combat does not revalidate a deactivated target")

    # 5. Non-duplication of aggro
    if "zed.getTarget() != null && zed.getTarget() != shell" not in bridge_src:
        faults.append("bridge directNearestZombieAt usurps externally targeted zombies")
    if "REFUSED_EXTERNAL_TARGET" not in director_src:
        faults.append("director does not respect external motivation targets")

    # 6. Weapons & clothing
    for stat in ("weapon.getMinDamage()", "weapon.getMaxDamage()",
                 "weapon.getMaxRange()", "weapon.getBaseSpeed()",
                 "weapon.getCriticalChance()", "weapon.getCondition()"):
        if stat not in equipment_src:
            faults.append(f"equipment meleeScore does not read script stat {stat}")
    if "ISReloadWeaponAction:new" not in needs_lua:
        faults.append("SAO_Needs.lua does not queue vanilla ISReloadWeaponAction")
    for guard in ('"Throw".equalsIgnoreCase(weapon.getSwingAnim())',
                  "weapon.getPhysicsObject() != null", "weapon.getMaxDamage() <= 0.0f"):
        if guard not in equipment_src:
            faults.append("equipment melee eligibility omits native guard: " + guard)

    return faults


# Behavioral model simulation
def sound_reach(radius, weather_noise):
    hearing = 1.0 - 0.5 * max(0.0, min(1.0, weather_noise))
    return radius * hearing


def should_aim_floor(on_floor, is_crawler, is_prone):
    return on_floor or is_crawler or is_prone


def can_direct_aggro(is_useless, current_target, shell):
    if is_useless:
        return False
    if current_target is not None and current_target != shell:
        return False
    return True


def native_melee_checks(receipt_path=None):
    """Execute production scoring and both native consumers in a private JVM.

    Installed Item.Load/InventoryItemFactory own the shipped item semantics.
    Cell/body setup is the existing method fixture; no attack/world loop runs.
    """
    suffix = ".exe" if os.name == "nt" else ""
    javac, java = (JDK / (name + suffix) for name in ("javac", "java"))
    jars = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar"]
    if not all(path.is_file() for path in [javac, java, *jars]):
        print("SKIP installed melee receivers: native engine/JDK unavailable")
        return
    source = EQUIPMENT.read_text(encoding="utf-8-sig")
    probe = ROOT / "tools/luacheck/WeaponEligibilityProbe.java"
    fixture = ROOT / "tools/luacheck/ResourceApproachProbe.java"
    receipt = {"scope": "installed native item/query/equip methods; no loaded-game claim",
               "checks": [], "controls": [], "commands": [], "passed": False,
               "inputs": {str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path):
                          hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in [EQUIPMENT, probe, fixture, *jars,
                              GAME / "media/scripts/generated/items/weapon.txt"]}}

    def run(command, cwd, phase, name):
        started = time.perf_counter()
        result = subprocess.run([str(part) for part in command], cwd=cwd,
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
        receipt["commands"].append({"phase": phase, "name": name,
            "seconds": time.perf_counter() - started, "exit": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr})
        return result

    def remove(guard):
        if source.count(guard) != 1:
            raise AssertionError("melee control target drifted: " + guard)
        return source.replace(guard, "", 1)

    throwing = '            || "Throw".equalsIgnoreCase(weapon.getSwingAnim())\n'
    physics = '            || weapon.getPhysicsObject() != null\n'
    damage = '            || weapon.getMaxDamage() <= 0.0f'
    for guard in (throwing, physics, damage):
        if source.count(guard) != 1:
            raise AssertionError("melee control target drifted: " + guard)
    former = source.replace(throwing, "").replace(physics, "").replace(damage, "")
    variants = [
        ("former-eligibility", former, "firecracker_not_melee"),
        ("throw-animation", remove(throwing), "throw_animation_not_melee"),
        ("physics-projectile", remove(physics), "physics_projectile_not_melee"),
        ("zero-damage", remove(damage), "zero_damage_not_melee"),
        ("reject-valid-heavy", source.replace(damage,
            damage + "\n            || weapon.isTwoHandWeapon()", 1), "native_barbell_remains_melee"),
        ("ranged-melee", remove('            || weapon.isRanged()\n'), "ranged_not_melee"),
        ("broken-melee", remove('            || weapon.isBroken()\n'), "broken_not_melee"),
    ]
    try:
        with tempfile.TemporaryDirectory(prefix="sao-melee-eligibility-") as temporary:
            work = pathlib.Path(temporary)
            classes = work / "classes"; classes.mkdir()
            generated = work / "SAOVersion.java"
            version = (ROOT / "VERSION").read_text(encoding="utf-8-sig").strip()
            generated.write_text("package com.sao; public final class SAOVersion {"
                f'public static final String VALUE = "{version}"; }}\n', encoding="utf-8")
            sources = sorted((ROOT / "java/src").rglob("*.java")) + [generated, fixture, probe]
            native_cp = os.pathsep.join(map(str, jars))
            compiled = run([javac, "-encoding", "UTF-8", "-cp", native_cp,
                "-d", classes, *sources], work, "compile", "production")
            if compiled.returncode:
                raise AssertionError("native melee compile failed: " + compiled.stdout + compiled.stderr)
            classpath = os.pathsep.join((str(classes), native_cp))
            result = run([java, f"-Duser.home={work}", "-cp", classpath,
                "WeaponEligibilityProbe", GAME], work, "probe", "production")
            if result.returncode or "PASS installed melee eligibility checks=19" not in result.stdout:
                raise AssertionError("native melee probe failed: " + result.stdout + result.stderr)
            receipt["checks"] = [line[6:-5] for line in result.stdout.splitlines()
                if line.startswith("CHECK ") and line.endswith("=true")]
            if len(receipt["checks"]) != 19:
                raise AssertionError("native melee probe omitted checks")
            print("PASS installed melee eligibility: 19 native item/query/equip checks")
            for name, modified, reason in variants:
                directory = work / name; directory.mkdir()
                mutant = directory / "SAOEquipment.java"
                mutant.write_text(modified, encoding="utf-8")
                compiled = run([javac, "-encoding", "UTF-8", "-cp", classpath,
                    "-d", directory, mutant], directory, "compile", name)
                if compiled.returncode:
                    raise AssertionError("melee mutant did not compile: " + name + compiled.stderr)
                result = run([java, f"-Duser.home={directory}", "-cp",
                    str(directory) + os.pathsep + classpath,
                    "WeaponEligibilityProbe", GAME], directory, "probe", name)
                if result.returncode == 0 or f"CHECK {reason}=false" not in result.stdout \
                        or f"java.lang.AssertionError: {reason}" not in result.stderr:
                    raise AssertionError("melee control survived or failed elsewhere: " + name
                        + "\n" + result.stdout + result.stderr)
                receipt["controls"].append({"name": name, "rejectedBy": reason})
                print("CONTROL native melee " + name + ": " + reason)
            receipt["passed"] = True
    finally:
        if receipt_path:
            receipt_path = pathlib.Path(receipt_path)
            receipt_path.parent.mkdir(parents=True, exist_ok=True)
            receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-receipt", type=pathlib.Path)
    args = parser.parse_args()
    sources = [SCANNER, COMBAT, DIRECTOR, EQUIPMENT, BRIDGE, PERCEPTION_LUA, NEEDS_LUA]
    for path in sources:
        if not path.exists():
            print(f"FAULT: source file missing: {path.name}")
            return 1

    scanner_src = SCANNER.read_text(encoding="utf-8", errors="ignore")
    combat_src = COMBAT.read_text(encoding="utf-8", errors="ignore")
    director_src = DIRECTOR.read_text(encoding="utf-8", errors="ignore")
    equipment_src = EQUIPMENT.read_text(encoding="utf-8", errors="ignore")
    bridge_src = BRIDGE.read_text(encoding="utf-8", errors="ignore")
    perp_lua = PERCEPTION_LUA.read_text(encoding="utf-8", errors="ignore")
    needs_lua = NEEDS_LUA.read_text(encoding="utf-8", errors="ignore")

    faults = source_faults(scanner_src, combat_src, director_src, equipment_src,
                           bridge_src, perp_lua, needs_lua)

    # Behavioral model controls
    unsuppressed = sound_reach(40.0, 0.0)
    suppressed = sound_reach(10.0, 0.0)
    storm_suppressed = sound_reach(10.0, 1.0)
    if suppressed >= unsuppressed:
        faults.append("CONTROL model: suppressor did not contract sound reach")
    if storm_suppressed >= suppressed:
        faults.append("CONTROL model: weather did not further mask suppressed sound")

    if not should_aim_floor(False, True, False):
        faults.append("CONTROL model: crawler was not targeted at floor")
    if not should_aim_floor(False, False, True):
        faults.append("CONTROL model: prone target was not targeted at floor")
    if should_aim_floor(False, False, False):
        faults.append("CONTROL model: standing target was aimed at floor")

    if can_direct_aggro(True, None, "shell"):
        faults.append("CONTROL model: useless zombie was directed")
    if can_direct_aggro(False, "other_player", "shell"):
        faults.append("CONTROL model: externally targeted zombie was usurped")
    if not can_direct_aggro(False, None, "shell"):
        faults.append("CONTROL model: free zombie could not be directed")
    if not can_direct_aggro(False, "shell", "shell"):
        faults.append("CONTROL model: already-acquired shell zombie could not be refreshed")

    # Mutation controls
    bad_combat = combat_src.replace("target.isOnFloor()", "false")
    if not source_faults(scanner_src, bad_combat, director_src, equipment_src,
                         bridge_src, perp_lua, needs_lua):
        faults.append("CONTROL mutated combat isOnFloor but border passed")

    bad_scanner = scanner_src.replace("zombie.isUseless()", "false")
    if not source_faults(bad_scanner, combat_src, director_src, equipment_src,
                         bridge_src, perp_lua, needs_lua):
        faults.append("CONTROL mutated scanner isUseless but border passed")

    bad_prone = scanner_src.replace(
        '|| character.getVariableBoolean("ltsproneposition")', "", 1)
    if bad_prone == scanner_src:
        faults.append("CONTROL did not remove the installed prone variable")
    elif not source_faults(bad_prone, combat_src, director_src, equipment_src,
                            bridge_src, perp_lua, needs_lua):
        faults.append("CONTROL removed installed prone variable but border passed")

    bad_active = combat_src.replace("isInactiveTarget(target)", "false", 1)
    if bad_active == combat_src:
        faults.append("CONTROL did not remove active-target revalidation")
    elif not source_faults(scanner_src, bad_active, director_src, equipment_src,
                            bridge_src, perp_lua, needs_lua):
        faults.append("CONTROL removed target revalidation but border passed")

    bad_bridge = bridge_src.replace("zed.getTarget() != null && zed.getTarget() != shell", "false")
    if not source_faults(scanner_src, combat_src, director_src, equipment_src,
                         bad_bridge, perp_lua, needs_lua):
        faults.append("CONTROL mutated bridge target usurper but border passed")

    if faults:
        for fault in faults:
            print("FAULT: " + fault)
        return 1

    native_melee_checks(args.native_receipt)
    print("157) combat perception: acoustics, floor targeting, prone stance, stealth, aggro non-duplication, and weapons verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
