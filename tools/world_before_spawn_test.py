#!/usr/bin/env python3
r"""Border 115 - the world is generated before it is spawned ([C41],
DR-036).

Genesis used to pace at six people per pass whatever the state of the
save, so a sixty-person county took a minute of play to exist and the
first survivors a player met had woken into a world with almost nobody
in it. The county accreted around the player rather than being there
first. On a save that has never been settled the budget is now the
whole county, and because genesis runs ahead of the band in the tick
rotation it finishes before any body is materialised.

WHAT THIS HOLDS
---------------
  1. The budget is the target on a fresh save and the pace afterwards,
     read off the source rather than assumed.
  2. The pace is named once, not spelled twice - a bare 6 and a bare 8
     two hundred lines apart were the same rule written twice, and the
     mate slack must not be smaller than a unit can be or a family is
     cut in half at the budget's edge.
  3. The flag is written only when the target is actually reached, so
     an interrupted run carries on next pass instead of pacing a
     half-built county for the rest of the save.
  4. THE ORDERING LAW, which is what makes the claim true at all:
     genesis runs before the band in the tick, so "generated" really
     does precede "spawned". If that order ever inverts, the whole
     batch is a lie and this is the only thing that would notice.
  5. Nothing else changed about who a person is: the border checks the
     per-person work is still in the loop - the past, the trade
     ground, the home navigation reference, the unit and its bonds. Actual
     admissions execute in installed Kahlua to check that location grants no
     ownership and that existing explicit claims remain intact.

An optional argv[1] points the checker at another tree root, which is
how its control runs: the pre-batch tree paces a fresh county.
"""
import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

# Catalog references are verified by map_reference_test and version_replay.
# A historical SHIPPED sentence is not a mechanical completion condition.
ROOT = pathlib.Path(__file__).resolve().parent.parent
POP = ROOT / "mod" / "42.20" / "media" / "lua" / "client" / "SAO_Population.lua"
ADMISSIONS = POP.with_name("SAO_PopulationAdmissions.lua")
REGISTRY = ROOT / "DECISION_REGISTRY.md"
CHECK = ROOT / "tools" / "check.sh"

GAME = pathlib.Path(os.environ.get("PZ_DIR",
    r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"))
JDK = pathlib.Path(os.environ.get("JDK_BIN",
    r"C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin"))

# The producer is the unmodified exported A.ensurePopulation from Admissions.
# These dependencies record its writes; no replacement admissions function is
# installed. Places supply a located building, without any residence evidence.
ADMISSION_HOST = r'''
SAO={PopulationAdmissions={},Log={line=function() end,tally=function() end}}
__records={} __store={} __hours=0 __building=false
__created={} __history={} __presence={} __learned={} __bonds={} __trust={} __saw={}
__claimCalls={} __groundCalls=0 __random={}
local function record(list,value) list[#list+1]=value end
ModData={getOrCreate=function(key)
    assert(key=='SurvivorAwareness_Standing') return __store
end}
SpawnRegionMgr={getSpawnRegions=function() return {
    {name='Fixed origin',points={
        unemployed={{posX=100,posY=200,posZ=0}},
        nurse={{posX=120,posY=220,posZ=1}}
    }}
} end}
SAO.Rand={int=function(limit)
    assert(type(limit)=='number' and limit>0 and limit==math.floor(limit))
    local value=limit==100 and 80 or 0
    assert(value>=0 and value<limit)
    record(__random,{limit=limit,value=value})
    return value
end}
SAO.Identity={
    all=function() return __records end,
    livingCount=function()
        local count=0 for _,rec in pairs(__records) do if not rec.dead then count=count+1 end end
        return count
    end,
    create=function(forename,surname,x,y,z)
        local id='person-'..tostring(#__created+1)
        local rec={id=id,x=x,y=y,z=z}
        __records[id]=rec record(__created,rec) return rec
    end,
    beliefKey=function(rec) return rec.id end,
}
SAO.History={countyHours=function() return __hours end,countyMonth=function() return 5 end,
    generate=function(id,rec)
        rec.occupation='nurse' record(__history,{id=id,rec=rec})
    end}
SAO.Census={rowOf=function(key)
    assert(key=='nurse') return {enginePath='nurse',label='nursing'}
end}
SAO.WorldKnowledge={markCountyPresence=function(rec,genesis)
    record(__presence,{id=rec.id,genesis=genesis,hours=__hours})
end}
SAO.Places={at=function(x,y)
    assert(x==120 and y==220)
    return __building and __building or nil
end}
SAO.Perception={
    learnBuilding=function(id,building,tick,source)
        record(__learned,{id=id,building=building,tick=tick,source=source})
    end,
    sawPerson=function(id,key,x,y,tick,other,distance)
        record(__saw,{id=id,key=key,x=x,y=y,tick=tick,other=other,distance=distance})
    end,
}
SAO.Body={get=function() return nil end}
SAO.Standing={
    groupOf=function() return nil end,
    feudBetween=function() return false end,
    groundAround=function(body,x,y,radius)
        __groundCalls=__groundCalls+1
        return x-radius,y-radius,x+radius,y+radius
    end,
    claim=function(id,minX,minY,maxX,maxY,z)
        local claim={id=id,minX=minX,minY=minY,maxX=maxX,maxY=maxY,z=z}
        record(__claimCalls,claim) __store.claims[id]=claim
    end,
    bond=function(a,b) record(__bonds,{a=a,b=b}) end,
    adjustTrust=function(a,b,value) record(__trust,{a=a,b=b,value=value}) end,
    pushRadioNews=function(news) record(__store.news,news) end,
}
'''

ADMISSION_CASES = r'''
local A=SAO.PopulationAdmissions
local producer=A.ensurePopulation
assert(type(producer)=='function')
local results={}
local function size(table)
    local n=0 for _ in pairs(table) do n=n+1 end return n
end
local function reset(building,target)
    A.rebindWorld()
    __records={} __created={} __history={} __presence={} __learned={}
    __bonds={} __trust={} __saw={} __claimCalls={} __groundCalls=0 __random={}
    __store={claims={},news={}} __hours=0
    __building=building and {key='located-clinic',minX=118,minY=218,maxX=125,maxY=225} or false
    return {population=target or 12,newcomers=target or 12,refillDays=3}
end
local function ensure(conf,tick)
    assert(A.ensurePopulation==producer,'the real admissions producer was replaced')
    A.ensurePopulation(conf,tick or 5400)
end
local function check(name,fn)
    local ok,value=pcall(fn)
    if not ok then print('DETAIL '..name..': '..tostring(value)) end
    results[#results+1]=name..'='..tostring(ok and value==true)
end
local function noNewClaims()
    return #__claimCalls==0 and __groundCalls==0
end
local function references()
    if #__history~=#__created or #__presence~=#__created then return false end
    for _,rec in ipairs(__created) do
        if rec.x~=120 or rec.y~=220 or rec.z~=1
            or rec.homeX~=120 or rec.homeY~=220 or rec.homeZ~=1
            or rec.originRegion~='Fixed origin' or rec.occupation~='nurse' then return false end
    end return true
end
local function explicitClaim()
    local claim={id='person-12',minX=90,minY=190,maxX=94,maxY=194,z=0,proof='existing-explicit'}
    __store.claims[claim.id]=claim return claim
end
local function preserved(claim)
    return __store.claims['person-12']==claim and claim.proof=='existing-explicit'
        and claim.minX==90 and claim.minY==190 and claim.maxX==94 and claim.maxY==194 and claim.z==0
end
local function refill(building)
    local conf=reset(building)
    ensure(conf)
    local claim=explicitClaim()
    for i=1,6 do __records['person-'..i].dead=true __records['person-'..i].diedAtHours=24 end
    __hours=95 ensure(conf,855000)
    if SAO.Identity.livingCount()~=6 or #__created~=12 then error('refill ran before wait') end
    __hours=96 ensure(conf,864000)
    return claim
end
check('road_genesis_creates_no_claims',function()
    ensure(reset(false))
    return noNewClaims() and size(__store.claims)==0 and SAO.Identity.livingCount()==12
end)
check('located_building_genesis_creates_no_claims',function()
    ensure(reset(true))
    return noNewClaims() and size(__store.claims)==0 and #__learned==4
end)
check('genesis_keeps_home_origin_and_profession',function()
    ensure(reset(true))
    return references() and SAO.Identity.livingCount()==12 and #__created==12
        and __store.countySettled==true and __store.countySettledSize==12
end)
check('genesis_keeps_lived_building_knowledge',function()
    ensure(reset(true))
    if #__learned~=4 then return false end
    for _,entry in ipairs(__learned) do
        local rec=__records[entry.id]
        if entry.building~=__building or entry.source~='lived' or entry.tick~=0
            or not rec.originAnchored or not rec.knowsTradeGround then return false end
    end
    for _,entry in ipairs(__presence) do if entry.genesis~=true then return false end end
    return true
end)
check('road_keeps_navigation_without_building_knowledge',function()
    ensure(reset(false))
    return references() and #__learned==0
end)
check('genesis_keeps_units_bonds_and_mutual_sight',function()
    ensure(reset(true))
    local units={}
    for _,rec in ipairs(__created) do
        if not rec.unitId or rec.unitKind~='mixed' then return false end
        units[rec.unitId]=(units[rec.unitId] or 0)+1
    end
    for _,n in pairs(units) do if n~=3 then return false end end
    for _,bond in ipairs(__bonds) do
        if __records[bond.a].unitId~=__records[bond.b].unitId then return false end
    end
    for _,entry in ipairs(__trust) do if entry.value~=0.5 then return false end end
    for _,entry in ipairs(__saw) do
        if entry.tick~=5400 or entry.distance~=0 or entry.key~=entry.other then return false end
    end
    return size(units)==4 and #__bonds==12 and #__trust==24 and #__saw==24
end)
check('road_refill_creates_no_claims',function()
    local claim=refill(false)
    return noNewClaims() and size(__store.claims)==1 and preserved(claim)
        and SAO.Identity.livingCount()==12
end)
check('located_building_refill_creates_no_claims',function()
    local claim=refill(true)
    return noNewClaims() and size(__store.claims)==1 and preserved(claim)
        and SAO.Identity.livingCount()==12 and #__learned==6
end)
check('explicit_claim_survives_admissions',function()
    local claim=refill(true)
    return preserved(claim) and __records['person-12'].dead~=true
        and #__created==18 and references()
end)
check('refill_keeps_arrival_and_presence_times',function()
    refill(true)
    for i=13,18 do
        local rec=__records['person-'..i]
        local presence=__presence[i]
        if not rec.newcomer or rec.arrivedAtHours~=96 or presence.genesis~=false
            or presence.hours~=96 then return false end
    end
    return #__store.news==2 and __store.news[1].kind=='stranger'
end)
check('refill_keeps_six_person_pace_after_wait',function()
    local conf=reset(false,18) ensure(conf)
    for i=1,12 do __records['person-'..i].dead=true __records['person-'..i].diedAtHours=24 end
    __hours=95 ensure(conf,855000)
    if #__created~=18 or SAO.Identity.livingCount()~=6 then return false end
    __hours=96 ensure(conf,864000)
    if #__created~=24 or SAO.Identity.livingCount()~=12 then return false end
    ensure(conf,864240)
    return #__created==30 and SAO.Identity.livingCount()==18 and __store.countySettled==true
end)
__admissionResult=table.concat(results,';')
'''

ADMISSION_EXPECTED = {
    'road_genesis_creates_no_claims', 'located_building_genesis_creates_no_claims',
    'genesis_keeps_home_origin_and_profession', 'genesis_keeps_lived_building_knowledge',
    'road_keeps_navigation_without_building_knowledge', 'genesis_keeps_units_bonds_and_mutual_sight',
    'road_refill_creates_no_claims', 'located_building_refill_creates_no_claims',
    'explicit_claim_survives_admissions', 'refill_keeps_arrival_and_presence_times',
    'refill_keeps_six_person_pace_after_wait',
}

# The exact removed producer block, reinstated inside the real admission loop.
SPAWN_CLAIM_BLOCK = '''        -- A home is a claim from the first day: a modest box around the
        -- spawn house, the social fact other survivors will respect.
        pcall(function()
            -- [B34] One ruler for everybody. Genesis happens before
            -- any body exists, so there is nothing to ask the engine
            -- about yet and this is the one claim still measured by a
            -- radius - the honest fallback, not a second policy. It
            -- goes through the same function as the others so it
            -- starts deriving the moment a body is there to ask.
            local mnX, mnY, mxX, mxY = SAO.Standing.groundAround(
                SAO.Body.get(rec.id), origin.x, origin.y, 4)
            SAO.Standing.claim(rec.id, mnX, mnY, mxX, mxY, origin.z)
        end)
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def producer_checks(receipt, faults):
    engine = GAME / 'projectzomboid.jar'
    runner = ROOT / 'tools/luacheck/LuaRun.java'
    if not all(path.is_file() for path in (engine, GAME / 'stdlib.lua',
                                          JDK / 'java.exe', JDK / 'javac.exe')):
        receipt['producer_status'] = 'SKIPPED'
        print('  SKIPPED admissions producer: installed Project Zomboid or JDK absent')
        return
    receipt['sources'] = {str(path.relative_to(ROOT)).replace('\\', '/'): sha(path)
                          for path in (ADMISSIONS, runner)}
    receipt['engine_sha256'] = sha(engine)
    source = read(ADMISSIONS)
    anchor = '        if arriving then\n            -- An arrival is a FACT of the person and news on the air.'
    if source.count(anchor) != 1:
        faults.append('admissions claim mutation anchor drifted')
        return
    with tempfile.TemporaryDirectory(prefix='sao-admissions-') as raw:
        work = pathlib.Path(raw)
        def run(command, label):
            result = subprocess.run(list(map(str, command)), cwd=work, capture_output=True,
                                    text=True, encoding='utf-8', errors='replace', timeout=90)
            receipt['runs'].append({'label': label, 'exit': result.returncode,
                                    'stdout': result.stdout, 'stderr': result.stderr})
            return result
        compile_result = run([JDK / 'javac.exe', '-encoding', 'UTF-8', '-cp', engine,
                              '-d', work, runner], 'compile-kahlua-runner')
        if compile_result.returncode:
            faults.append('admissions runner compilation failed: ' + compile_result.stderr)
            return
        shutil.copy2(GAME / 'stdlib.lua', work / 'stdlib.lua')
        host, cases = work / 'host.lua', work / 'cases.lua'
        host.write_text(ADMISSION_HOST, encoding='utf-8')
        cases.write_text(ADMISSION_CASES, encoding='utf-8')
        for label, content in (
                ('production', source),
                ('spawn-claim-restored', source.replace(anchor, SPAWN_CLAIM_BLOCK + anchor, 1))):
            path = work / (label + '.lua')
            path.write_text(content, encoding='utf-8')
            result = run([JDK / 'java.exe', '-cp', os.pathsep.join(map(str, (engine, work))),
                          'LuaRun', host, path, cases, '--', '__admissionResult'], label)
            checks = dict(re.findall(r'([a-z0-9_]+)=(true|false)', result.stdout))
            receipt[label] = checks
            if result.returncode or set(checks) != ADMISSION_EXPECTED:
                faults.append(label + ' did not execute every admissions case\n'
                              + result.stdout + result.stderr)
                return
            if label == 'production':
                failed = sorted(name for name, value in checks.items() if value != 'true')
                if failed:
                    faults.append('actual admissions producer: ' + ', '.join(failed)
                                  + '\n' + result.stdout + result.stderr)
                    return
                print('  PASS ' + str(len(checks)) + ' actual Admissions cases in installed Kahlua')
            else:
                defect_cases = {name for name in ADMISSION_EXPECTED if name.endswith('creates_no_claims')}
                if any(checks[name] != 'false' for name in defect_cases) \
                        or checks['genesis_keeps_home_origin_and_profession'] != 'true' \
                        or checks['genesis_keeps_units_bonds_and_mutual_sight'] != 'true':
                    faults.append('restored production claim block did not expose invented ownership\n'
                                  + result.stdout + result.stderr)
                    return
                print('  PASS restored production claim block fails all four ownership cases')
        receipt['producer_status'] = 'PASS'


def read(path):
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def main():
    global ROOT, POP, ADMISSIONS, REGISTRY, CHECK
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', nargs='?', type=pathlib.Path, default=ROOT)
    parser.add_argument('--receipt', type=pathlib.Path)
    args = parser.parse_args()
    ROOT = args.root.resolve()
    POP = ROOT / 'mod/42.20/media/lua/client/SAO_Population.lua'
    ADMISSIONS = POP.with_name('SAO_PopulationAdmissions.lua')
    REGISTRY, CHECK = ROOT / 'DECISION_REGISTRY.md', ROOT / 'tools/check.sh'
    receipt = {'status': 'FAIL', 'runs': [], 'checker_sha256': sha(pathlib.Path(__file__)),
               'limits': 'Real exported Admissions.ensurePopulation in installed Kahlua; fixed origin, identity, history, place and Standing recording dependencies; no game loop or spawned native body.'}
    faults = []
    print("=" * 74)
    print("THE WORLD IS GENERATED BEFORE IT IS SPAWNED")
    print("=" * 74)

    if not POP.exists() or not ADMISSIONS.exists():
        print("  FAULT: population scheduler or admissions does not exist")
        return 1
    pop = read(ADMISSIONS)
    scheduler = read(POP)

    # 1. The budget.
    budget = re.search(r"local budget = (\w+) and (\w+) or (\w+)\n", pop)
    if not budget:
        faults.append(
            "genesis has no budget that changes with the county's state - a "
            "fresh save paces six at a time and the world grows around "
            "whoever is standing in it")
    else:
        settled_value, paced, whole = budget.groups()
        print("     budget: %s -> %s, otherwise %s" % (settled_value, paced, whole))
        if whole not in ("capNow", "target"):
            faults.append(
                "the unsettled budget is '%s' and not the county's own target, "
                "so a fresh save still does not settle in one pass" % whole)
        if paced == whole:
            faults.append("both arms of the budget are the same value, so the "
                          "branch decides nothing")
    if re.search(r"while count < capNow and bornThisPass < 6 do", pop):
        faults.append("the loop still carries the bare six it was written with")

    # 2. The pace, named once.
    pace = re.search(r"local PACE_PER_PASS = (\d+)\n", pop)
    mates = re.search(r"local PACE_MATES = (\d+)\n", pop)
    if not pace or not mates:
        faults.append("the pace and its mate slack are not named, so the same "
                      "rule is spelled twice two hundred lines apart again")
    else:
        print("     pace: %s a pass, %s of slack for a unit" % (pace.group(1),
                                                               mates.group(1)))
        if int(mates.group(1)) < 2:
            faults.append(
                "the mate slack is %s: a unit of three settled at the budget's "
                "edge would be cut in half, and a family that starts as two "
                "thirds of itself is a defect nobody would see"
                % mates.group(1))
    if re.search(r"bornThisPass >= 8 then break", pop):
        faults.append("the mate break still carries the bare eight")

    # 3. The flag, written only on reaching the target.
    flags = {
        "the flag is read before the budget is chosen":
            "local settled = genesisSettled()" in pop
            and pop.index("function genesisSettled") < pop.index("local settled = genesisSettled()"),
        "the flag is written only when the target is reached":
            "if wholeCounty and count >= capNow then" in pop
            and "markGenesisSettled(count, capNow)" in pop,
        "an interrupted run says so and carries on":
            "the next pass carries on before anyone spawns" in pop,
        "the flag lives in the county's own store":
            "s.countySettled = true" in pop,
    }

    # 4. The ordering law - the whole claim rests on it.
    genesis_at = scheduler.find('runSub("genesis"')
    band_at = scheduler.find('runSub("band"')
    flags["genesis runs before the band in the tick"] = (
        genesis_at >= 0 and band_at >= 0 and genesis_at < band_at)
    if genesis_at < 0 or band_at < 0:
        faults.append("the tick no longer names genesis and band as subsystems, "
                      "so the order that makes 'before it is spawned' true "
                      "cannot be read at all")

    # 5. The per-person work is still in the loop.
    loop_at = pop.find("while count < capNow and bornThisPass < budget do")
    loop = pop[loop_at:pop.find("\nfunction A.rebindWorld", loop_at)] if loop_at >= 0 else ""
    for what, needle in (
            ("a past", "SAO.History.generate"),
            ("the trade's own ground", "pickOriginFor"),
            ("the place they woke in", "SAO.Perception.learnBuilding"),
            ("the unit they began in", "rec.unitId, rec.unitKind"),
            ("and its bonds", "SAO.Standing.bond")):
        flags["genesis still gives them " + what] = needle in loop

    flags["the registry carries the direction"] = (
        "## DR-036" in read(REGISTRY))
    flags["the gate runs this border"] = (
        "tools/world_before_spawn_test.py" in read(CHECK))

    print()
    for k, v in flags.items():
        print(f"  {'yes' if v else 'NO '}  {k}")
        if not v:
            faults.append(k)

    try:
        producer_checks(receipt, faults)
    except Exception as error:
        faults.append('admissions producer probe failed: ' + str(error))
    receipt['static_checks'] = flags
    receipt['faults'] = faults
    receipt['status'] = 'FAIL' if faults else 'PASS'
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')

    print()
    print("VERDICT:")
    if faults:
        for f in faults:
            print("  FAULT: " + f)
        return 1
    print("  115) the world is generated before it is spawned: the whole "
          "county on a fresh save, paced only once it exists, and genesis "
          "ahead of the band in the tick")
    return 0


if __name__ == "__main__":
    sys.exit(main())
