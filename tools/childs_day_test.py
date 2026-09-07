#!/usr/bin/env python3
r"""Border 106 - the child's day ([C31], DR-032).

[C29] gave a child a body and [C30] gave the county its children.
[C31] gives a child their day, every system Growing Up's (credited)
carried at SAO's own seams: a fear floor by age that the night
deepens and a comfort object and the child's own kills ease, read by
the disposition's decisions and held on the engine's panic; literacy
by the school years lived before the fall; the experience throttle
on the shell and the birthday floors on strength and fitness; the
kit drawn from the child's own temperament; the child's head.

What is checked, in the engine's own VM (tools/luacheck/LuaRun, the
[B48] instrument) against Border 105's stub county:

  * the floor at six, eight, thirteen, eighteen and thirty; the night
    by age and hour; the throttle and the floors by age;
  * literacy follows the age for every one of three thousand people;
  * the kit: a schoolbag first, the comfort share by band, nothing for
    anyone grown, all six types reached, the same kit twice;
  * a child's fear equals the floor where there is no body and no
    clock, an adult's is zero, the flee distance is widened by exactly
    four times the fear, a frightened child never engages, and the
    crowd threshold never drops below the envelope's two.

And by text, the seams that carry it: the body (floors and kit on a
first body, the learning pace on every body), the appearance (the
verified accessors, and every style name one the game's own hair
definitions declare), the age module (the panic floor), the
controller (the literacy gate), the bridge (the scaled grant and its
three exemptions), and Border 63 loading the county so its ranges
include children.

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
SHARED = ROOT / "mod" / "42.20" / "media" / "lua" / "shared"
CLIENT = ROOT / "mod" / "42.20" / "media" / "lua" / "client"
HASH = SHARED / "SAO_Hash.lua"
HISTORY = SHARED / "SAO_History.lua"
DISP = SHARED / "SAO_Disposition.lua"
AGE = CLIENT / "SAO_Age.lua"
BODY = CLIENT / "SAO_Body.lua"
LOOK = CLIENT / "SAO_Appearance.lua"
CONTROLLER = CLIENT / "SAO_Controller.lua"
BRIDGE = ROOT / "java" / "src" / "com" / "sao" / "bridge" / "SAOBridge.java"
SHELL = ROOT / "java" / "src" / "com" / "sao" / "engine" / "SAOIsoPlayerShell.java"
RANGE_BORDER = ROOT / "tools" / "decision_range_test.py"
PRELUDE = HERE / "luacheck" / "probe_age.lua"
SRC = HERE / "luacheck" / "LuaRun.java"
OUT = ROOT / "java" / "out" / "luacheck"
JDK = pathlib.Path(r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin")
PZ_DIR = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")
PZ = PZ_DIR / "projectzomboid.jar"
STDLIB = PZ_DIR / "stdlib.lua"
HAIR_DEFS = PZ_DIR / "media" / "lua" / "shared" / "Definitions" / "HairOutfitDefinitions.lua"

IDS = 3000


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
             str(PRELUDE), str(HASH), str(HISTORY), str(DISP), "--", expr],
            cwd=str(work), capture_output=True, text=True, timeout=600)
    return (done.stdout or "").strip().split("\n")[-1] if done.stdout else "ERROR no output"


def value(line):
    return line[6:] if line.startswith("VALUE ") else None


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


FLOORS = (
    "(function() local H = SAO.History local out = {} "
    "for _, a in ipairs({6, 8, 13, 18, 30}) do out[#out + 1] = string.format('%.4f', H.fearFloorOf(a)) end "
    "out[#out + 1] = string.format('%.2f/%.2f/%.2f/%.2f/%.2f', H.nightFearOf(10, 23), H.nightFearOf(13, 2), "
    "H.nightFearOf(13, 12), H.nightFearOf(16, 23), H.nightFearOf(10, 21.9)) "
    "out[#out + 1] = string.format('%.2f/%.2f/%.2f/%.2f', H.xpScaleOf(9), H.xpScaleOf(12), H.xpScaleOf(14), H.xpScaleOf(40)) "
    "local s8, f8 = H.perkFloorsOf(8) local s13, f13 = H.perkFloorsOf(13) local s17, f17 = H.perkFloorsOf(17) "
    "local s6, f6 = H.perkFloorsOf(6) "
    "out[#out + 1] = tostring(s8) .. ',' .. tostring(f8) .. '/' .. tostring(s13) .. ',' .. tostring(f13) .. '/' "
    ".. tostring(s17) .. ',' .. tostring(f17) .. '/' .. tostring(s6) .. ',' .. tostring(f6) .. '/' .. tostring(H.perkFloorsOf(18)) "
    "return table.concat(out, '|') end)()")
FLOORS_WANT = "0.5500|0.5500|0.2750|0.0000|0.0000|0.20/0.10/0.00/0.00/0.00|0.25/0.50/1.00/1.00|0,0/2,3/4,5/0,0/nil"

KIT = (
    "(function() local H = SAO.History local bad, kids, bagFirst = 0, 0, 0 "
    "local cU12, nU12, c1214, n1214, c15, n15, adultsWithKit = 0, 0, 0, 0, 0, 0, 0 "
    "local types = {} local same = true "
    "for i = 1, %d do local id = 'sao-' .. i local age = H.ageOf(id) "
    "local lit = H.literacyOf(id) local want = (age < 8 and 'none') or (age < 12 and 'slow') or 'reads' "
    "if lit ~= want then bad = bad + 1 end "
    "local kit = H.kitOf(id) "
    "if age >= 18 then if kit ~= nil then adultsWithKit = adultsWithKit + 1 end "
    "else kids = kids + 1 "
    "if kit and kit[1] == 'Base.Bag_Schoolbag_Kids' then bagFirst = bagFirst + 1 end "
    "local has = false for _, it in ipairs(kit or {}) do for _, c in ipairs(H.COMFORT_OBJECTS) do if it == c then has = true end end end "
    "if age < 12 then nU12 = nU12 + 1 if has then cU12 = cU12 + 1 end "
    "elseif age < 15 then n1214 = n1214 + 1 if has then c1214 = c1214 + 1 end "
    "else n15 = n15 + 1 if has then c15 = c15 + 1 end end "
    "local ty = H.archetypeOf(id) types[ty] = (types[ty] or 0) + 1 "
    "local again = H.kitOf(id) if #again ~= #kit then same = false else for k = 1, #kit do if kit[k] ~= again[k] then same = false end end end "
    "end end "
    "local tl = {} for _, ty in ipairs({'scout', 'jock', 'nerd', 'shy', 'bully', 'crybaby'}) do tl[#tl + 1] = ty .. '=' .. tostring(types[ty] or 0) end "
    "return string.format('bad=%%d kids=%%d bagFirst=%%d u12=%%d/%%d t14=%%d/%%d o15=%%d/%%d adultsWithKit=%%d same=%%s %%s', "
    "bad, kids, bagFirst, cU12, nU12, c1214, n1214, c15, n15, adultsWithKit, tostring(same), table.concat(tl, ' ')) end)()"
    % IDS)

FEAR = (
    "(function() local H, D = SAO.History, SAO.Disposition "
    "local n, adultsNonZero, kidsOff, fleeOff, engage, overwhelmLow, maxFear = 0, 0, 0, 0, 0, 0, 0 "
    "for i = 1, %d do local id = 'sao-' .. i local age = H.ageOf(id) local f = D.fear(id) "
    "if age >= 18 then if f ~= 0 then adultsNonZero = adultsNonZero + 1 end "
    "else n = n + 1 "
    "if math.abs(f - H.fearFloorOf(age)) > 1e-6 then kidsOff = kidsOff + 1 end "
    "if f > maxFear then maxFear = f end "
    "local t = D.traits(id) local base = 3.0 + (1.0 - t.nerve) * 5.0 + t.selfPreservation * 3.0 "
    "if math.abs(D.fleeDistance(id) - (base + f * 4.0)) > 1e-6 then fleeOff = fleeOff + 1 end "
    "if f >= 0.5 and D.wouldEngage(id, true, 1) then engage = engage + 1 end "
    "if D.overwhelmThreshold(id) < 2 then overwhelmLow = overwhelmLow + 1 end "
    "end end "
    "return string.format('n=%%d adultsNonZero=%%d kidsOff=%%d fleeOff=%%d engage=%%d overwhelmLow=%%d maxFear=%%.2f', "
    "n, adultsNonZero, kidsOff, fleeOff, engage, overwhelmLow, maxFear) end)()"
    % IDS)


def numbers(line):
    return {k: v for k, v in re.findall(r"(\w+)=([\d./]+|true|false)", line or "")}


def main():
    faults = []
    print("=" * 74)
    print("THE CHILD'S DAY")
    print("=" * 74)

    for path, what in ((HASH, "SAO_Hash.lua"), (HISTORY, "SAO_History.lua"),
                       (DISP, "SAO_Disposition.lua"), (AGE, "SAO_Age.lua"),
                       (BODY, "SAO_Body.lua"), (LOOK, "SAO_Appearance.lua"),
                       (CONTROLLER, "SAO_Controller.lua"), (BRIDGE, "SAOBridge.java"),
                       (SHELL, "SAOIsoPlayerShell.java"), (RANGE_BORDER, "Border 63"),
                       (PRELUDE, "the probe")):
        if not path.exists():
            faults.append(what + " does not exist")
    if faults:
        for fault in faults:
            print("  FAULT: " + fault)
        return 1
    if not (JDK.exists() and PZ.exists() and STDLIB.exists() and SRC.exists()):
        print("  FAULT: no JDK, engine jar, stdlib or runner - nothing ran on the engine")
        return 1
    if not build():
        print("  FAULT: LuaRun does not compile against the installed jar")
        return 1

    hist = read(HISTORY)
    if "function H.fearFloorOf" not in hist:
        faults.append("SAO_History carries no fear floor, so nothing below can be asked")
    else:
        got = value(probe(FLOORS))
        print("     floors/night/throttle: " + str(got))
        if got != FLOORS_WANT:
            faults.append("the floor, the night, the throttle or the birthday floors "
                          "are not the mod's - got %r, wanted %r" % (got, FLOORS_WANT))

        kit = numbers(value(probe(KIT)))
        print("     kit: " + " ".join("%s=%s" % kv for kv in kit.items()))
        try:
            kids = int(kit["kids"])
            if int(kit["bad"]) != 0:
                faults.append("literacy does not follow the age for %s people" % kit["bad"])
            if not (IDS * 0.12 <= kids <= IDS * 0.32):
                faults.append("children are %d of %d, outside the county's own share" % (kids, IDS))
            if int(kit["bagFirst"]) != kids:
                faults.append("not every child's kit begins with the schoolbag")
            cu, nu = (int(x) for x in kit["u12"].split("/"))
            ct, nt = (int(x) for x in kit["t14"].split("/"))
            co, no = (int(x) for x in kit["o15"].split("/"))
            if nu == 0 or not (0.60 <= cu / nu <= 0.90):
                faults.append("the comfort share under twelve is %d of %d" % (cu, nu))
            if nt == 0 or not (0.15 <= ct / nt <= 0.45):
                faults.append("the comfort share at twelve to fourteen is %d of %d" % (ct, nt))
            if co != 0:
                faults.append("%d of %d at fifteen and over carry a comfort object" % (co, no))
            if int(kit["adultsWithKit"]) != 0:
                faults.append("%s adults were dealt a child's kit" % kit["adultsWithKit"])
            if kit["same"] != "true":
                faults.append("the same child was dealt two different kits")
            for ty in ("scout", "jock", "nerd", "shy", "bully", "crybaby"):
                if int(kit.get(ty, "0")) == 0:
                    faults.append("no child of %d is a %s - a type nobody is is a type not derived" % (IDS, ty))
        except (KeyError, ValueError, ZeroDivisionError):
            faults.append("the kit probe did not answer: %r" % kit)

        fear = numbers(value(probe(FEAR)))
        print("     fear: " + " ".join("%s=%s" % kv for kv in fear.items()))
        try:
            if int(fear["adultsNonZero"]) != 0:
                faults.append("%s adults carry a child's fear" % fear["adultsNonZero"])
            if int(fear["kidsOff"]) != 0:
                faults.append("%s children's fear is not the floor where there is no body and no clock" % fear["kidsOff"])
            if int(fear["fleeOff"]) != 0:
                faults.append("the flee distance is not widened by exactly four times the fear for %s children" % fear["fleeOff"])
            if int(fear["engage"]) != 0:
                faults.append("%s frightened children would still choose to engage" % fear["engage"])
            if int(fear["overwhelmLow"]) != 0:
                faults.append("the crowd threshold dropped below the envelope's two")
            if abs(float(fear["maxFear"]) - 0.55) > 1e-6:
                faults.append("the highest fear in the county is %s, not the floor at eight" % fear["maxFear"])
            if int(fear["n"]) == 0:
                faults.append("no children were sampled")
        except (KeyError, ValueError):
            faults.append("the fear probe did not answer: %r" % fear)

    # The seams, by text.
    body = read(BODY)
    sec = body[body.find("[C31]"):] if "[C31]" in body else ""
    seams = {
        "the body sets the strength floor": "setPerkLevelDebug(Perks.Strength, strength)" in sec,
        "and the fitness floor": "setPerkLevelDebug(Perks.Fitness, fitness)" in sec,
        "on a first body only": "if not rec.hibernation then" in sec
            and sec.find("if not rec.hibernation then") < sec.find("setPerkLevelDebug"),
        "and gives the kit": "SAO.History.kitOf" in sec and "inv:AddItem(item)" in sec,
        "and holds the learning pace on every body": "setXpScale(" in sec
            and sec.find("setXpScale(") > sec.find("if not rec.hibernation then"),
        "the appearance takes the beard": 'visual:setBeardModel("")' in read(LOOK)
            and "resetBeardGrowingTime" in read(LOOK),
        "and replaces a banned style": "visual:setHairModel(" in read(LOOK)
            and "BANNED_FOR_CHILDREN" in read(LOOK),
        # [C32] widened from the child alone to everyone the fear reads.
        "the age module holds the panic floor": "CharacterStat.PANIC" in read(AGE)
            and "SAO.Disposition.fear" in read(AGE),
        "the controller gates the book by literacy": "SAO.History.literacyOf(id)" in read(CONTROLLER)
            and 'literacy48 == "none"' in read(CONTROLLER),
        "the shell carries the learning pace": "public volatile float xpScale = 1f;" in read(SHELL),
        "the bridge sets it without throwing": "public String setXpScale(" in read(BRIDGE)
            and "catch (Throwable" in read(BRIDGE)[read(BRIDGE).find("public String setXpScale("):][:900],
        "the disposition carries the fear": "function D.fear(id)" in read(DISP)
            and "D.fear(id) * 4.0" in read(DISP) and "D.fear(id) >= 0.5" in read(DISP),
        "Border 63 samples the whole county": "SAO_History.lua" in read(RANGE_BORDER)
            and "probe_age.lua" in read(RANGE_BORDER),
    }
    grant = read(BRIDGE)
    g = grant.find("public boolean grantXP(")
    gbody = grant[g:grant.find("\n    }\n", g)] if g >= 0 else ""
    seams["the grant is scaled"] = "scaled * shell.xpScale" in gbody
    seams["with the three exemptions"] = all(
        '"%s".equalsIgnoreCase(id)' % p in gbody for p in ("Strength", "Fitness", "Sprinting"))

    # Every style name is one the game's own definitions declare.
    look = read(LOOK)
    declared = set(re.findall(r"([A-Za-z]+):\d+", read(HAIR_DEFS))) | set(
        re.findall(r'cat\.name = "([A-Za-z]+)"', read(HAIR_DEFS)))
    pool = re.search(r"local CHILD_HAIR = \{(.*?)\}", look, re.S)
    banned = re.search(r"local BANNED_FOR_CHILDREN = \{(.*?)\}", look, re.S)
    pool_names = re.findall(r'"([A-Za-z]+)"', pool.group(1)) if pool else []
    banned_names = re.findall(r"([A-Za-z]+) = true", banned.group(1)) if banned else []
    unknown = [n for n in pool_names + banned_names if n not in declared]
    seams["every style name is the game's own"] = bool(pool_names) and bool(banned_names) \
        and not unknown and HAIR_DEFS.exists()
    if unknown:
        print("     styles the game does not declare: " + ", ".join(unknown))

    print()
    print("  THE SEAMS")
    for k, v in seams.items():
        print("    %s  %s" % ("yes" if v else "NO ", k))
        if not v:
            faults.append("seam missing: " + k)

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  106) the child's day: the floor, the night, the comfort, the kills, literacy, "
          "the throttle, the floors, the kit and the head, on the engine's own VM and every seam")
    return 0


if __name__ == "__main__":
    sys.exit(main())
