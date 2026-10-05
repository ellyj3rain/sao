"""Installed combat admission/pressedAttack and controlled native custody; not a rendered combat trial."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import argparse
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(os.environ.get("PZ_DIR", r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = Path(os.environ.get("JDK_BIN", r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))
SOURCES = [ROOT / name for name in (
    "java/src/com/sao/engine/SAOCombat.java",
    "java/src/com/sao/engine/SAOPerceptionScanner.java",
    "java/src/com/sao/bridge/SAOBridge.java",
    "tools/javacheck/ConflictNativeProbe.java",
    "tools/javacheck/ConflictNativeAgent.java",
    "tools/luacheck/MovementCrossingProbe.java",
    "tools/orienting_checks/OrientationProbe.java",
)]


def run(only=None):
    out = ROOT / "_scratch/d1-shared-reasoning/conflict/native" / datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
    out.mkdir(parents=True)
    jars = [GAME / "projectzomboid.jar", GAME / "ZombieBuddy.jar", ROOT / "mod/42.20/media/java/SAO.jar"]
    files = [*SOURCES, Path(__file__), *jars, GAME / "media/scripts/generated/items/weapon.txt",
             *[GAME / f"media/anims_X/Bob/{name}.x" for name in ("Bob_LookLeft", "Bob_LookRight", "Bob_LookDown", "Bob_LookUp", "Bob_Idle", "Bob_Walk")]]
    files.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(files, GAME, JDK, "conflict native")
    if preflight is not None:
        raise SystemExit(preflight)
    def pins():
        return {str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    receipt = {"schema": "sao.conflict-native-proof/1", "status": "INCOMPLETE", "boundary": __doc__, "inputs": pins(), "variants": []}
    def save():
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    save()
    cp = os.pathsep.join(map(str, jars))
    variants = [
        ("production", None, None, None, None),
        ("ordinary-token-shape", "SAOCombat.java", 'if (SAOConceptObservation.actor(body) == null) return refused("body-unavailable");', 'if (SAOConceptObservation.actor(body) == null || body.getModData().rawget("SAOExternalToken") == null) return refused("body-unavailable");', "ordinary_tokenless_unarmed_shove"),
        ("wrong-observer-key", "SAOPerceptionScanner.java", 'if (!key.equals(entry.getValue())) continue;', 'if (false) continue;', "observer_private_token"),
        ("stale-visibility", "SAOPerceptionScanner.java", '|| !canSeePersonNow(observer, found, RANGE)', '|| false', "fresh_observation_resolver_sight"),
        ("held-weapon-no-shove", "SAOCombat.java", 'boolean shove = shoveReach > 0', 'boolean shove = held == null && shoveReach > 0', "held_weapon_shove_available"),
        ("ammo-without-chamber", "SAOCombat.java", 'held.haveChamber() ? held.isRoundChambered() && !held.isSpentRoundChambered()', 'held.haveChamber() ? held.getCurrentAmmoCount() > 0', "magazine_not_chamber"),
        ("pending-crossing-stolen", "SAOCombat.java", '|| body.getActionContext().hasEventOccurred("EventClimbFence")', '|| false', "pending_crossing_not_stolen"),
        ("weapon-swap", "SAOCombat.java", '|| shell.getPrimaryHandItem() != observedWeapon', '|| false', "weapon_swap_revalidated"),
        ("skip-native-request", "SAOCombat.java", '            shell.pressedAttack();\n        } catch (Throwable error)', '            // defective skipped native request\n        } catch (Throwable error)', "native_unarmed_request"),
        ("cancel-active-shove", "SAOCombat.java", '|| body.isPerformingShoveAnimation()', '|| false', "cancel_holds_native_animation"),
        ("bridge-drops-held-owner", "SAOBridge.java", 'if (combat.isBounded() && "COMBAT_HELD".equals(combat.cancelObserved()))', 'if (false)', "reset_holds_native_animation"),
        ("unattributed-damage-credit", "SAOCombat.java", 'COMBAT_COMPLETED attempt=1 outcome=unattributed', 'COMBAT_SUCCEEDED damageObserved=true', "completion_not_damage_credit"),
        ("successor-token", "SAOCombat.java", 'Objects.equals(actorToken, shell.getModData().rawget("SAOExternalToken"))', 'true', "changed_owner_not_cleared"),
        ("ambiguous-person", "SAOPerceptionScanner.java", 'if (found != null && found != entry.getKey()) return null;', 'if (false) return null;', "ambiguous_person_not_substituted"),
        ("stomp-standing-target", "SAOCombat.java", '&& (other.isOnFloor() || SAOPerceptionScanner.isProneOrCrawling(other));', '&& true;', "standing_target_not_stomp"),
        ("stomp-reach", "SAOCombat.java", 'Math.min(shoveReach, .6f)', 'shoveReach', "stomp_uses_native_close_reach"),
        ("stomp-authorization", "SAOCombat.java", 'shell.setAuthorizedHandToHand(handToHand || priorHandToHand);', 'shell.setAuthorizedHandToHand(shove || priorHandToHand);', "native_exact_stomp_request"),
        ("stomp-cancel-animation", "SAOCombat.java", '|| body.isPerformingStompAnimation()', '|| false', "stomp_cancellation_waits"),
        ("stomp-target-substitution", "SAOCombat.java", '|| shell.targetOnGround != target', '|| false', "stomp_exact_native_target"),
    ]
    if only:
        assert set(only) <= {v[0] for v in variants}, "unknown variant"
        variants = [v for v in variants if v[0] in only]
    receipt["selectedVariants"] = [v[0] for v in variants]
    for name, source_name, old, new, expected in variants:
        target = out / name
        target.mkdir()
        sources = SOURCES.copy()
        if old:
            source = next(p for p in sources if p.name == source_name)
            text = source.read_text(encoding="utf-8")
            assert text.count(old) == 1, name
            candidate = target / source.name
            candidate.write_text(text.replace(old, new, 1), encoding="utf-8")
            sources[sources.index(source)] = candidate
        compile_cmd = [JDK / "javac.exe", "-encoding", "UTF-8", "-cp", cp, "-d", target, *sources]
        compiled = subprocess.run(list(map(str, compile_cmd)), capture_output=True, text=True, timeout=120)
        (target / "compile.log").write_text(compiled.stdout + compiled.stderr, encoding="utf-8")
        assert compiled.returncode == 0, compiled.stdout + compiled.stderr
        manifest = target / "MANIFEST.MF"
        manifest.write_text("Manifest-Version: 1.0\nPremain-Class: ConflictNativeAgent\n\n", encoding="utf-8")
        agent = target / "probe-agent.jar"
        jar_cmd = [JDK / "jar.exe", "cfm", agent, manifest, "-C", target, "ConflictNativeAgent.class"]
        subprocess.run(list(map(str, jar_cmd)), check=True, capture_output=True, timeout=30)
        command = [JDK / "java.exe", "-javaagent:" + str(agent), "-Duser.home=" + str(target),
                   "-Djava.awt.headless=true", "-Djava.library.path=" + str(GAME),
                   "-cp", str(target) + os.pathsep + cp, "ConflictNativeProbe", GAME]
        result = subprocess.run(list(map(str, command)), cwd=GAME, capture_output=True, text=True, timeout=90)
        log = result.stdout + result.stderr
        (target / "run.log").write_text(log, encoding="utf-8")
        receipt["variants"].append({"name": name, "exit": result.returncode, "expectedFailure": expected,
            "command": list(map(str, command)), "logSha256": hashlib.sha256(log.encode()).hexdigest(),
            "checks": log.count("CHECK "), "classes": {str(p.relative_to(target)): hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob("*.class")}})
        save()
        assert (result.returncode != 0 and "CONFLICT:" + expected in log) if expected else (result.returncode == 0 and "PASS conflict native" in log), log
        print(name + ": " + (expected or next(line for line in log.splitlines() if line.startswith("PASS conflict native"))), flush=True)
    receipt["inputsAfter"] = pins()
    assert receipt["inputsAfter"] == receipt["inputs"], "proof inputs changed"
    receipt["status"] = "PASS"
    save()
    print("receipt=" + str(out / "receipt.json"))


if __name__ == "__main__":
    try:
        parser=argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--only",nargs="+")
        run(parser.parse_args().only)
    except Exception as error:
        print("FAIL conflict native: " + str(error), file=sys.stderr)
        raise SystemExit(1)
