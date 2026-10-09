#!/usr/bin/env python3
"""Run the real Identity and Admissions producer against historical birth boundaries."""

from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

import world_before_spawn_test as world

ROOT = Path(__file__).resolve().parent.parent
IDENTITY = ROOT / "mod/42.20/media/lua/shared/SAO_Identity.lua"
ADMISSIONS = ROOT / "mod/42.20/media/lua/client/SAO_PopulationAdmissions.lua"
ENGINE = world.GAME / "projectzomboid.jar"
STDLIB = world.GAME / "stdlib.lua"
RUNNER = ROOT / "tools/luacheck/LuaRun.java"
JAVA = world.JDK / "java.exe"
JAVAC = world.JDK / "javac.exe"


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


host = world.ADMISSION_HOST
old = "SAO={PopulationAdmissions={},Log={line=function() end,tally=function() end}}"
new = ("__createdTally=0\n"
       "SAO={PopulationAdmissions={},Log={line=function() end,"
       "tally=function(_,kind) if kind=='created' then __createdTally=__createdTally+1 end end}}")
assert host.count(old) == 1
host = host.replace(old, new, 1)
old = "__records={} __store={} __hours=0 __building=false"
new = "__records={} __store={} __identityStore={records={},nextId=1} __hours=0 __building=false\ngetGameTime=function() return nil end"
assert host.count(old) == 1
host = host.replace(old, new, 1)
old = "assert(key=='SurvivorAwareness_Standing') return __store"
new = ("if key=='SurvivorAwareness_Records' then return __identityStore end\n"
       "    assert(key=='SurvivorAwareness_Standing') return __store")
assert host.count(old) == 1
host = host.replace(old, new, 1)
host += r'''
__birthReject={} __birthUnavailable=false __birthUnavailableIds={} __birthCalls={}
SAO.History.generatedPresentAtCountyTime=function(id)
    __birthCalls[#__birthCalls+1]=id
    if __birthUnavailable or __birthUnavailableIds[id] then
        return nil,'calendar-unavailable'
    end
    if __birthReject[id] then return false,'not-yet-born' end
    return true
end
'''

cases = r'''
local A=SAO.PopulationAdmissions
local I=SAO.Identity
local results={}
local function check(name,fn)
    local ok,result=pcall(fn)
    if not ok then print('DETAIL '..name..': '..tostring(result)) end
    results[#results+1]=name..'='..tostring(ok and result==true)
end
local function count(table)
    local n=0 for _ in pairs(table) do n=n+1 end return n
end
local function reset()
    __identityStore={records={},nextId=1}
    __store={claims={},news={}}
    __createdTally=0 __history={} __birthCalls={}
    __presence={} __learned={} __bonds={} __trust={} __saw={}
    __hours=0 __birthUnavailable=false __birthUnavailableIds={} __birthReject={}
    __building=false
    I.rebindWorld() A.rebindWorld()
end
local function seed()
    reset()
    __birthReject={['sao-1']=true,['sao-2']=true,['sao-5']=true}
    A.ensurePopulation({population=12,newcomers=12,refillDays=3},5400)
end
check('historical_genesis_has_only_born_people',function()
    seed()
    local records=I.all()
    return I.livingCount()==12 and count(records)==12
        and __identityStore.nextId==16
        and records['sao-1']==nil and records['sao-2']==nil
        and records['sao-5']==nil and records['sao-3']~=nil
        and __store.countySettled==true
end)
check('skipped_ids_have_no_person_history_or_creation_tally',function()
    seed()
    if __createdTally~=12 or #__history~=12 then return false end
    for _,row in ipairs(__history) do
        if __birthReject[row.id] or I.get(row.id)~=row.rec then return false end
    end
    return true
end)
check('eligible_mates_keep_real_unit_and_bonds',function()
    seed()
    local units={}
    for _,rec in pairs(I.all()) do
        if not rec.unitId then return false end
        units[rec.unitId]=(units[rec.unitId] or 0)+1
    end
    for _,size in pairs(units) do if size~=3 then return false end end
    return count(units)==4 and #__bonds==12 and #__trust==24
end)
check('unavailable_calendar_defers_without_consuming_id',function()
    reset()
    __birthUnavailable=true
    A.ensurePopulation({population=12,newcomers=12,refillDays=3},5400)
    local held=I.livingCount()==0 and __identityStore.nextId==1
        and __createdTally==0 and #__history==0
        and __store.countySettled~=true
    __birthUnavailable=false
    A.ensurePopulation({population=12,newcomers=12,refillDays=3},5640)
    return held and I.livingCount()==12 and __store.countySettled==true
end)
check('unavailable_mate_does_not_create_a_false_unit',function()
    reset()
    __birthUnavailableIds['sao-2']=true
    A.ensurePopulation({population=12,newcomers=12,refillDays=3},5400)
    local first=I.get('sao-1')
    local held=first and first.unitId==nil and first.unitKind==nil
        and I.livingCount()==1 and __identityStore.nextId==2
        and __createdTally==1 and #__history==1
        and __store.countySettled~=true
    __birthUnavailableIds={}
    A.ensurePopulation({population=12,newcomers=12,refillDays=3},5640)
    return held and first.unitId==nil and first.unitKind==nil
        and I.livingCount()==12 and __store.countySettled==true
        and __createdTally==12 and #__history==12
end)
check('later_refill_still_excludes_an_unborn_candidate',function()
    seed()
    __birthReject['sao-16']=true
    for _,id in ipairs({'sao-3','sao-4','sao-6','sao-7','sao-8','sao-9'}) do
        local rec=I.get(id)
        if not rec then return false end
        rec.dead=true rec.diedAtHours=24
    end
    __hours=96
    A.ensurePopulation({population=12,newcomers=12,refillDays=3},864000)
    return I.livingCount()==12 and I.get('sao-16')==nil
        and __identityStore.nextId==23 and __createdTally==18
        and #__history==18
end)
check('ordinary_creation_keeps_existing_id_path',function()
    reset()
    local rec=I.create(nil,nil,8,9,0)
    return rec and rec.id=='sao-1' and I.get('sao-1')==rec
        and __identityStore.nextId==2 and __createdTally==1
end)
__birthResult=table.concat(results,';')
'''


def main(out):
    out = Path(out)
    assert out.is_absolute() and not out.exists(), out
    for path in (IDENTITY, ADMISSIONS, ENGINE, STDLIB, RUNNER, JAVA, JAVAC):
        assert path.is_file(), path
    out.mkdir(parents=True)
    compile_run = subprocess.run([str(JAVAC), "-encoding", "UTF-8", "-cp", str(ENGINE),
                                  "-d", str(out), str(RUNNER)], cwd=out,
                                 capture_output=True, text=True, timeout=120)
    (out / "compile.log").write_text(compile_run.stdout + compile_run.stderr, encoding="utf-8")
    assert compile_run.returncode == 0, compile_run.stderr
    shutil.copy2(STDLIB, out / "stdlib.lua")
    (out / "host.lua").write_text(host, encoding="utf-8")
    (out / "cases.lua").write_text(cases, encoding="utf-8")
    original_identity = IDENTITY.read_text(encoding="utf-8")
    original_admissions = ADMISSIONS.read_text(encoding="utf-8")
    primary = ("local rec, creationReason = SAO.Identity.create(nil, nil,\n"
               "            origin.x, origin.y, origin.z, generatedBirthEligible)")
    mate = ("local mate = SAO.Identity.create(nil, nil,\n"
            "                origin.x, origin.y, origin.z, generatedBirthEligible)")
    inverted = "if admitted then id = candidate; break end"
    unit_claim = "if #mates > 1 then"
    assert original_admissions.count(primary) == original_admissions.count(mate) == 1
    assert original_identity.count(inverted) == 1
    assert original_admissions.count(unit_claim) == 1
    variants = {
        "production": (original_identity, original_admissions),
        "primary-filter-omitted": (original_identity,
                                   original_admissions.replace(primary, primary.replace(", generatedBirthEligible", ""), 1)),
        "mate-filter-omitted": (original_identity,
                                original_admissions.replace(mate, mate.replace(", generatedBirthEligible", ""), 1)),
        "rejected-id-created": (original_identity.replace(inverted, "if true then id = candidate; break end", 1),
                                original_admissions),
        "singleton-unit-claim": (original_identity,
                                 original_admissions.replace(unit_claim, "if #mates >= 1 then", 1)),
    }
    expected = set(re.findall(r"check\('([a-z0-9_]+)'", cases))
    runs = []
    for label, (identity, admissions) in variants.items():
        identity_path = out / (label + "-identity.lua")
        admissions_path = out / (label + "-admissions.lua")
        identity_path.write_text(identity, encoding="utf-8")
        admissions_path.write_text(admissions, encoding="utf-8")
        run = subprocess.run([str(JAVA), "-cp", os.pathsep.join((str(ENGINE), str(out))),
                              "LuaRun", str(out / "host.lua"), str(identity_path),
                              str(admissions_path), str(out / "cases.lua"), "--", "__birthResult"],
                             cwd=out, capture_output=True, text=True, timeout=120)
        log = out / (label + ".log")
        log.write_text(run.stdout + run.stderr, encoding="utf-8")
        values = dict(re.findall(r"([a-z0-9_]+)=(true|false)", run.stdout))
        assert run.returncode == 0 and set(values) == expected, (label, run.stdout, run.stderr)
        if label == "production":
            assert all(value == "true" for value in values.values()), (label, values)
        elif label == "primary-filter-omitted":
            assert values["historical_genesis_has_only_born_people"] == "false"
        elif label == "mate-filter-omitted":
            assert values["historical_genesis_has_only_born_people"] == "false"
        elif label == "rejected-id-created":
            assert values["skipped_ids_have_no_person_history_or_creation_tally"] == "false"
        else:
            assert values["unavailable_mate_does_not_create_a_false_unit"] == "false"
        runs.append({"name": label, "exitCode": run.returncode, "checks": values,
                     "log": log.name, "logSha256": digest(log)})
    receipt = {"schema": "sao.generated-birth-admission-proof/1", "status": "PASS",
               "inputs": {str(path.relative_to(ROOT)): digest(path)
                          for path in (IDENTITY, ADMISSIONS, RUNNER)},
               "installedEngineSha256": digest(ENGINE), "installedStdlibSha256": digest(STDLIB),
               "productionChecks": len(expected), "inverseControls": len(runs) - 1,
               "runs": runs,
               "boundary": "Real Identity and Admissions execute in installed Kahlua with a controlled tri-state History birth-time owner. Production History calendar/birth calculations are proved separately; no game, save or rendered person is observed."}
    receipt_path = out / "receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "receipt": str(receipt_path),
                      "receiptSha256": digest(receipt_path),
                      "productionChecks": len(expected), "inverseControls": len(runs) - 1}))


if __name__ == "__main__":
    assert len(sys.argv) == 2, "usage: generated_birth_admission_test.py ABSOLUTE_OUT"
    main(sys.argv[1])
