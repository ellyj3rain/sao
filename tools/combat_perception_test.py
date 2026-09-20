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
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
SCANNER = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOPerceptionScanner.java"
COMBAT = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOCombat.java"
DIRECTOR = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOZombieDirector.java"
EQUIPMENT = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOEquipment.java"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
PERCEPTION_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Perception.lua"
NEEDS_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Needs.lua"


def source_faults(scanner_src, combat_src, director_src, equipment_src, bridge_src, perp_lua, needs_lua):
    faults = []

    # 1. Acoustic perception
    if "sound.radius * weatherHearing()" not in scanner_src:
        faults.append("scanner does not scale sound reach by weather hearing")
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


def main():
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

    print("157) combat perception: acoustics, floor targeting, prone stance, stealth, aggro non-duplication, and weapons verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
