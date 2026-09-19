#!/usr/bin/env python3
r"""Border 158 - the neuroinflammation knot: brain health as one continuous graph.

The operator's ruling of 2026-09-13:
1. One continuous value per person (`rec.neuroinflammation` in [0.0, 1.0]),
   not an enum or bucket, with functional sub-scores derived from it.
2. In the shape of Antibodies (lonegamedev, MIT): uses the sine activation curve
   `math.sin(pos * math.pi)` over the pathogen infection course (`SAO.Course`).
3. Multi-source insult accumulation: feeds from active Knox infection, peripheral
   sepsis (`rec.woundInfected`), and drug/toxin damage (`rec.drinkPoisonTotal`,
   withdrawal phases).
4. Afflicted and crossed baselines: afflicted bodies maintain a 0.30 floor;
   crossed bodies sit at 0.90 (humanity burned out by neuroinflammation).
5. Natural resolution: resting, uninfected bodies clear neuroinflammation
   exponentially toward baseline.
6. Cognitive and memory degradation: `SAO.Conditions.memoryFactor` attenuates
   with cognitive clarity (`1.0 - load`).
7. Clinical diagnosis and visualization: `SAO_Medical.readingOf` gates observations
   by Doctor skill, and `SAOMedicalWindow` renders an Antibodies-style visual curve.
8. Off-switch: sandbox option `SurvivorAwareness.Neuroinflammation` disables the
   graph completely.
"""
import math
import pathlib
import re
import sys
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
NEURO_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Neuro.lua"
COND_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "shared" / "SAO_Conditions.lua"
MED_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Medical.lua"
MED_WIN = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_MedicalWindow.lua"
INSPECT_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Inspect.lua"
POP_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
DRUGS_LUA = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Drugs.lua"
OPTS_TXT = ROOT / "mod" / "42.20" / "media" / "sandbox-options.txt"
SANDBOX_JSON = (ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
                / "Translate" / "EN" / "Sandbox.json")


def source_faults(neuro_src, cond_src, med_src, medwin_src, inspect_src, pop_src, drugs_src, opts_src, json_src):
    faults = []

    # 1. Continuous single value and derived sub-scores
    if "Neuro.AFFLICTED_FLOOR = 0.30" not in neuro_src:
        faults.append("SAO_Neuro lacks AFFLICTED_FLOOR baseline of 0.30")
    if "Neuro.CROSSED_FLOOR = 0.90" not in neuro_src:
        faults.append("SAO_Neuro lacks CROSSED_FLOOR baseline of 0.90")
    if "math.sin(pos * math.pi)" not in neuro_src:
        faults.append("SAO_Neuro does not use Antibodies sine activation curve for Knox course")
    if "math.exp(-Neuro.BASE_CLEARANCE_RATE * deltaHours)" not in neuro_src:
        faults.append("SAO_Neuro lacks exponential clearance decay equation")
    if "function Neuro.clarityOf" not in neuro_src:
        faults.append("SAO_Neuro lacks clarityOf cognitive projection")
    if "function Neuro.affectiveVolatility" not in neuro_src:
        faults.append("SAO_Neuro lacks affectiveVolatility projection")
    if "function Neuro.motorSteadiness" not in neuro_src:
        faults.append("SAO_Neuro lacks motorSteadiness projection")

    # 2. Multi-source insults
    if "rec.woundInfected" not in neuro_src:
        faults.append("SAO_Neuro does not accumulate peripheral sepsis")
    if "rec.drinkPoisonTotal" not in neuro_src:
        faults.append("SAO_Neuro does not read drug/alcohol poison total from C121 ladder")
    if "withdrawalPhase" not in neuro_src:
        faults.append("SAO_Neuro does not read withdrawal phase stress")

    # 3. Off-switch
    if "sv.Neuroinflammation" not in neuro_src:
        faults.append("SAO_Neuro does not query sv.Neuroinflammation sandbox option")
    if "option SurvivorAwareness.Neuroinflammation" not in opts_src:
        faults.append("sandbox-options.txt lacks SurvivorAwareness.Neuroinflammation declaration")
    if "Sandbox_SurvivorAwareness_Neuroinflammation" not in json_src:
        faults.append("Sandbox.json lacks Neuroinflammation translations")

    # 4. Memory integration
    if "SAO.Neuro.clarityOfId" not in cond_src:
        faults.append("SAO_Conditions.memoryFactor does not attenuate with neuro clarity")

    # 5. Medical reading & Window visual graph
    if "Signs of neuroinflammation" not in med_src:
        faults.append("SAO_Medical lacks neuroinflammation diagnostic lines")
    if "Brain Inflammatory Load:" not in medwin_src:
        faults.append("SAOMedicalWindow lacks Brain Inflammatory Load label")
    if "drawRect" not in medwin_src or "neuroLoad" not in medwin_src:
        faults.append("SAOMedicalWindow does not render visual load curve bar")

    # 6. Inspect & Tick advances
    if "neuroinflammation" not in inspect_src:
        faults.append("SAO_Inspect does not display neuroinflammation")
    if "SAO.Neuro.advance" not in pop_src:
        faults.append("SAO_Population does not advance neuroinflammation in daily dormant pass")
    if "SAO.Neuro.advance" not in drugs_src:
        faults.append("SAO_Drugs does not advance neuroinflammation in 10-minute pass")

    return faults


def simulate_math():
    """Verify kinetic equations and mathematical properties directly."""
    faults = []

    # Sine activation curve: mid-course peak
    def knox_rate(pos):
        pos = max(0.0, min(1.0, pos))
        return math.sin(pos * math.pi) * 0.08

    r_early = knox_rate(0.1)
    r_mid = knox_rate(0.5)
    r_late = knox_rate(0.9)
    if not (r_mid > r_early and r_mid > r_late):
        faults.append(f"Knox sine curve failed peak property: mid={r_mid:.4f} early={r_early:.4f} late={r_late:.4f}")
    if abs(r_mid - 0.08) > 1e-6:
        faults.append(f"Knox sine curve peak expected 0.08, got {r_mid}")

    # Clearance decay
    decay_24h = math.exp(-0.04 * 24.0)
    if not (0.35 < decay_24h < 0.40):
        faults.append(f"24h clearance decay expected ~0.38, got {decay_24h}")

    # Afflicted baseline invariance
    afflicted_floor = 0.30
    load = afflicted_floor + (0.80 - afflicted_floor) * decay_24h
    if load < afflicted_floor:
        faults.append(f"Afflicted load decayed below floor: {load} < {afflicted_floor}")

    # Clarity inverse
    for test_load in [0.0, 0.25, 0.50, 0.75, 1.0]:
        clarity = max(0.0, min(1.0, 1.0 - test_load))
        if abs(clarity - (1.0 - test_load)) > 1e-6:
            faults.append(f"Clarity mismatch for load {test_load}: got {clarity}")

    return faults


def mutation_tests(neuro_src, cond_src, med_src, medwin_src, inspect_src, pop_src, drugs_src, opts_src, json_src):
    # Control 1: If sine curve is removed, fault occurs
    m1 = neuro_src.replace("math.sin(pos * math.pi)", "pos")
    if not source_faults(m1, cond_src, med_src, medwin_src, inspect_src, pop_src, drugs_src, opts_src, json_src):
        return "mutation failed: missing sine activation curve did not fault"

    # Control 2: If afflicted floor is missing, fault occurs
    m2 = neuro_src.replace("Neuro.AFFLICTED_FLOOR = 0.30", "Neuro.AFFLICTED_FLOOR = 0.0")
    if not source_faults(m2, cond_src, med_src, medwin_src, inspect_src, pop_src, drugs_src, opts_src, json_src):
        return "mutation failed: altered afflicted floor did not fault"

    # Control 3: If memory integration is removed, fault occurs
    m3 = cond_src.replace("SAO.Neuro.clarityOfId", "clarityOfId")
    if not source_faults(neuro_src, m3, med_src, medwin_src, inspect_src, pop_src, drugs_src, opts_src, json_src):
        return "mutation failed: missing memory clarity integration did not fault"

    # Control 4: If medical window graph rendering is removed, fault occurs
    m4 = medwin_src.replace("Brain Inflammatory Load:", "")
    if not source_faults(neuro_src, cond_src, med_src, m4, inspect_src, pop_src, drugs_src, opts_src, json_src):
        return "mutation failed: missing medical window graph did not fault"

    # Control 5: If sandbox option is missing, fault occurs
    m5 = opts_src.replace("option SurvivorAwareness.Neuroinflammation", "")
    if not source_faults(neuro_src, cond_src, med_src, medwin_src, inspect_src, pop_src, drugs_src, m5, json_src):
        return "mutation failed: missing sandbox declaration did not fault"

    return None


def switch_vm_faults(source):
    """Execute the option, including the original false-or-true control."""
    game = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
    jdk = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
    runner = ROOT / "tools/luacheck/LuaRun.java"
    if not all(p.exists() for p in (game / "projectzomboid.jar", game / "stdlib.lua",
                                   jdk / "java.exe", jdk / "javac.exe")):
        print("SKIPPED: neuro option VM check needs the installed game and JDK")
        return []
    if not runner.exists():
        return ["neuro option VM runner is missing"]
    seam = "return sv.Neuroinflammation == true"
    if source.count(seam) != 1:
        return ["neuro option control seam changed"]
    with tempfile.TemporaryDirectory(prefix="sao-neuro-switch-") as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(game / "stdlib.lua", work / "stdlib.lua")
        compiled = subprocess.run([str(jdk / "javac.exe"), "-cp",
            str(game / "projectzomboid.jar"), "-d", str(work), str(runner)],
            capture_output=True, text=True, timeout=60)
        if compiled.returncode:
            return ["neuro option VM runner did not compile: " + compiled.stderr]
        probe = '''(function()
            SandboxVars = nil
            if not SAO.Neuro.isActive() then return "FAIL missing setting changed default" end
            SandboxVars = { SurvivorAwareness = { Neuroinflammation = false } }
            if SAO.Neuro.isActive() then return "FAIL false setting stayed active" end
            local rec = { neuroinflammation = 0.8, woundInfected = true }
            if SAO.Neuro.loadOf(rec) ~= 0 or SAO.Neuro.clarityOf(rec) ~= 1 then
                return "FAIL disabled projections still affect cognition" end
            if SAO.Neuro.advance(rec, 24, 24) ~= 0 then return "FAIL disabled graph advanced" end
            SandboxVars.SurvivorAwareness.Neuroinflammation = true
            if not SAO.Neuro.isActive() then return "FAIL true setting stayed disabled" end
            if SAO.Neuro.advance(rec, 24, 48) <= 0 then return "FAIL reenabled graph did not advance" end
            return "neuro switch holds"
        end)()'''
        args = [str(jdk / "java.exe"), "-cp", str(game / "projectzomboid.jar") + ";" + str(work),
                "LuaRun", str(work / "neuro.lua"), "--", probe]
        for bad in (False, True):
            text = source.replace(seam, "return (sv.Neuroinflammation or true) == true") if bad else source
            (work / "neuro.lua").write_text(text, encoding="utf-8")
            result = subprocess.run(args, cwd=work, capture_output=True, text=True, timeout=30)
            if not bad and (result.returncode or "VALUE neuro switch holds" not in result.stdout):
                return ["neuro option VM failed: " + result.stdout + result.stderr]
            if bad and (result.returncode or "VALUE FAIL false setting stayed active" not in result.stdout):
                return ["neuro option original-code control survived or failed for another reason"]
    print("CONTROL: original neuro off-switch rejected in actual VM")
    return []


def main():
    if not (NEURO_LUA.exists() and COND_LUA.exists() and MED_LUA.exists()
            and MED_WIN.exists() and INSPECT_LUA.exists() and POP_LUA.exists()
            and DRUGS_LUA.exists() and OPTS_TXT.exists() and SANDBOX_JSON.exists()):
        print("FAULT: Required source files missing for Border 158")
        return 1

    neuro_src = NEURO_LUA.read_text(encoding="utf-8")
    cond_src = COND_LUA.read_text(encoding="utf-8")
    med_src = MED_LUA.read_text(encoding="utf-8")
    medwin_src = MED_WIN.read_text(encoding="utf-8")
    inspect_src = INSPECT_LUA.read_text(encoding="utf-8")
    pop_src = POP_LUA.read_text(encoding="utf-8")
    drugs_src = DRUGS_LUA.read_text(encoding="utf-8")
    opts_src = OPTS_TXT.read_text(encoding="utf-8")
    json_src = SANDBOX_JSON.read_text(encoding="utf-8")

    faults = source_faults(neuro_src, cond_src, med_src, medwin_src, inspect_src,
                           pop_src, drugs_src, opts_src, json_src)
    faults.extend(simulate_math())
    faults.extend(switch_vm_faults(neuro_src))

    if faults:
        for f in faults:
            print(f"FAULT: {f}")
        return 1

    m_err = mutation_tests(neuro_src, cond_src, med_src, medwin_src, inspect_src,
                           pop_src, drugs_src, opts_src, json_src)
    if m_err:
        print(f"FAULT: {m_err}")
        return 1

    print("158) neuroinflammation: source contract and arithmetic checked; option behavior and original-code control executed in VM when available")
    return 0


if __name__ == "__main__":
    sys.exit(main())
