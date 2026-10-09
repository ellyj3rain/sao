"""Installed Kahlua proof of birth-year projection and attained-age passage.

Production History/Conditions/Neuro and compiled SAORecord execute with controlled
identity/hash sampling, native time, replay state, education and moodle receivers.
No DOB is invented. This proves bounded mechanisms, not gameplay or calibration.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get("PZ_DIR", r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get("JDK_BIN", r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
FILES={name:ROOT/('mod/42.20/media/lua/shared/SAO_'+name.title()+'.lua')
       for name in ('history','census','conditions','neuro')}
FILES['cases']=ROOT/'tools/calendar_age_cases.lua'
FILES['dormant']=ROOT/'mod/42.20/media/lua/client/SAO_DormantPopulation.lua'
PRELUDE='''
SAO={};require=function()end
SAO.Log={line=function()end,tally=function()end}
SandboxVars={SurvivorAwareness={Neuroinflammation=true}}
-- Explicit sampling boundary: production ageOf executes its actual census.
SAO.Hash={of=function(id,salt)
    if salt=='age' or salt=='ageIn' then
        local target=id=='fixture-child' and 13
            or id=='ks:kid-42' and 15
            or (id=='sao-91001' or id=='sao-91002'
                or id=='sao-91003') and 18
            or (id=='sao-91004' or id=='sao-91005') and 6 or 74
        local seen=0
        for _,band in ipairs(SAO.History.bands()) do
            if target>=band.from and target<=band.to then
                return salt=='age' and seen or target-band.from
            end
            seen=seen+band.weight
        end
    end
    return 9999
end}
'''
RELOAD='''
local F=__calendarFixture
SAO.History.rebindWorld()
local v=SAO.History.calendarAgeOf('fixture-person')
F.check('module_reload_cache_free',v.status=='available' and v.nominalAge==74 and v.birthYear==1919)
F.check('module_reload_no_identity_rewrite',F.records['fixture-person'].birthYear==nil)
__result=F.result()
'''
CONTROLS=[
 ('generated-age-frozen','history','return baseline + years','return baseline','generated_attained_age_transition'),
 ('mature-historical-age','history','if year < start then return year - (start - baseline) end',
  'if year < start then return baseline end','mature_replay_age_matches_birth_year'),
 ('prenatal-presence','history','if year < saveStartYear() - baseline then',
  'if false then','generated_not_yet_born_refused'),
 ('child-prefilled-work','history','if age < 18 then\n        local changed',
  'if false then\n        local changed','historical_child_cannot_keep_adult_job'),
 ('prospective-id','history','if rec and (rec.chronology ~= nil or rec.weekOne ~= nil) then',
  'if rec == nil then','prospective_id_checked_before_identity_write'),
 ('presence-missing-calendar','history','if not year then return nil, nil, nil, "calendar-unavailable" end',
  'if not year then return saveStartYear(), 1, 1 end','generated_calendar_missing_unavailable'),
 ('presence-age-source','history','return nil, "age-source-unavailable"',
  'return nil, "calendar-unavailable"','generated_age_source_failure_is_distinct'),
 ('preschool-is-school','history','if age < 6 then\n        local changed',
  'if age < 0 then\n        local changed','newborn_has_no_school_or_six_year_history'),
 ('school-becomes-work-row','history',
  'if rec.occupation == "student" or rec.occupation == nil then\n            rec.occupation = nil\n            rec.occupationPresumed = nil',
  'if rec.occupation == "student" or rec.occupation == nil then\n            rec.occupation = "unemployed"\n            rec.occupationPresumed = nil',
  'former_student_skips_dormant_work_goal'),
 ('retained-school-worksite','history',
  'rec.occupation = nil\n            rec.occupationPresumed = nil\n            rec.workX, rec.workY = nil, nil\n            return true, marker == "school" and "school-ended"',
  'rec.occupation = nil\n            rec.occupationPresumed = nil\n            return true, marker == "school" and "school-ended"',
  'mature_school_exit_has_no_false_workplace'),
 ('earned-work-erased','history','if rec.occupation == "student" or rec.occupation == nil then\n            rec.occupation = nil',
  'if marker ~= nil then\n            rec.occupation = nil','earned_adult_work_preserved'),
 ('nil-school-worksite-retained','history',
  'if rec.occupation == "student" or rec.occupation == nil then',
  'if rec.occupation == "student" then',
  'nil_school_role_clears_stale_worksite'),
 ('adult-student-erased','history','if marker ~= nil then\n        rec.ageBoundOccupation = nil',
  'if marker ~= nil or rec.occupation == "student" then\n        rec.ageBoundOccupation = nil',
  'independent_adult_student_preserved'),
 ('knox-stage-overwritten','history',
  'if not generatedId(rec.id) or rec.chronology ~= nil\n        or rec.weekOne ~= nil then',
  'if rec.chronology ~= nil or rec.weekOne ~= nil then',
  'knox_import_preserves_school_and_work'),
 ('source-life-stage-overwritten','history',
  'if not generatedId(rec.id) or rec.chronology ~= nil\n        or rec.weekOne ~= nil then',
  'if not generatedId(rec.id) or rec.weekOne ~= nil then',
  'imported_adult_identity_unchanged'),
 ('knox-prospective-admitted','history',
  'if not generatedId(id) then return nil, "not-generated" end',
  'if false then return nil, "not-generated" end',
  'knox_not_generated_candidate'),
 ('noncanonical-generated-alias','history',
  'id:match("^sao%-[1-9]%d*$") ~= nil',
  'id:match("^sao%-%d+$") ~= nil',
  'noncanonical_generated_alias_sao-0'),
 ('child-future-trade-drawn','history',
  'if age >= 18 and not rec.occupation and SAO.Census then',
  'if not rec.occupation and SAO.Census then',
  'newborn_has_no_school_or_six_year_history'),
 ('newborn-inherits-world-months','history',
  'if ceiling then monthsAlive = math.min(monthsAlive, ceiling) end',
  'if false then monthsAlive = math.min(monthsAlive, ceiling) end',
  'newborn_has_no_school_or_six_year_history'),
 ('explicit-months-capped','history',
  'if monthsAliveOverride == nil and generatedId(id)\n        and rec.chronology == nil',
  'if generatedId(id)\n        and rec.chronology == nil',
  'explicit_history_month_override_preserved'),
 ('missing-calendar-advances-stage','history',
  'if calendarReason then return nil, calendarReason end',
  'if false then return nil, calendarReason end',
  'life_stage_holds_without_calendar'),
 ('dormant-work-guard','dormant',
  'if row and row.enginePath then\n            local work = SAO.PopulationAdmissions.workplaceFor(\n                rec, row.enginePath)',
  'if true then\n            local work = SAO.PopulationAdmissions.workplaceFor(\n                rec, row and row.enginePath)',
  'former_student_skips_dormant_work_goal'),
 ('generated-january-first-birthday','history',
  'local transition = (hashOf(id, "age-transition") % 365) + 1',
  'local transition = 1','january_first_waits_for_policy_day'),
 ('foreign-person','history','if type(rec) ~= "table" or rec.id ~= id then',
  'if type(rec) ~= "table" or false then','foreign_identity_receiver_refused'),
 ('education-birth','history','profile.birthYear ~= birth','false','education_birth_conflict_refused'),
 ('education-person','history','profile.personId ~= id','false','education_foreign_person_refused'),
 ('leap-century','history','y%4 == 0 and (y%100 ~= 0 or y%400 == 0)','y%4 == 0','strict_calendar_1900-02-29T00:00:00'),
 ('age-bounds','history','math.max(0,nominal-1),nominal','nominal,nominal','unknown_birthday_bounds'),
 ('baseline-retention','conditions','age = projection.nominalAge','age = ageOf(id)','current_age_modifies_retention'),
 ('fabricated-calendar','history','if not year then out.reason = "calendar-unavailable"; return out end',
  'if not year then year=1993;instant="1993-01-01T00:00:00" end','strict_calendar_1900-02-29T00:00:00'),
 ('unavailable-hidden','conditions','metadata.status,metadata.reason = "unavailable","calendar-age-unavailable"',
  'metadata.status,metadata.reason = "available","calendar-age-unavailable"','missing_calendar_no_fabricated_date'),
 ('calendar-offset','history','instant = SAOJavaBridge:countyInstant(projected, dayZeroAsked())',
  'instant = SAOJavaBridge:countyInstant(projected + H.daysOwed()*24, dayZeroAsked())','behind_offset_uses_county_calendar'),
 ('live-phase','history','return hours + ((civil - (hours % HOURS_PER_DAY) + HOURS_PER_DAY)\n        % HOURS_PER_DAY)',
  'return hours','native_after_replay_same_date'),
 ('earlier-live-phase','history',
  'return (atHours + civil - (current % HOURS_PER_DAY)\n        + HOURS_PER_DAY) % HOURS_PER_DAY',
  'return (atHours + civil - (current % HOURS_PER_DAY)) % HOURS_PER_DAY',
  'live_origin_at_03_current'),
 ('live-month','history','month = SAOJavaBridge:countyMonth(projected, dayZeroAsked())',
  'month = SAOJavaBridge:countyMonth(H.countyHours(), dayZeroAsked())','live_month_crosses_midnight'),
 ('date-phase','history','local instant = H.countyInstant(hours)\n    if type(instant)',
  'local instant = SAOJavaBridge:countyInstant(hours, dayZeroAsked())\n    if type(instant)',
  'live_month_midnight_date'),
 ('future-born','history','if year < birth then out.reason = "not-yet-born"; return out end',
  'if false then out.reason = "not-yet-born"; return out end','future_born_unavailable'),
 ('identity-write','history','out.birthYear,out.baselineAge = birth,baseline',
  'out.birthYear,out.baselineAge = birth,baseline; rec.birthYear=birth','native_state_reload_projection'),
]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'_scratch/d1-finish/calendar-age/verification-01')
    parser.add_argument('--baseline-only',action='store_true')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=GAME/'projectzomboid.jar';stdlib=GAME/'stdlib.lua'
    runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
    record=ROOT/'java/src/com/sao/engine/SAORecord.java'
    package=ROOT/'mod/42.20/media/java/SAO.jar'
    paths=[*FILES.values(),Path(__file__),runner,record,package,jar,stdlib,JDK/'javac.exe',JDK/'java.exe']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, GAME, JDK, "calendar age")
    if preflight is not None:
        raise SystemExit(preflight)
    def pins():return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao.calendar-age-proof/2','status':'INCOMPLETE','inputs':pins(),'runs':[],
        'boundary':__doc__,'changedContracts':['detached birth-year calendar projection',
            'current age retention metadata','generated attained-age passage']}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(command):
        result=subprocess.run(list(map(str,command)),cwd=out,text=True,capture_output=True,timeout=120)
        return result.returncode,result.stdout+result.stderr
    save()
    text=runner.read_text(encoding='utf-8').replace('public final class PhysicalMeansLuaProbe',
        'public final class CalendarAgeProbe')
    marker='        try {\n            int index=0;'
    expose='''        env.rawset("__countyCalendar",(JavaFunction)(frame,count)->{
            return frame.push(com.sao.engine.SAORecord.countyInstant(
                ((Number)frame.get(0)).intValue(),((Number)frame.get(1)).intValue(),
                ((Number)frame.get(2)).intValue(),((Number)frame.get(3)).doubleValue(),
                ((Number)frame.get(4)).intValue()));
        });
        env.rawset("__countyMonth",(JavaFunction)(frame,count)->{
            return frame.push((double)com.sao.engine.SAORecord.countyMonth0(
                ((Number)frame.get(0)).intValue(),((Number)frame.get(1)).intValue(),
                ((Number)frame.get(2)).intValue(),((Number)frame.get(3)).doubleValue(),
                ((Number)frame.get(4)).intValue()));
        });
'''
    assert text.count(marker)==1
    private=out/'CalendarAgeProbe.java';private.write_text(text.replace(marker,expose+marker),encoding='utf-8')
    code,log=run([JDK/'javac.exe','-cp',os.pathsep.join([str(jar),str(package)]),'-d',out,record,private])
    (out/'compile.log').write_bytes(log.encode('utf-8'))
    receipt['compile']={'exitCode':code,'log':'compile.log','logSha256':hashlib.sha256((out/'compile.log').read_bytes()).hexdigest()}
    save();assert code==0,log
    shutil.copyfile(stdlib,out/'stdlib.lua')
    (out/'prelude.lua').write_text(PRELUDE,encoding='utf-8')
    (out/'reload.lua').write_text(RELOAD,encoding='utf-8')
    original={key:path.read_text(encoding='utf-8') for key,path in FILES.items()}
    dormant_anchor='D.dormantLife = dormantLife'
    assert original['dormant'].count(dormant_anchor)==1
    original['dormant']=original['dormant'].replace(dormant_anchor,
        'D.probeChooseDayGoal = chooseDayGoal\n'+dormant_anchor)
    variants=[] if args.baseline_only else CONTROLS
    for name,owner,old,new,failure in [('production',None,None,None,None),*variants]:
        sources=dict(original)
        if owner:
            assert sources[owner].count(old)==1,(name,sources[owner].count(old))
            sources[owner]=sources[owner].replace(old,new)
        for key,value in sources.items():(out/(key+'.lua')).write_text(value,encoding='utf-8')
        command=[JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out),str(package)]),'CalendarAgeProbe',
            'prelude.lua','history.lua','census.lua','conditions.lua','neuro.lua','dormant.lua','cases.lua','history.lua','conditions.lua','reload.lua','--','__result']
        code,log=run(command);dest=out/(name+'.log');dest.write_bytes(log.encode('utf-8'))
        receipt['runs'].append({'name':name,'exitCode':code,'command':list(map(str,command)),
            'log':dest.name,'logSha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'expectedFailure':failure})
        save()
        if failure:assert code!=0 and 'CALENDAR_AGE:'+failure in log,log
        else:assert code==0 and 'PASS calendar age:' in log,log
        print(name+': '+next((line for line in log.splitlines() if 'VALUE ' in line or 'ERROR ' in line),log.strip()),flush=True)
    assert receipt['inputs']==pins(),'relevant sources changed during proof'
    receipt['status']='PASS';save()

if __name__=='__main__':
    try:main()
    except Exception as error:
        print('FAIL calendar age: '+str(error),file=sys.stderr)
        raise SystemExit(1)
