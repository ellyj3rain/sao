"""Production Perception acquisition/context with controlled native descriptors.
Actual native geometry/descriptor construction is qualified by observation_test.py.
Installed Kahlua executes the extracted unchanged production functions and saves
their plain facts. This fixture makes no native audio/playback or rendered claim.
"""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).parent
GAME=Path(r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')
JDK=Path(r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
SOURCE=ROOT/'mod/42.20/media/lua/shared/SAO_Perception.lua'
PRELUDE='''P={beliefs={},beliefVersion=0};body={}
SAO={Needs={ownsRecoveryBody=function(id,value)return id=='person' and value==body end},History={ticks=function()return __tick or 100 end}}
SAOJavaBridge={conceptObservations=function()return __view end}
finiteSoundNumber=function(v)return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
store=function(id)P.beliefs[id]=P.beliefs[id] or {};return P.beliefs[id]end
P.knownPlaces=function()return {}end
'''
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);args=ap.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 probe=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java';cases=HERE/'perception_cases.lua';jar=GAME/'projectzomboid.jar'
 files=[Path(__file__),SOURCE,cases,probe,jar,GAME/'stdlib.lua']
 absent=installed_presence(files,GAME,JDK,'D2 perception_test');
 if absent is not None:return absent
 inputs={str(p):sha(p)for p in files}
 receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':inputs,'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd):
  p=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=30);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
  receipt['runs'].append({'name':name,'exit':p.returncode,'log':str(log),'sha256':sha(log)});save();return p.returncode,log.read_text(errors='replace')
 try:
  (out/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());prelude=out/'prelude.lua';prelude.write_text(PRELUDE)
  code,log=run('compile',[JDK/'javac.exe','-cp',jar,'-d',out,probe]);assert code==0,log
  source=SOURCE.read_text(encoding='utf-8-sig');start=source.index('local function conceptCopy(row)');end=source.index('  -- Exterior leads',start) if '  -- Exterior leads' in source[start:] else source.index('-- Exterior leads',start)
  source=source[start:end]
  variants=[('baseline',None,None,None),
   ('old-room-requirement','if (frontier or row.kind=="room") and (row.buildingId==nil or row.roomId==nil) then return end','if row.buildingId==nil or row.roomId==nil then return end','outdoor_no_invented_room'),
   ('missing-audio-export','if kind then local copy=conceptCopy(row);','if false then local copy=conceptCopy(row);','placed_audio_source_exported'),
   ('foreign-view-bypass','view.actorId~=id','false','foreign_native_view_refused'),
   ('swapped-item-bypass','if current[field]~=prior[field]then return nil end','if current[field]~=prior[field] and field~=\"itemKey\" then return nil end','swapped_private_item_refused_before_native_dispatch'),
  ]
  for name,before,after,marker in variants:
   text=source
   if before:assert text.count(before)==1,name;text=text.replace(before,after,1)
   path=out/(name+'.lua');path.write_text(text)
   code,log=run(name,[JDK/'java.exe','-cp',str(out)+os.pathsep+str(jar),'PhysicalMeansLuaProbe',prelude,path,cases,'--','__conceptJoinChecks'])
   if marker:assert code!=0 and ('CONCEPT_JOIN:'+marker in log),(name,log);receipt['controls'].append({'name':name,'marker':marker})
   else:assert code==0 and 'VALUE 21' in log,log;receipt['checks']=int(float(log.split('VALUE ')[1].split()[0]))
  receipt['inputsAfter']={str(p):sha(p)for p in files};assert inputs==receipt['inputsAfter'],'input drift';receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS perception concept join',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
