#!/usr/bin/env python3
r"""Border 113 - the conditions are SAO's own ([C39], DR-032 amended).

[C32] required two third-party mods so the player could carry the
conditions the county's people carry, took no code from either, and
gained nothing mechanical. The operator ruled that wrong: port the
source instead. So SAO registers the conditions as engine character
traits of its own, uses vanilla's where vanilla has one, stamps a
survivor's drawn conditions onto their shell, drives the player's
chosen ones through the same functions, and requires nothing.

WHAT THIS HOLDS
---------------
  1. Neither manifest requires another mod, and no module names one.
  2. Every condition SAO models is accounted for: registered by SAO,
     or claimed as vanilla's.
  3. No cost is picked. Each condition names the vanilla trait whose
     shape is closest, and takes ITS cost - read out of the shipped
     `character_traits.txt` on this machine, that run. A cost that
     drifts from its anchor, or an anchor vanilla does not price, is a
     fault.
  4. The registration is in shared Lua: no `media/registries.lua` and
     no `character_trait_definition` script of ours, because a mod
     that throws in the registries pass takes down every mod after it.
  5. The assertion beats the draw - driven in the engine's own VM, so
     the player's chosen conditions reach every surface that asks.
  6. The condition rides the trait at materialisation, and the player
     has a pass of their own.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree faults at every seam.
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 \
    else pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent
LUA = ROOT / "mod" / "42.20" / "media" / "lua"
TRAITS = LUA / "shared" / "NPCs" / "SAO_Traits.lua"
COND = LUA / "shared" / "SAO_Conditions.lua"
HASH = LUA / "shared" / "SAO_Hash.lua"
HISTORY = LUA / "shared" / "SAO_History.lua"
BODY = LUA / "client" / "SAO_Body.lua"
AGE = LUA / "client" / "SAO_Age.lua"
WORDS = LUA / "shared" / "Translate" / "EN" / "UI_EN.txt"
CREDITS = ROOT / "CREDITS.md"
REGISTRY = ROOT / "DECISION_REGISTRY.md"
CONTRACT = ROOT / "ENGINE_CONTRACT.md"
CHECK = ROOT / "tools" / "check.sh"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
VANILLA_TRAITS = (PZ_DIR / "media" / "scripts" / "generated" / "characters"
                  / "character_traits.txt")

MANIFESTS = (ROOT / "mod" / "42.20" / "mod.info", ROOT / "mod" / "mod.info")


def build():
    cls = OUT / "LuaRun.class"
    if cls.exists() and cls.stat().st_mtime >= SRC.stat().st_mtime:
        return True
    OUT.mkdir(parents=True, exist_ok=True)
    done = subprocess.run(
        [str(JDK / "javac.exe"), "-cp", str(PZ), "-d", str(OUT), str(SRC)],
        capture_output=True, text=True, timeout=300)
    return done.returncode == 0


def probe(expr):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        shutil.copy2(STDLIB, work / "stdlib.lua")
        for c in OUT.glob("*.class"):
            shutil.copy2(c, work / c.name)
        done = subprocess.run(
            [str(JDK / "java.exe"), "-cp", f"{PZ};.", "LuaRun",
             str(PRELUDE), str(HASH), str(HISTORY), str(COND), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=300)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def vanilla_costs():
    """Every vanilla trait's own cost, off the shipped script."""
    text = read(VANILLA_TRAITS)
    out = {}
    for block in re.finditer(
            r"character_trait_definition\s+base:(\w+)(.*?)\n\s*\}", text, re.S):
        cost = re.search(r"Cost\s*=\s*(-?\d+)", block.group(2))
        if cost:
            out[block.group(1).lower()] = int(cost.group(1))
    return out


# The assertion beats the draw, in the engine's own VM: a person the
# hash gave nothing is asked about a condition they were asserted to
# have, and one the hash gave something is asserted to have none.
ASSERT = (
    "(function() local Cn = SAO.Conditions "
    "local drawn, bare = nil, nil "
    "for i = 1, 4000 do local id = 'sao-' .. i "
    "if not drawn and Cn.has(id, 'anxiety') then drawn = id end "
    "if not bare and #Cn.of(id) == 0 then bare = id end end "
    "if not drawn or not bare then return 'nosample=true' end "
    "local out = {} "
    "out[#out + 1] = 'drawnBefore=' .. tostring(Cn.has(drawn, 'anxiety')) "
    "out[#out + 1] = 'bareBefore=' .. tostring(Cn.has(bare, 'dementia')) "
    "Cn.assert(bare, { dementia = true }) "
    "Cn.assert(drawn, {}) "
    "out[#out + 1] = 'bareAfter=' .. tostring(Cn.has(bare, 'dementia')) "
    "out[#out + 1] = 'drawnAfter=' .. tostring(Cn.has(drawn, 'anxiety')) "
    "out[#out + 1] = 'bareWords=' .. tostring(Cn.describe(bare)):gsub(' ', '_') "
    "out[#out + 1] = 'bareMemory=' .. string.format('%.2f', Cn.memoryFactor(bare, 'zombies')) "
    "out[#out + 1] = 'drawnFear=' .. string.format('%.2f', Cn.fear(drawn)) "
    "return table.concat(out, ' ') end)()")


def main():
    faults = []
    print("=" * 74)
    print("THE CONDITIONS ARE SAO'S OWN")
    print("=" * 74)

    if not TRAITS.exists():
        print("  FAULT: SAO_Traits.lua does not exist - the conditions are still "
              "another mod's to provide")
        return 1
    traits, cond = read(TRAITS), read(COND)

    # 1. Nothing is required, and nothing names a required mod.
    for manifest in MANIFESTS:
        text = read(manifest)
        if not text:
            faults.append(str(manifest.name) + " does not exist")
            continue
        line = re.search(r"^require=(.*)$", text, re.M)
        if line:
            faults.append("%s still requires %s - a requirement on every user "
                          "for a surface SAO can hold itself"
                          % (manifest.parent.name + "/" + manifest.name,
                             line.group(1).strip()))
    tree = "".join(read(p) for p in LUA.rglob("*.lua"))
    for named in ("twbInfirmities", "EvenMoreTraits4220"):
        if named in tree:
            faults.append("%s is named in the Lua tree - the port stands on its "
                          "own or it is not a port" % named)

    # 2. Every condition accounted for.
    order = re.search(r"Cn\.ORDER = \{(.*?)\}", cond, re.S)
    conditions = re.findall(r'"(\w+)"', order.group(1)) if order else []
    ours = set(re.findall(r"^\s{4}(\w+) = \"(?:\w+)\",",
                          traits.split("T.ANCHOR = {")[-1].split("}")[0], re.M))
    vanillas = set(re.findall(r"^\s{4}(\w+) = \"[A-Z_]+\",",
                              traits.split("T.VANILLA = {")[-1].split("}")[0], re.M))
    print("     ours: " + ", ".join(sorted(ours)))
    print("     vanilla's: " + ", ".join(sorted(vanillas)))
    if not conditions:
        faults.append("SAO_Conditions declares no ORDER to check against")
    for key in conditions:
        if key not in ours and key not in vanillas:
            faults.append("%s is a condition the county carries and no trait "
                          "answers for it" % key)
    for key in ours & vanillas:
        faults.append("%s is registered by SAO and claimed as vanilla's - two "
                      "names for one fact" % key)

    # 3. Every cost is its anchor's, off the shipped script.
    prices = vanilla_costs()
    if not prices:
        faults.append("vanilla's own character_traits.txt did not parse, so no "
                      "cost was checked against the game")
    anchors = dict(re.findall(r"^\s{4}(\w+) = \"(\w+)\",",
                              traits.split("T.ANCHOR = {")[-1].split("}")[0], re.M))
    declared = dict((k, int(v)) for k, v in re.findall(
        r"^\s{4}(\w+) = (-?\d+),",
        traits.split("T.ANCHOR_COST = {")[-1].split("}")[0], re.M))
    print("     costs: " + " ".join(
        "%s=%s(%s)" % (k, declared.get(anchors[k]), anchors[k]) for k in sorted(anchors)))
    for key, anchor in sorted(anchors.items()):
        want = prices.get(anchor)
        if want is None:
            faults.append("%s is priced as '%s' and vanilla prices no such trait"
                          % (key, anchor))
            continue
        if declared.get(anchor) != want:
            faults.append("%s is priced as '%s' at %s; vanilla prices that trait "
                          "at %d - a cost that has drifted from its anchor is a "
                          "picked number wearing a reason"
                          % (key, anchor, declared.get(anchor), want))
    for key in vanillas:
        constant = re.search(r'%s = "([A-Z_]+)"' % key, traits)
        if constant and constant.group(1).lower().replace("_", "") not in prices:
            faults.append("%s claims vanilla's '%s' and vanilla has no such trait"
                          % (key, constant.group(1)))

    # 4. Shared Lua, not the registries pass.
    if (ROOT / "mod" / "42.20" / "media" / "registries.lua").exists():
        faults.append("a media/registries.lua has appeared - one mod throwing in "
                      "that pass takes down every mod after it")
    for script in (ROOT / "mod" / "42.20" / "media" / "scripts").glob("*.txt"):
        if "character_trait_definition" in read(script):
            faults.append("%s defines a trait through a script - the registration "
                          "belongs in shared Lua" % script.name)

    # 5. The assertion beats the draw, driven.
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        faults.append("no JDK, engine jar, stdlib or runner - nothing drove the "
                      "assertion, and a border that cannot run is not a border "
                      "that passed")
    elif not build():
        faults.append("LuaRun does not compile against the installed jar")
    else:
        answer = value(probe(ASSERT)) or ""
        got = dict(kv.split("=", 1) for kv in answer.split(" ") if "=" in kv)
        print("     asserted: " + " ".join("%s=%s" % kv for kv in got.items()))
        want = {"drawnBefore": "true", "bareBefore": "false",
                "bareAfter": "true", "drawnAfter": "false",
                "bareWords": "forgets_things", "bareMemory": "0.50",
                "drawnFear": "0.00"}
        if got.get("nosample") == "true":
            faults.append("no drawn and no bare person among four thousand")
        else:
            for k, v in want.items():
                if got.get(k) != v:
                    faults.append("the assertion: %s is %s, wanted %s"
                                  % (k, got.get(k), v))

    # 6. Every seam.
    body, age, words = read(BODY), read(AGE), read(WORDS)
    seams = {
        "the assertion is the condition module's own":
            "function Cn.assert(id, set)" in cond and "Cn.asserted[tostring(id)]" in cond,
        "the condition rides the trait at materialisation":
            "SAO.Traits.stamp(rec.id, body)" in body,
        "the player's traits are read onto their key":
            "function T.readPlayer(player)" in traits
            and "SAO.Conditions.assert(key, asserted)" in traits,
        "the player has a pass of their own, conditions only":
            "function Age.playerPass(player, key, pass, today)" in age
            and "Age.playerPass(me, key, passCounter" in age
            and "SAO.History.stageOf" not in age.split("function Age.playerPass")[1]
                                               .split("local lastDay")[0],
        "every trait of ours has a word":
            all(("UI_trait_SAO_" + k) in words for k in ours),
        "the credits say what was taken and that the requirement is gone":
            "no longer one" in read(CREDITS) and "One TECHNIQUE is" in read(CREDITS),
        "the registry carries the amendment":
            "**Amended 2026-09-07 by the operator ([C39]).**" in read(REGISTRY),
        "the contract carries the trait surfaces":
            "CharacterTrait.register(String)" in read(CONTRACT),
        "the gate runs this border":
            "tools/traits_test.py" in read(CHECK),
    }
    print()
    for k, v in seams.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  113) the conditions are SAO's own: %d traits registered and %d left "
          "to vanilla, every cost its anchor's, nothing required"
          % (len(ours), len(vanillas)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
