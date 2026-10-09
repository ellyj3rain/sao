"""Original Art consumption/outcome after correlated multi-supply acquisition retry.

Native installed item definitions/factory, original Lifestyle palette consumption,
and actual Planner/SourceUse/Acquisition/Art owners execute in Kahlua. Source
transport, body/station observation, route arrival and callback hosts are controlled.
Native physical transfer and rendered gameplay are qualified separately.
"""
import argparse, hashlib, json, os, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];HERE=ROOT/'tools';LUA=ROOT/'mod/42.20/media/lua'
GAME=Path(os.environ.get('PZ_GAME_DIR',os.environ.get('PZ_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
SOURCE=Path(os.environ.get('LIFESTYLE_LUA',r'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3403870858/mods/Lifestyle/common/media/lua'))
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--required',action='store_true');args=ap.parse_args()
 helper=HERE/'native_proof_preflight.py'
 if not helper.is_file():print('FAILED D2 acquisition Art: owned proof inputs absent: '+str(helper));return 1
 from native_proof_preflight import presence
 owners=[LUA/'shared/SAO_WorldSources.lua',LUA/'shared/SAO_ProceduralPlanning.lua',LUA/'client/SAO_SourceUse.lua',LUA/'client/SAO_LeisureAcquisition.lua',LUA/'client/SAO_LeisureArt.lua']
 probe=HERE/'instrument_checks/InstrumentProbe.java';metadata=HERE/'d2_leisure_materials/metadata.java.inc'
 helpers=[HERE/'luacheck/MovementCrossingProbe.java',HERE/'luacheck/ResourceApproachProbe.java',HERE/'cognition_checks/CognitionUseProbe.java']
 cases=HERE/'d2_leisure_acquisition_art_cases.lua';fixture=HERE/'d2_leisure_art/fixture.lua'
 owned=[Path(__file__),helper,probe,metadata,*helpers,*owners,cases,fixture,HERE/'source_use_test.py',args.jar.resolve()]
 script=SOURCE.parent/'scripts/Lifestyle_items.txt'
 libraries=[*sorted((SOURCE/'client/Painting/lib').glob('*.lua')),*sorted((SOURCE/'client/Painting/Sculpting/lib').glob('*.lua')),SOURCE/'client/Painting/Quality.lua']
 source=[SOURCE/p for p in ['shared/LSUtil.lua','shared/LSSync.lua','shared/Art/ArtFunctions.lua','shared/Art/PaintingMarkings.lua']]
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',*sorted((GAME/'jars').glob('*.jar'))]
 installed=[*jars[1:],GAME/'stdlib.lua',script,*libraries,*source,*native,JDK/'java.exe',JDK/'javac.exe',*[GAME/'media/scripts/generated/items'/p for p in ['normal.txt','weapon.txt']]]
 ready=presence(owned,installed,args.required,'D2 acquisition Art')
 if ready is not None:return ready
 import source_use_test as transport
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 inputs=owned+installed;receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[],'controls':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,work):
  done=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(done.stdout+done.stderr)
  receipt['runs'].append({'name':name,'exitCode':done.returncode,'sha256':sha(log)});save();return done.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  table=out/'items.tsv';table.write_text(''.join(str(script)+'\tLifestyle\t'+n+'\n'for n in ['oldPaintBrush','paintPalette','paintPaletteEmpty']),encoding='utf-8')
  java=probe.read_text().replace('public final class InstrumentProbe','public final class AcquisitionArtProbe')
  java=java.replace('public static void main(String[] args)throws Exception{',metadata.read_text()+'\npublic static void main(String[] args)throws Exception{\nThread.setDefaultUncaughtExceptionHandler((t,e)->{e.printStackTrace();System.exit(1);});')
  java=java.replace('InventoryItem.class,zombie.inventory.ItemContainer.class','zombie.scripting.ScriptManager.class,zombie.inventory.types.DrainableComboItem.class,InventoryItem.class,zombie.inventory.ItemContainer.class')
  injection='''LuaCompiler.register(env);
var materialDictionary=new MaterialDictionary();data.set(null,materialDictionary);var nativeItems=platform.newTable();short materialId=5000;
for(var row:Files.readAllLines(Path.of(TABLE))){var p=row.split("\\t",3);var it=material(Path.of(p[0]),p[1],p[2],materialId++,materialDictionary);nativeItems.rawset(it.getFullType(),it);}
env.rawset("__nativeItems",nativeItems);env.rawset("__scriptManager",ScriptManager.instance);env.rawset("__nativeItemTag",env.rawget("ItemTag"));
env.rawset("__requirements",(JavaFunction)(f,n)->f.push(com.sao.engine.SAOLeisureMaterials.requirements(null,(String)f.get(0))));
'''.replace('TABLE',json.dumps(str(table)))
  java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
  java=java.replace('System.out.println("INSTRUMENT_NATIVE_DONE");','System.out.println("INSTRUMENT_NATIVE_DONE");System.exit(0);')
  generated=out/'AcquisitionArtProbe.java';generated.write_text(java,encoding='utf-8')
  prelude=out/'source-prelude.lua';prelude.write_text(transport.ACTION_PRELUDE+'\n__sourceHost=SAO;__sourceBridge=SAOJavaBridge;__sourceEvents=Events;__proofPrint=print\n',encoding='utf-8')
  lib=out/'libraries.lua';lib.write_text('__libraries={}\n'+''.join('__libraries['+json.dumps(str(p.relative_to(SOURCE/'client')).replace('\\','/')[:-4])+']=(function()\n'+p.read_text(encoding='utf-8-sig')+'\nend)()\n'for p in libraries),encoding='utf-8')
  setup=out/'join.lua';setup.write_text('''
print=__proofPrint;Events=__sourceEvents
ModData.get=function(k)return __stores[k]end
SAO.Body=__sourceHost.Body;SAO.Places=__sourceHost.Places;SAO.Locomotion=__sourceHost.Locomotion;SAO.Log=__sourceHost.Log
SAO.Controller={agents={}};SAO.ProceduralPlanning=nil
SAO.Perception.knownPlaces=__sourceHost.Perception.knownPlaces
SAO.Perception.learnInspectedSource=function()return true end
for k,v in pairs(__sourceHost.Standing)do SAO.Standing[k]=v end
SAO.Needs.busy=__sourceHost.Needs.busy;SAO.Needs.worldSourceTransferAction=__sourceHost.Needs.worldSourceTransferAction
local queueArt=SAO.Needs.queueVerified
SAO.Needs.queueVerified=function(a)if a.kind then return __sourceHost.Needs.queueVerified(a)end;return queueArt(a)end
ISTimedActionQueue.clear=function()local a=__queued;__queued=nil;__busy=false;if a and a.stop then a:stop()end end
for k,v in pairs(__sourceBridge)do SAOJavaBridge[k]=v end
SAOJavaBridge.leisureMaterialRequirements=function(_,body,t)return __requirements(t)end
SAOJavaBridge.carriedWorldTransferItem=function()return __transfer end
getScriptManager=function()return __scriptManager end;ItemTag=__nativeItemTag
''',encoding='utf-8')
  with tempfile.TemporaryDirectory(prefix='sao-acquisition-art-')as tmp:
   work=Path(tmp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes());cp=os.pathsep.join(map(str,jars))
   status,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert status==0,log
   controls=[('lose-retry-chain',owners[1],'if not a.resultId and a.sourceId==exact.sourceId','if false and a.sourceId==exact.sourceId','palette_retry_same_original_purpose'),
             ('forget-original-purpose',owners[1],'local purpose = acquired or leisurePurpose','local purpose = leisurePurpose','art_use_same_original_purpose'),
             ('invent-palette-consumption',SOURCE/'shared/LSUtil.lua','item:UseAndSync()','do end','original_palette_native_consumption')]
   for name,target,before,after,marker in [('baseline',None,None,None,None),*controls]:
    paths=[prelude,fixture,*native,lib,*source,setup,*owners,cases]
    if target:
     text=target.read_text(encoding='utf-8-sig');assert before in text,(name,before);changed=out/(name+'.lua');changed.write_text(text.replace(before,after),encoding='utf-8');paths=[changed if p==target else p for p in paths]
    status,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'AcquisitionArtProbe',GAME,*paths],work)
    if marker:assert status!=0 and 'D2_ACQUISITION_ART:'+marker in log,(name,log[-8500:]);receipt['controls'].append({'name':name,'failedCheck':marker})
    else:assert status==0 and 'PASS D2 acquisition Art 'in log,log[-8500:];receipt['checks']=int(log.split('PASS D2 acquisition Art ')[1].splitlines()[0])
  receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift';receipt['status']='PASS'
 except Exception as e:receipt['status']='FAIL';receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS D2 acquisition Art',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
