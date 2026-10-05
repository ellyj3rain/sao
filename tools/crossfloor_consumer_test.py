"""Native P-row acquisition through production floor-aware conflict and work consumers.

Installed Lua owners execute; native scanner text and combat/movement admission
are controlled. Different-floor visibility never supplies contact reach or an
automatic safe choice. The real scanner/window proof remains separate.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import conflict_response_test as existing
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parents[1]
FILES=dict(existing.FILES)
FILES.update(perception=ROOT/'mod/42.20/media/lua/shared/SAO_Perception.lua',labor=ROOT/'mod/42.20/media/lua/shared/SAO_Labor.lua',
    floor_cases=ROOT/'tools/crossfloor_consumer_cases.lua')
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,default=ROOT/'_scratch/d1-crossfloor-consumers/verification-01')
    args=ap.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=fixture.GAME/'projectzomboid.jar';paths=[*FILES.values(),Path(__file__),Path(existing.__file__),Path(fixture.__file__),fixture.RUNNER,jar,fixture.GAME/'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "crossfloor consumer")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao-crossfloor-consumer-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],'boundary':__doc__}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(command):
        p=subprocess.run(list(map(str,command)),cwd=out,text=True,capture_output=True,timeout=120);return p.returncode,p.stdout+p.stderr
    save();command=[fixture.JDK/'javac.exe','-cp',jar,'-d',out,fixture.RUNNER];code,log=invoke(command)
    receipt['compile']={'command':list(map(str,command)),'exit':code};save();assert code==0,log
    shutil.copyfile(fixture.GAME/'stdlib.lua',out/'stdlib.lua')
    (out/'prelude.lua').write_text(fixture.PRELUDE+'\nrequire=function()end\n__legacyPerception={} for k,v in pairs(SAO.Perception)do __legacyPerception[k]=v end\n',encoding='utf-8')
    originals={k:p.read_text(encoding='utf-8') for k,p in FILES.items()}
    originals['controller']=originals['controller'].replace('return Ctl\n',fixture.EXPOSE.replace('return Ctl\n','Ctl.__floorProbeHostile=nearestHostilePerson\nreturn Ctl\n'))
    variants=[('production',None,None,None,None),
        ('drop-hostile-floor','controller','z = best.z, dist = bestDist','dist = bestDist','hostile_reader_preserves_floor'),
        ('drop-frame-floor','response','z=threat.z,observerZ=math.floor(body:getZ()),','-- floor dropped','executor_preserves_floor_evidence'),
        ('xy-close-only','models','and threat.distance<=3 and same~=false','and threat.distance<=3','shared_close_excludes_known_other_floor'),
        ('drop-labor-floor','labor','danger.nearest.z,danger.nearest.observerZ=nearest.z,target.z','-- geometry dropped','labor_keeps_floor_and_unknown_reach'),
        ('drop-parsed-floor','perception','z = observedFloor, dist = d','dist = d','actual_p_row_retains_floor')]
    for name,key,old,new,marker in variants:
        sources=dict(originals)
        if old:assert sources[key].count(old)==1,(name,sources[key].count(old));sources[key]=sources[key].replace(old,new,1)
        sources['cases']=sources['cases']+'\n'+sources.pop('floor_cases')
        sources['cases']=sources['cases'].replace('if not value then error("CROSSFLOOR:"..name)end','__lastFloorCheck=name;if not value then error("CROSSFLOOR:"..name)end')
        sources['cases']='local function runCases()\n'+sources['cases']+'\nend\nlocal ok,why=pcall(runCases);if not ok then error(tostring(why).." after CROSSFLOOR:"..tostring(__lastFloorCheck))end\n'
        for k,value in sources.items():(out/(k+'.lua')).write_text(value,encoding='utf-8')
        (out/'capture.lua').write_text('__floorPerception=SAO.Perception;__legacyPerception.sortEvidence=SAO.Perception.sortEvidence;SAO.Perception=__legacyPerception\n',encoding='utf-8')
        command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out)]),'LuaRun','prelude.lua',
            *[k+'.lua' for k in FILES if k not in ('cases','floor_cases','perception','labor')],
            'perception.lua','labor.lua','capture.lua','cases.lua','--','__result']
        code,log=invoke(command);(out/(name+'.log')).write_bytes(log.encode('utf-8'))
        receipt['runs'].append({'name':name,'exit':code,'command':list(map(str,command)),'marker':marker,
            'logSha256':hashlib.sha256((out/(name+'.log')).read_bytes()).hexdigest(),
            'mutation':{'source':key,'before':old,'after':new} if old else None});save()
        assert (code!=0 and 'CROSSFLOOR:'+marker in log) if marker else (code==0 and 'PASS crossfloor consumers:' in log),log
        print(name+': '+next((line for line in log.splitlines() if 'VALUE ' in line or 'ERROR ' in line),log.strip()),flush=True)
    receipt['inputs_after']=pins();assert receipt['inputs_after']==receipt['inputs'],'source inputs changed';receipt['status']='PASS';save()
if __name__=='__main__':main()
