"""Actual WorldSources candidate and Perception in installed Kahlua; controlled native protocol receiver."""
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import hashlib, json, os, re, shutil, subprocess, tempfile
HERE=Path(__file__).resolve().parent
from config import ROOT, OUT, GAME, JDK
sys.path.insert(0,str(ROOT/'tools'))
import private_inventory_test as inventory
import source_use_test as source
PZ=GAME/'projectzomboid.jar'
W=ROOT/'mod/42.20/media/lua/shared/SAO_WorldSources.lua'
P=ROOT/'mod/42.20/media/lua/shared/SAO_Perception.lua'
CONTROLS=[
    ('ignore-explicit-source','(sourceId == nil or row.id == sourceId)','true','exact_target_selected_without_fallback'),
    ('forbid-known-explicit-source','(sourceId ~= nil or not personallyInspected(known, row))','not personallyInspected(known, row)','explicit_known_target_can_be_reinspected'),
    ('skip-target-permission','if not (SAO.Standing and SAO.Standing.mayTakeCurrent\n        and SAO.Standing.mayTakeCurrent(actorId, context.sourceX, context.sourceY,\n            context.admission)) then return false, "current-claim-refused" end','if false then return false, "current-claim-refused" end','target_permission_rechecked_before_native_fill'),
]
def main():
    fp='a'*64
    target={'id':'C:target:0','fp':fp,'rev':'empty-1','kind':'container','x':11,'y':11,'building':-1,'state':'spent','quantities':{},'items':[]}
    candidate=f'H|protocol=SAOWI1\nC|id=C:first:0|fp={fp}|sx=11|sy=11|sz=0|x=10|y=11|z=0|reachable=1\nC|id=C:target:0|fp={fp}|sx=11|sy=11|sz=0|x=10|y=11|z=0|reachable=1\nE\n'
    snapshot='I|source=C:target:0\n'+source.snapshot(1,1,'chunk-empty',[target])
    prelude=inventory.INSPECTION_PRELUDE+'\ncandidateText=[=['+candidate+']=]\nsnapshotText=[=['+snapshot+']=]\n'
    receipt={'boundary':__doc__,'inputs':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [W,P,HERE/'inspection_cases.lua',PZ]},'runs':[],'controls':[]}
    try:
        with tempfile.TemporaryDirectory(prefix='inspection-') as directory:
            work=Path(directory);shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua')
            pre=work/'prelude.lua';pre.write_text(prelude,encoding='utf-8')
            debug_case = work/'cases.lua'
            case_text = (HERE/'inspection_cases.lua').read_text(encoding='utf-8')
            case_text = re.sub(r'(^|\n)(check\("([a-z_]+)",)', lambda m:m[1]+'__stage="'+m[3]+'"\n'+m[2],case_text)
            debug_case.write_text('local ok, why = pcall(function()\n'+case_text+'\nend)\nif not ok then error("at "..tostring(__stage)..": "..tostring(why)) end\n',encoding='utf-8')
            def run(label, args):
                done=subprocess.run(list(map(str,args)),cwd=work,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
                receipt['runs'].append({'name':label,'exit':done.returncode,'stdout':done.stdout,'stderr':done.stderr})
                return done
            done=run('compile',[JDK/'javac.exe','-cp',PZ,'-d',work,ROOT/'tools/luacheck/LuaRun.java'])
            if done.returncode:raise RuntimeError(done.stderr)
            def execute(label, ws):
                return run(label,[JDK/'java.exe','-Djava.awt.headless=true','-cp',str(work)+os.pathsep+str(PZ),'LuaRun',pre,ws,P,debug_case,'--','RESULT'])
            done=execute('candidate',W)
            if done.returncode or 'PASS cooking exact inspection ' not in done.stdout: raise RuntimeError(done.stdout+done.stderr)
            receipt['cases']=int(re.search(r'PASS cooking exact inspection (\d+)',done.stdout)[1])
            baseline=W.read_text(encoding='utf-8-sig')
            for label,before,after,target in CONTROLS:
                if baseline.count(before)!=1:raise RuntimeError(label+': mutation anchor must match once')
                changed=baseline.replace(before,after,1);path=work/(label+'.lua');path.write_text(changed,encoding='utf-8')
                done=execute(label,path)
                if not done.returncode or 'ERROR ' not in done.stdout or target not in done.stdout:raise RuntimeError(label+': named target did not fail: '+done.stdout)
                receipt['controls'].append({'name':label,'target':target,'source_sha256':hashlib.sha256(changed.encode()).hexdigest(),'verdict':'false'})
            receipt['status']='passed'
    except Exception as error:
        receipt['status']='failed';receipt['error']=str(error)
    (OUT/'inspection-verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:receipt.get(k) for k in ('status','cases','error')}))
    return 0 if receipt['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
