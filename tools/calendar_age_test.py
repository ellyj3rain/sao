"""Installed Kahlua proof of birth-year calendar projection and retention.

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
       for name in ('history','conditions','neuro')}
FILES['cases']=ROOT/'tools/calendar_age_cases.lua'
PRELUDE='''
SAO={};require=function()end
SandboxVars={SurvivorAwareness={Neuroinflammation=true}}
-- Explicit sampling boundary: production ageOf executes its actual census.
SAO.Hash={of=function(id,salt)
    if salt=='age' or salt=='ageIn' then
        local target=id=='fixture-child' and 13 or 74
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
 ('future-clock','history','hours > current','false','future_coordinate_refused'),
 ('foreign-person','history','rec.id ~= id','false','foreign_identity_receiver_refused'),
 ('education-birth','history','profile.birthYear ~= birth','false','education_birth_conflict_refused'),
 ('education-person','history','profile.personId ~= id','false','education_foreign_person_refused'),
 ('leap-century','history','y%4 == 0 and (y%100 ~= 0 or y%400 == 0)','y%4 == 0','strict_calendar_1900-02-29T00:00:00'),
 ('age-bounds','history','math.max(0,nominal-1),nominal','nominal,nominal','unknown_birthday_bounds'),
 ('baseline-retention','conditions','age = projection.nominalAge','age = ageOf(id)','current_age_modifies_retention'),
 ('fabricated-calendar','history','if not year then out.reason = "calendar-unavailable"; return out end',
  'if not year then year=1993;instant="1993-01-01T00:00:00" end','strict_calendar_1900-02-29T00:00:00'),
 ('unavailable-hidden','conditions','metadata.status,metadata.reason = "unavailable","calendar-age-unavailable"',
  'metadata.status,metadata.reason = "available","calendar-age-unavailable"','missing_calendar_no_fabricated_date'),
 ('calendar-offset','history','instant = SAOJavaBridge:countyInstant(hours, dayZeroAsked())',
  'instant = SAOJavaBridge:countyInstant(hours + H.daysOwed()*24, dayZeroAsked())','behind_offset_uses_county_calendar'),
 ('future-born','history','year < birth','false','future_born_unavailable'),
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
    receipt={'schema':'sao.calendar-age-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],
        'boundary':__doc__,'changedContracts':['detached birth-year calendar projection','current age retention metadata']}
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
    variants=[] if args.baseline_only else CONTROLS
    for name,owner,old,new,failure in [('production',None,None,None,None),*variants]:
        sources=dict(original)
        if owner:
            assert sources[owner].count(old)==1,(name,sources[owner].count(old))
            sources[owner]=sources[owner].replace(old,new)
        for key,value in sources.items():(out/(key+'.lua')).write_text(value,encoding='utf-8')
        command=[JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out),str(package)]),'CalendarAgeProbe',
            'prelude.lua','history.lua','conditions.lua','neuro.lua','cases.lua','history.lua','conditions.lua','reload.lua','--','__result']
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
