"""Native keep-input card/dice recipes, actual shells, RNG and timed actions.

Headless recipe initialization and callback scheduling are controlled. Native
inventory/recipe guards, RandomCard/Rand, animation/metabolism setters, Kahlua
serialization, typed Planner and source-owner callbacks execute unchanged.
Audio hardware is controlled. This does not establish rendered gameplay.
"""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from native_proof_preflight import installed_presence
import argparse,hashlib,json,os,subprocess,sys,tempfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
GAME=Path(r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid')
JDK=Path(r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin')
DIR=Path(__file__).parent
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureGames.lua'
PLAN=ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
JAR=ROOT/'mod/42.20/media/java/SAO.jar'
CONTROLS=[
 ('partial-progress','or not(self:getJobDelta()>=1)','', 'partial_no_result_CardDeck'),
 ('native-result','a.result=plain(result);a.performed=true','result.face=(result.face or 0)+1;a.result=plain(result);a.performed=true','native_source_result_Dice'),
 ('item-progress','a.item:setJobDelta(self:getJobDelta())','-- omit source native progress','native_partial_CardDeck'),
 ('source-sound','if d.sound and d.soundTime=="ACTION_START"then self.sound=a.body:playSound(d.sound);a.tabletopSound=self.sound end','if false then self.sound=a.body:playSound(d.sound);a.tabletopSound=self.sound end','native_animation_and_sound'),
 ('maintained-purpose','if not admission or admission.ownerName~="SAO.LeisureGames"or admission.actorId~=a.work.actorId\n        or admission.sequence~=a.work.sequence or admission.sourceId~=a.work.sourceId or admission.bodyToken~=a.work.bodyToken then return false end','if false then return false end','retired_purpose_refuses_rng'),
 ('body-generation','and a.body:getModData().SAOExternalToken==w.bodyToken and hours()>=w.admittedAtHours','and hours()>=w.admittedAtHours','stale_generation_refuses_rng'),
 ('captured-audio','a.emitter:stopOrTriggerSound(sound)','do end ','death_exact_audio_cleanup'),
 ('foreign-interrupt','if a.body~=body then return false end','if false then return false end','foreign_interrupt_cannot_retire'),
 ('native-callback','or self.action~=a.nativeAction\n        or a.work.nativeProgress.sourceUpdates<1','\n        or a.work.nativeProgress.sourceUpdates<1','foreign_native_callback_refused'),
 ('source-update','or a.work.nativeProgress.sourceUpdates<1 or not(self:getJobDelta()>=1)','or not(self:getJobDelta()>=1)','source_update_required'),
 ('county-clock','and hours()>=w.admittedAtHours','and true','backwards_clock_refuses_rng'),
 ('offered-source','if same(v,offer)then selected=v;break end','if true then selected=v;break end','forged_source_refused'),
]

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=JAR);args=ap.parse_args();jar=args.jar.resolve()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 originals=[GAME/'media/scripts/generated/recipes/recipes_cardsAndDice.txt',GAME/'media/scripts/generated/timedactions.txt',GAME/'media/scripts/generated/items/normal.txt',GAME/'media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua']
 inputs=[Path(__file__),DIR/'tabletop_fixture.java',DIR/'tabletop_prelude.lua',DIR/'tabletop_cases.lua',OWNER,PLAN,probe,*helpers,jar,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',*native,*originals]
 absent=installed_presence(inputs,GAME,JDK,'D2 tabletop_test');
 if absent is not None:return absent
 receipt={'schema':'sao.d2-native-tabletop/1','status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[]}
 def seal():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,work):
  r=subprocess.run(list(map(str,cmd)),cwd=work,capture_output=True,timeout=120);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':sha(log)});seal();return r.returncode,log.read_text(encoding='utf-8',errors='replace')
 seal()
 try:
  with tempfile.TemporaryDirectory(prefix='sao-tabletop-')as tmp:
   work=Path(tmp);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   java=probe.read_text().replace('public final class InstrumentProbe','public final class D2TabletopProbe')
   java=java.replace('env.rawset("__body",body);','TabletopFixture.install(env,exposer,body,other,Path.of(args[0]));\n        env.rawset("__body",body);')
   java=java.replace('Path.of(args[args.length-2])','Path.of(args[args.length-2])')
   generated=out/'D2TabletopProbe.java';generated.write_text(java,encoding='utf-8')
   cp=os.pathsep.join(map(str,[jar,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']))
   code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,DIR/'tabletop_fixture.java',generated],work);assert code==0,log
   production=OWNER.read_text()
   plan=out/'planner.lua';plan.write_bytes(PLAN.read_bytes())
   reload=out/'reload.lua';reload.write_text('__reloadGames=function()\n'+OWNER.read_text()+'\nend\n',encoding='utf-8')
   receipt['controls']=[]
   for name,before,after,marker in [('production',None,None,None),*CONTROLS]:
    variant=production
    if before:
     assert variant.count(before)==1,(name,variant.count(before));variant=variant.replace(before,after,1)
    owner=out/(name+'-owner.lua');owner.write_text(variant,encoding='utf-8')
    reload=out/(name+'-reload.lua');reload.write_text('__reloadGames=function()\n'+variant+'\nend\n',encoding='utf-8')
    code,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'D2TabletopProbe',GAME,DIR/'tabletop_prelude.lua',*native,originals[3],plan,owner,reload,DIR/'tabletop_cases.lua'],work)
    if marker:assert code!=0 and 'NATIVE_TABLETOP:'+marker in log,(name,log[-5000:]);receipt['controls'].append({'name':name,'marker':marker})
    else:
     assert code==0 and 'PASS native tabletop 'in log,log[-9000:]
     import re
     receipt['checks']=int(re.search(r'PASS native tabletop (\d+)',log).group(1))
    print(name+': '+('expected refusal'if marker else'PASS'),flush=True)
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift'
   receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);seal();print('FAIL',e);return 1
 seal();print('PASS native tabletop',receipt['checks']);return 0
if __name__=='__main__':raise SystemExit(main())
