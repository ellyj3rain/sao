#!/usr/bin/env python3
"""Installed-engine Week One gear transfer and selected Bandits source proof."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
JDK = Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
WORKSHOP = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600")
JAVA = ROOT / "java/src/com/sao/engine/SAONativeSnapshot.java"
PROBE = ROOT / "tools/weekone_material/WeekOneMaterialProbe.java"
PERSON = ROOT / "tools/luacheck/PersonSnapshotProbe.java"
SELECTED = {
    "Bandit.lua": WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/shared/Bandit.lua",
    "BanditWeapons.lua": WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/shared/BanditWeapons.lua",
    "BanditServerSpawner.lua": WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/server/BanditServerSpawner.lua",
    "ZAShoot.lua": WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/shared/ZombieActions/ZAShoot.lua",
    "ZALoad.lua": WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/shared/ZombieActions/ZALoad.lua",
    "BanditUpdate.lua": WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/client/BanditUpdate.lua",
    "ZABandage.lua": WORKSHOP / "3268487204/mods/Bandits/42.20/media/lua/shared/ZombieActions/ZABandage.lua",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command):
    done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
    return {"exit": done.returncode, "output": (done.stdout + done.stderr)[-6000:]}


def build_and_run(source, directory, cp):
    directory.mkdir(parents=True, exist_ok=True)
    copy = directory / "SAONativeSnapshot.java"
    copy.write_text(source, encoding="utf-8")
    built = run([str(JDK / "javac.exe"), "-cp", cp, "-d", str(directory),
        str(copy), str(PERSON), str(PROBE)])
    if built["exit"]:
        raise RuntimeError("material probe compilation failed: " + built["output"])
    result = run([str(JDK / "java.exe"), f"-Duser.home={directory}",
        "-cp", f"{directory};{cp}", "WeekOneMaterialProbe"])
    return result


def main():
    engine = GAME / "projectzomboid.jar"
    sao = ROOT / "mod/42.20/media/java/SAO.jar"
    if not all(path.is_file() for path in [engine, sao, JDK / "javac.exe", JAVA, PROBE, PERSON,
            *SELECTED.values()]):
        raise RuntimeError("installed engine, selected Bandits source, JDK or test input missing")
    source = JAVA.read_text(encoding="utf-8")
    selected_text = {name: path.read_text(encoding="utf-8") for name, path in SELECTED.items()}
    source_contract = {
        "Bandit.lua": ["function Bandit.UpdateItemsToSpawnAtDeath", "weapons.primary.bulletsLeft",
            "weapons.primary.magCount", "brain.permaInv", "brain.keys"],
        "BanditWeapons.lua": ["ret.type = \"mag\"", "ret.bulletsLeft = magSize",
            "ret.type = \"nomag\"", "ret.ammoCount = boxCount * boxSize - ammoSize"],
        "BanditServerSpawner.lua": ["brain.loot = {}", "brain.inventory = {}",
            "brain.permaInv = copyBrainData(args.permaInv)"],
        "ZAShoot.lua": ["weapon.bulletsLeft = weapon.bulletsLeft - 1"],
        "ZALoad.lua": ["weapon.clipIn = true", "weapon.magCount = weapon.magCount - 1"],
        "BanditUpdate.lua": ["bandit:setHealth(health - 0.00005)",
            "bandit:setHealth(health)"],
        "ZABandage.lua": ["zombie:setHealth(1.2)"],
    }
    for name, needles in source_contract.items():
        for needle in needles:
            if needle not in selected_text[name]:
                raise RuntimeError(f"selected Bandits source drifted: {name}: {needle}")
    receipt = {"selected": {name: sha(path) for name, path in SELECTED.items()},
        "sourceSha256": sha(JAVA), "probeSha256": sha(PROBE), "checks": {}}
    cp = f"{engine};{sao}"
    with tempfile.TemporaryDirectory(prefix="sao-weekone-material-") as temp:
        root = Path(temp)
        positive = build_and_run(source, root / "positive", cp)
        receipt["checks"]["positive"] = positive
        if positive["exit"] or "PASS Week One armed native inventory" not in positive["output"]:
            raise RuntimeError("armed native transfer failed: " + positive["output"])
        mutants = {
            "duplicate-display-gun": (
                "weekOneAdd(items, gun);\n        proxyTypes.add(name);",
                "weekOneAdd(items, gun);\n        // Missing disposable-source proxy recognition."),
            "lost-spare-magazines": (
                "weekOneAdd(items, mag);",
                "// Missing spare magazine transfer."),
            "healed-on-transfer": (
                "destination.getBodyDamage().ReduceGeneralHealth(sourceOverall - target);",
                "// Missing native general health reduction."),
        }
        for name, (old, new) in mutants.items():
            if source.count(old) != 1:
                raise RuntimeError("inverse control seam drifted: " + name)
            variant = build_and_run(source.replace(old, new, 1), root / name, cp)
            receipt["checks"][name] = variant
            if variant["exit"] == 0:
                raise RuntimeError("inverse control passed unexpectedly: " + name)
    receipt["status"] = "PASS"
    target = ROOT / "_scratch/d2-leisure-01/weekone21/material-transfer27.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("PASS Week One native armed inventory and health with 3 source inverses")


if __name__ == "__main__":
    main()
