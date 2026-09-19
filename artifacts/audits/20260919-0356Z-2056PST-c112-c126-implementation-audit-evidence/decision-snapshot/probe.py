import sys, pathlib, shutil, subprocess, json
root=pathlib.Path.cwd()
sys.path.insert(0, str(root/'tools'))
import county_dump as Dump
import county_sweep as Sweep
work=pathlib.Path(sys.argv[1])
shutil.copy2(Sweep.STDLIB, work/'stdlib.lua')
for p in Sweep.OUT.glob('*.class'): shutil.copy2(p,work/p.name)
setup=r'''
local state={groups={a='g',b='g'}, yearsRun=1, yearsOwed=1}
local records={a={forename='A',surname='A',designation='before',stage='decision-time'},b={forename='B',surname='B'}}
local beliefs={a={known={stage='decision-time',tick=10}},b={}}
ModData={getOrCreate=function() return state end}
SAO={Identity={get=function(id) return records[id] end,all=function() return records end},
 Perception={beliefs=beliefs},History={countyHours=function() return 1 end},
 Standing={electLeader=function() records.a.designation='chosen' end}}
local count=0
_G.__handlers={OnTick=function()
 count=count+1
 if count==1 then SAO.Standing.electLeader('g') end
 if count==2 then records.a.stage='future';records.a.designation='later';beliefs.a.known.stage='future';beliefs.a.futureKnowledge={tick=200} end
end}
'''
pre=work/'snapshot-control.lua';pre.write_text(setup,encoding='utf-8')
cmd=[str(Sweep.JDK/'java.exe'),'-cp',str(Sweep.PZ)+';.','LuaRun',str(pre),'--',Dump.RUN.replace('RUN_NAME','snapshot-audit')]
done=subprocess.run(cmd,cwd=work,capture_output=True,text=True,timeout=30)
(work/'stdout.txt').write_text(done.stdout,encoding='utf-8')
if done.returncode: raise SystemExit(done.stdout+done.stderr)
row=json.loads(done.stdout.split('VALUE ',1)[1])
m=row['rows'][0]['roster'][0]
result={'captureFailures':row['captureFailures'],'decisionHours':row['rows'][0]['hours'],'recordStage':m['record']['stage'],'beliefStage':m['beliefs']['known']['stage'],'futureKnowledge':m['beliefs'].get('futureKnowledge'),'designationBefore':m['designationBefore'],'designationAfter':m['designationAfter'],'recordDesignation':m['record']['designation']}
(work/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'scratch':str(work),'result':result},indent=2))
assert result['recordStage']=='future' and result['beliefStage']=='future'
assert result['designationBefore']=='before' and result['designationAfter']=='chosen'
assert result['captureFailures']==0
