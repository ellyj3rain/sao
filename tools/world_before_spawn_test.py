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
     ownership, that every co-resident knows the actual starting building,
     and that existing explicit claims remain intact.

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
# installed. Places supply the building at the actual starting coordinates;
# its co-residents' location supports lived knowledge, not ownership.
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
local function learnedByEveryPerson(expected)
    if #__created~=expected or #__learned~=expected then return false end
    local seen={}
    for _,entry in ipairs(__learned) do
        local rec=__records[entry.id]
        if not rec or seen[entry.id] or entry.building~=__building
            or entry.source~='lived' or entry.tick~=0
            or rec.x~=120 or rec.y~=220 or rec.z~=1 then return false end
        seen[entry.id]=true
    end
    for _,rec in ipairs(__created) do if not seen[rec.id] then return false end end
    return true
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
    return noNewClaims() and size(__store.claims)==0 and #__learned==12
end)
check('genesis_keeps_home_origin_and_profession',function()
    ensure(reset(true))
    return references() and SAO.Identity.livingCount()==12 and #__created==12
        and __store.countySettled==true and __store.countySettledSize==12
end)
check('genesis_keeps_lived_building_knowledge',function()
    ensure(reset(true))
    if not learnedByEveryPerson(12) then return false end
    for _,entry in ipairs(__presence) do if entry.genesis~=true then return false end end
    return true
end)
check('mates_do_not_inherit_trade_anchor',function()
    ensure(reset(true))
    local primaries,mates=0,0
    for _,rec in ipairs(__created) do
        if rec.unitId==rec.id..'-u' then
            primaries=primaries+1
            if not rec.originAnchored or not rec.knowsTradeGround then return false end
        else
            mates=mates+1
            if rec.originAnchored or rec.knowsTradeGround then return false end
        end
    end
    return primaries==4 and mates==8 and learnedByEveryPerson(12)
end)
check('small_population_keeps_every_origin_witness',function()
    for _,population in ipairs({2,5,7}) do
        ensure(reset(true,population))
        if SAO.Identity.livingCount()~=population or not learnedByEveryPerson(population)
            or not noNewClaims() then return false end
    end
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
        and SAO.Identity.livingCount()==12 and #__learned==18
end)
check('refill_all_admitted_people_learn_origin',function()
    refill(true)
    return learnedByEveryPerson(18)
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
    'mates_do_not_inherit_trade_anchor', 'small_population_keeps_every_origin_witness',
    'road_keeps_navigation_without_building_knowledge', 'genesis_keeps_units_bonds_and_mutual_sight',
    'road_refill_creates_no_claims', 'located_building_refill_creates_no_claims',
    'explicit_claim_survives_admissions', 'refill_keeps_arrival_and_presence_times',
    'refill_keeps_six_person_pace_after_wait', 'refill_all_admitted_people_learn_origin',
}

COHORT_CASES = r'''
local A=SAO.PopulationAdmissions
local hash=string.rep('a',64)
local sites={{id='residential',x=100,y=200,z=0},{id='services',x=300,y=200,z=0},
    {id='farm',x=500,y=200,z=0}}
local wanted={residential=4,services=4,farm=4}
local results={}
local function reset()
    A.rebindWorld()
    __records={} __created={} __history={} __presence={} __learned={}
    __bonds={} __trust={} __saw={} __claimCalls={} __groundCalls=0
    __store={claims={},news={}} __hours=0
    SpawnRegionMgr.getSpawnRegions=function() return {{name='Native regional origins',points={
        unemployed={{posX=100,posY=200,posZ=0},{posX=300,posY=200,posZ=0},{posX=500,posY=200,posZ=0}},
        nurse={{posX=300,posY=200,posZ=0}}
    }}} end
    SAO.Rand.int=function(limit) return limit==100 and 90 or 0 end
    SAO.Places.at=function(x,y) return {key=tostring(x)..':'..tostring(y)} end
    SAO.Body.get=function() return nil end
    return {population=12,newcomers=12,refillDays=3}
end
local function stage()
    return A.stageInitialPeople(hash,'NativeSave',wanted,sites,12)
end
local function run()
    local conf=reset() assert(stage()) A.ensurePopulation(conf,5400) return conf
end
local function check(name,fn)
    local ok,value=pcall(fn)
    if not ok then results[#results+1]='detail:'..name..':'..tostring(value) end
    results[#results+1]=name..'='..tostring(ok and value==true)
end
check('initial_three_native_origin_sites',function()
    run()
    local snap=A.initialPeopleSnapshot()
    if #__created~=12 or snap.generated~=12 or snap.represented~=0 or snap.status~='generated'
        or __store.countySettled~=true then return false end
    for _,site in ipairs(sites) do
        local row=snap.sites[site.id]
        if row.generated~=4 or #row.actualIds~=4 then return false end
        for _,id in ipairs(row.actualIds) do
            local rec=__records[id]
            if rec.x~=site.x or rec.y~=site.y or rec.z~=site.z or rec.homeX~=site.x
                or rec.initialStudyOrigin.siteId~=site.id then return false end
        end
    end
    return true
end)
check('initial_units_clamp_to_site_quota',function()
    run()
    local units={}
    for _,rec in ipairs(__created) do
        if rec.unitId then
            units[rec.unitId]=units[rec.unitId] or {count=0,siteId=rec.initialStudyOrigin.siteId}
            local u=units[rec.unitId]
            if u.siteId~=rec.initialStudyOrigin.siteId then return false end
            u.count=u.count+1
        end
    end
    local n=0 for _,u in pairs(units) do if u.count~=3 then return false end n=n+1 end
    return n==3 and #__bonds==9 and #__saw==18
end)
check('initial_keeps_history_presence_and_lived_witness',function()
    run()
    if #__history~=12 or #__presence~=12 or #__learned~=12 or #__claimCalls~=0 then return false end
    for i,rec in ipairs(__created) do
        if rec.occupation~='nurse' or __presence[i].genesis~=true or __learned[i].id~=rec.id
            or __learned[i].building.key~=tostring(rec.x)..':'..tostring(rec.y) then return false end
    end
    return true
end)
check('initial_trade_anchor_stays_in_declared_site',function()
    run()
    for _,rec in ipairs(__created) do
        if rec.initialStudyOrigin.siteId~='services' and (rec.x==300 or rec.originAnchored) then return false end
    end
    return __records['person-5'].originAnchored==true
end)
check('initial_rebind_replay_keeps_exact_people',function()
    local conf=run()
    __records['person-1'].x=900
    __records['person-1'].dead=true __records['person-1'].diedAtHours=1
    A.rebindWorld() assert(stage()) A.ensurePopulation(conf,5401)
    return #__created==12 and __records['person-1'].x==900
        and A.initialPeopleSnapshot().generated==12
end)
check('initial_representation_is_native_body_truth',function()
    run()
    SAO.Body.get=function(id) return id=='person-9' and {} or nil end
    local snap=A.initialPeopleSnapshot()
    return snap.generated==12 and snap.represented==1 and snap.sites.farm.represented==1
        and snap.sites.residential.represented==0
end)
check('initial_placement_requires_exact_source_and_native_body_truth',function()
    run()
    local rec=__records['person-9']
    rec.initialStudyPlacement={definitionSha256=string.rep('b',64),saveName='NativeSave',siteId='farm',
        status='represented',causeAvailable=true}
    local snap=A.initialPeopleSnapshot()
    if snap.sites.farm.placement[rec.id].status~='unobserved' or snap.represented~=0 then return false end
    rec.initialStudyPlacement={definitionSha256=hash,saveName='NativeSave',siteId='farm',
        status='refused',reason='native-square-unavailable',causeAvailable=true,observedAtCountyHours=123}
    snap=A.initialPeopleSnapshot()
    return snap.sites.farm.placement[rec.id].reason=='native-square-unavailable'
        and snap.sites.farm.placement[rec.id].observedAtCountyHours==123 and snap.represented==0
end)
check('initial_snapshot_does_not_publish_requested_as_generated',function()
    reset() assert(stage())
    local snap=A.initialPeopleSnapshot()
    return snap.target==12 and snap.generated==0 and snap.represented==0
        and #snap.sites.farm.actualIds==0 and snap.status=='staged'
end)
check('initial_foreign_binding_refused',function()
    run() A.rebindWorld()
    local ok,reason=A.stageInitialPeople(string.rep('b',64),'NativeSave',wanted,sites,12)
    return ok==false and reason=='initial-cohort-binding-differs' and #__created==12
end)
check('initial_changed_quota_refused',function()
    run() A.rebindWorld()
    local ok,reason=A.stageInitialPeople(hash,'NativeSave',{residential=3,services=5,farm=4},sites,12)
    return ok==false and reason=='initial-cohort-definition-differs'
end)
check('initial_too_late_staging_refused',function()
    local conf=reset() A.ensurePopulation(conf,5400)
    local ok,reason=stage()
    return ok==false and reason=='initial-cohort-staged-after-genesis'
end)
check('initial_missing_identity_refused_without_replacement',function()
    run() __records['person-9']=nil A.rebindWorld()
    local ok,reason=stage()
    return ok==false and reason=='initial-cohort-identity-provenance-differs' and #__created==12
end)
check('initial_wrong_site_provenance_refused',function()
    run() __records['person-9'].initialStudyOrigin.x=100 A.rebindWorld()
    local ok,reason=stage()
    return ok==false and reason=='initial-cohort-identity-provenance-differs'
end)
check('initial_native_origin_missing_defers_its_site',function()
    local conf=reset()
    SpawnRegionMgr.getSpawnRegions=function() return {{name='Only residential',points={
        unemployed={{posX=100,posY=200,posZ=0}}
    }}} end
    assert(stage()) A.ensurePopulation(conf,5400)
    local snap=A.initialPeopleSnapshot()
    return #__created==4 and snap.generated==4 and snap.sites.services.generated==0
        and snap.status=='deferred' and snap.reason=='native-origin-unavailable:services'
        and __store.countySettled~=true
end)
check('initial_creation_refusal_preserves_partial_exact_ids',function()
    local conf=reset() assert(stage())
    local original=SAO.Identity.create
    SAO.Identity.create=function(a,b,x,y,z)
        if #__created>=5 then return nil end
        return original(a,b,x,y,z)
    end
    A.ensurePopulation(conf,5400)
    local snap=A.initialPeopleSnapshot()
    SAO.Identity.create=original
    if snap.generated~=5 or snap.status~='deferred' or __store.countySettled then return false end
    A.ensurePopulation(conf,5640)
    snap=A.initialPeopleSnapshot()
    return #__created==12 and snap.generated==12 and snap.sites.farm.generated==4
        and snap.status=='generated' and #__history==12
end)
check('initial_invalid_native_population_refused',function()
    reset()
    local ok,reason=A.stageInitialPeople(hash,'NativeSave',{residential=501},sites,501)
    return ok==false and reason=='invalid-initial-cohort-binding'
end)
__cohortResult=table.concat(results,';')
'''

COHORT_EXPECTED = set(re.findall(r"check\('([a-z0-9_]+)'", COHORT_CASES))

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
    mate_learning = '''            if startedIn then
                pcall(function()
                    SAO.Perception.learnBuilding(mate.id, startedIn, 0, "lived")
                end)
            end
'''
    mate_identity = '            mate.unitId, mate.unitKind = unitId, kind'
    if source.count(mate_learning) != 1 or source.count(mate_identity) != 1:
        faults.append('co-resident origin mutation anchor drifted')
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
                ('spawn-claim-restored', source.replace(anchor, SPAWN_CLAIM_BLOCK + anchor, 1)),
                ('co-resident-knowledge-omitted', source.replace(mate_learning, '', 1)),
                ('borrow-leader-trade', source.replace(mate_identity,
                    '            mate.originAnchored = rec.originAnchored\n'
                    '            mate.knowsTradeGround = rec.knowsTradeGround\n' + mate_identity, 1))):
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
            elif label == 'spawn-claim-restored':
                defect_cases = {name for name in ADMISSION_EXPECTED if name.endswith('creates_no_claims')}
                if any(checks[name] != 'false' for name in defect_cases) \
                        or checks['genesis_keeps_home_origin_and_profession'] != 'true' \
                        or checks['genesis_keeps_units_bonds_and_mutual_sight'] != 'true':
                    faults.append('restored production claim block did not expose invented ownership\n'
                                  + result.stdout + result.stderr)
                    return
                print('  PASS restored production claim block fails all four ownership cases')
            elif label == 'co-resident-knowledge-omitted':
                if checks['genesis_keeps_lived_building_knowledge'] != 'false' \
                        or checks['refill_all_admitted_people_learn_origin'] != 'false' \
                        or checks['small_population_keeps_every_origin_witness'] != 'false' \
                        or checks['road_keeps_navigation_without_building_knowledge'] != 'true' \
                        or checks['genesis_keeps_units_bonds_and_mutual_sight'] != 'true':
                    faults.append('omitted co-resident knowledge did not expose the per-person defect\n'
                                  + result.stdout + result.stderr)
                    return
                print('  PASS omitted co-resident knowledge fails genesis, refill and small populations')
            elif label == 'borrow-leader-trade':
                if checks['mates_do_not_inherit_trade_anchor'] != 'false' \
                        or checks['genesis_keeps_lived_building_knowledge'] != 'true':
                    faults.append('borrowed leader trade did not expose invented anchoring\n'
                                  + result.stdout + result.stderr)
                    return
                print('  PASS borrowed leader trade fails independent profession anchoring')
        receipt['producer_status'] = 'PASS'
        cohort_cases = work / 'cohort-cases.lua'
        cohort_cases.write_text(COHORT_CASES, encoding='utf-8')
        controls = (
            ('initial-owner-omitted', 'store.initialStudyPeople, initialCohort = cohort, cohort',
             'store.initialStudyPeople = cohort', 'initial_three_native_origin_sites'),
            ('initial-unit-quota-omitted', 'if siteId then size = math.min(size, remaining) end',
             '', 'initial_units_clamp_to_site_quota'),
            ('initial-trade-reanchor-unbounded', 'pickOriginFor(row.enginePath, siteId)',
             'pickOriginFor(row.enginePath)', 'initial_trade_anchor_stays_in_declared_site'),
            ('initial-binding-check-omitted', 'prior.definitionSha256 ~= definitionSha256 or prior.saveName ~= saveName',
             'prior.saveName ~= saveName', 'initial_foreign_binding_refused'),
            ('initial-too-late-check-omitted', 'if store.countySettled or existingPeople then',
             'if false then', 'initial_too_late_staging_refused'),
            ('initial-replay-owner-omitted', 'if prior then', 'if false then',
             'initial_rebind_replay_keeps_exact_people'),
            ('initial-site-proof-omitted', 'or siteFor(origin, cohort.sites) ~= site.id then',
             'then', 'initial_wrong_site_provenance_refused'),
            ('initial-request-published-as-count', 'generated = 0, represented = 0, sites = {}',
             'generated = initialCohort.target, represented = 0, sites = {}',
             'initial_snapshot_does_not_publish_requested_as_generated'),
        )
        variants = [('initial-production', source, None)]
        for label, before, after, defect in controls:
            if source.count(before) != 1:
                faults.append('initial population mutation anchor drifted: ' + label)
                return
            changed = source.replace(before, after, 1)
            assert changed != source, 'initial mutation did not land: ' + label
            variants.append((label, changed, defect))
        for label, content, defect in variants:
            path = work / (label + '.lua')
            path.write_text(content, encoding='utf-8')
            result = run([JDK / 'java.exe', '-cp', os.pathsep.join(map(str, (engine, work))),
                          'LuaRun', host, path, cohort_cases, '--', '__cohortResult'], label)
            checks = dict(re.findall(r'([a-z0-9_]+)=(true|false)', result.stdout))
            receipt[label] = checks
            if result.returncode or set(checks) != COHORT_EXPECTED:
                faults.append(label + ' did not execute every initial population case\n'
                              + result.stdout + result.stderr)
                return
            if defect is None and any(value != 'true' for value in checks.values()):
                faults.append('initial population producer failed: ' + result.stdout + result.stderr)
                return
            if defect and checks[defect] != 'false':
                faults.append('initial population control survived: ' + label)
                return
            print('  PASS ' + (str(len(checks)) + ' initial population cases in installed Kahlua'
                  if defect is None else 'initial population control refused: ' + label))
        receipt['initial_population_status'] = 'PASS'


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
