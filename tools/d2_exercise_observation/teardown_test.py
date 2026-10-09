"""Actual installed FWO/Yoga sources joined to native NPC Fitness/Stats/XP.

Observation acquisition, queue callbacks, animation and audio receivers are
controlled. Physical objects, source definitions/utilities/hidden skills, native
Fitness cache/XP/stiffness, planner/skill custody and serialization are real.
"""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[2]
GAME=Path(os.environ.get('PZ_GAME_DIR',r'C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:/Users/jleyv/Peanut Butter/JetBrains/Java/bin'))
LIFESTYLE=Path(r'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/3403870858/mods/Lifestyle/common/media/lua')
FWO=Path(r'C:/Program Files (x86)/Steam/steamapps/workshop/content/108600/2940354599/mods')
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureExercise.lua'
PLAN=ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
SKILL=ROOT/'mod/42.20/media/lua/client/SAO_LeisureSkill.lua'
HERE=Path(__file__).parent
CONTROLS=[
 ('body-owner-guard','SAO.Needs.ownsRecoveryBody(active.actorId,body)','true','retired_body_token_no_fitness_write'),
 ('retired-skip-cleanup','if runtime[id]==active then cleanupCaptured(active) end','if runtime[id]==active and owned(active) then cleanupCaptured(active) end','retired_interrupt_removes_owned_action'),
 ('death-fitness-write','if current and not body:isDead() and not active.record.dead and action and action.character==body then','if current and action and action.character==body then','death_preserves_fitness_state'),
 ('foreign-detach','if active.body~=body then return false end','if false then return false end','foreign_detach_refused'),
 ('queue-reset','removeOwnedAction(self)','ISTimedActionQueue.getTimedActionQueue(self.character):resetQueue()','maintained_stop_preserves_follower'),
 ('sound-leak','pcall(function()active.soundEmitter:stopSound(active.gameSound)end)','pcall(function()end)','retired_sound_stopped'),
 ('retired-advance-leak','cleanupCaptured(active)\n        return finish(active,"interrupted","body-custody-lost")','return finish(active,"interrupted","body-custody-lost")','retired_advance_removes_owned_action'),
]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--jar',type=Path,default=ROOT/'mod/42.20/media/java/SAO.jar');ap.add_argument('--baseline-only',action='store_true');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 java_sources=[ROOT/'java/src/com/sao/engine/SAOFitnessDefinitions.java',ROOT/'java/src/com/sao/engine/SAOConceptObservation.java']
 jars=[args.jar.resolve(),GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar']
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',GAME/'media/lua/shared/Definitions/FitnessExercises.lua']
 definitions=FWO/'FWO Treadmill & BenchPress/42/media/lua/shared/Definitions/FWOFitnessExercisesBenchpress&Treadmill.lua'
 sources=[LIFESTYLE/'shared/LSUtil.lua',LIFESTYLE/'shared/LSSync.lua',LIFESTYLE/'client/Helper/HSMng.lua']
 originals=[LIFESTYLE/'shared/TimedActions/LSYogaAction.lua',LIFESTYLE/'client/ISMeditation/ZenWellnessContextMenu.lua',
  FWO/'FWO Treadmill & BenchPress/42/media/lua/shared/TimedActions/FWOTreadmillBenchpressExercise.lua',
  FWO/'FWO Fitness Workout Overhaul/42/media/lua/shared/TimedActions/FWOFitnessAction.lua',
  FWO/'FWO Treadmill & BenchPress/42/media/lua/client/TimedActions/FWOTreadmillBenchpressClient.lua']
 cases=HERE/'teardown_cases.lua';preludes=[HERE/'prelude.lua',HERE/'source_prelude.lua']
 inputs=[Path(__file__),OWNER,PLAN,SKILL,probe,*helpers,*java_sources,*jars,*native,definitions,*sources,*originals,cases,*preludes,HERE/'teardown_queue.lua',GAME/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
 absent=installed_presence(inputs,GAME,JDK,'D2 teardown_test');
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','boundary':__doc__,'inputsBefore':{str(p):sha(p)for p in inputs},'runs':[]}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,wd):
  p=subprocess.run(list(map(str,cmd)),cwd=wd,capture_output=True,timeout=100);log=out/(name+'.log');log.write_bytes(p.stdout+p.stderr)
  receipt['runs'].append({'name':name,'exitCode':p.returncode,'log':str(log),'sha256':sha(log)});save()
  return p.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-source-fitness-') as d:
   work=Path(d);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   java=probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class D2SourceExerciseProbe')
   java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','zombie.iso.sprite.IsoSprite.class,zombie.core.properties.PropertyContainer.class,zombie.iso.IsoDirections.class,zombie.characters.BodyDamage.Metabolics.class,zombie.characters.BodyDamage.Fitness.class,zombie.ai.states.FitnessState.class,zombie.ai.states.IdleState.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,\n            IsoCell.class,zombie.iso.IsoGridSquare.class')
   java=java.replace('{"weapon.txt","GuitarAcoustic","__guitar"}','{"weapon.txt","GuitarAcoustic","__guitar"},{"weapon.txt","BarBell","__barbell"},{"weapon.txt","DumbBell","__dumbbell"}')
   injection='''var aliases=new HashMap<String,ArrayList<String>>();
        env.rawset("__replacementBarbell",zombie.inventory.InventoryItemFactory.CreateItem("Base.BarBell"));
        aliases.put("CustomName",new ArrayList<>(java.util.List.of("Hamster Wheel","Contraption")));
        aliases.put("GroupName",new ArrayList<>(java.util.List.of("Human","Fitness")));
        aliases.put("Facing",new ArrayList<>(java.util.List.of("N","S","E","W")));
        zombie.core.TilePropertyAliasMap.instance.Generate(aliases);
        var sq=body.getCell().getGridSquare(10,19,0);
        if(sq==null){sq=zombie.iso.IsoGridSquare.getNew(cell,null,10,19,0);cell.setCacheGridSquare(10,19,0,sq);}
        sq.setS(body.getCurrentSquare());body.getCurrentSquare().setN(sq);
        var machine=new IsoObject(cell);machine.setSquare(sq);var sprite=new zombie.iso.sprite.IsoSprite();sprite.setName("fixture-bench");
        sprite.getProperties().set("CustomName","Contraption");sprite.getProperties().set("GroupName","Fitness");sprite.getProperties().set("Facing","S");
        machine.setSprite(sprite);sq.getObjects().add(machine);env.rawset("__machine",machine);
        env.rawset("__offSlot",(JavaFunction)(frame,count)->{for(var slot:zombie.characters.IsoPlayer.players)if(slot==body)return frame.push(false);return frame.push(true);});env.rawset("__enduranceMoodle",zombie.scripting.objects.MoodleType.ENDURANCE);env.rawset("__unhappyMoodle",zombie.scripting.objects.MoodleType.UNHAPPY);env.rawset("__drunkMoodle",zombie.scripting.objects.MoodleType.DRUNK);
        env.rawset("__painMoodle",zombie.scripting.objects.MoodleType.PAIN);env.rawset("__heavyMoodle",zombie.scripting.objects.MoodleType.HEAVY_LOAD);
        env.rawset("__smokerTrait",zombie.scripting.objects.CharacterTrait.SMOKER);
        env.rawset("__fwoNoiseExact",(JavaFunction)(frame,count)->{var rows=zombie.WorldSoundManager.instance.soundList;var last=rows.isEmpty()?null:rows.get(rows.size()-1);return frame.push(last!=null&&last.source==body&&last.radius==13&&last.volume==6&&last.x==10&&last.y==20);});
        var global=new zombie.Lua.LuaManager.GlobalObject();
        env.rawset("addXp",(JavaFunction)(frame,count)->{var target=(zombie.characters.IsoPlayer)frame.get(0);var perk=(zombie.characters.skills.PerkFactory.Perk)frame.get(1);float before=target.getXp().getXP(perk);global.addXp(target,perk,((Number)frame.get(2)).floatValue());env.rawset("__lastSourceXPAmount",frame.get(2));env.rawset("__lastSourceXPDelta",(double)(target.getXp().getXP(perk)-before));return 0;});
        env.rawset("SyncXp",(JavaFunction)(frame,count)->{global.SyncXp((zombie.characters.IsoPlayer)frame.get(0));return 0;});
        env.rawset("__initDefinitions",(JavaFunction)(frame,count)->frame.push(com.sao.engine.SAOFitnessDefinitions.initialize((SAOIsoPlayerShell)frame.get(0),frame.get(1))));
        env.rawset("__xpModifier",(JavaFunction)(frame,count)->frame.push(com.sao.engine.SAOFitnessDefinitions.xpModifier((SAOIsoPlayerShell)frame.get(0),(String)frame.get(1))));
        env.rawset("__resetFitness",(JavaFunction)(frame,count)->{try{var f=zombie.characters.BodyDamage.Fitness.class.getDeclaredField("exercises");f.setAccessible(true);((java.util.Map<?,?>)f.get(body.getFitness())).clear();body.getFitness().setCurrentExercise(null);body.getXp().xpMap.clear();}catch(Exception e){throw new IllegalStateException(e);}return 0;});
        '''
   java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
   generated=out/'D2SourceExerciseProbe.java';generated.write_text(java,encoding='utf-8')
   cp=os.pathsep.join(map(str,jars));code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,*java_sources,generated],work);assert code==0,log
   production=OWNER.read_text(encoding='utf-8')
   original=originals[0].read_text(encoding='utf-8-sig');original=original[original.index('LSYogaAction ='):].replace('LSYogaAction =','local SAONpcYogaCore =',1).replace('LSYogaAction:', 'SAONpcYogaCore:')
   blocks=[original[:original.index('local function getYogaMat(character)')],original[original.index('function SAONpcYogaCore:waitToStart()'):original.index('function SAONpcYogaCore:fitnessBonus()')],original[original.index('function SAONpcYogaCore:perform()'):]]
   assert all(block in production for block in blocks),'Yoga source profile drift'
   original=originals[3].read_text(encoding='utf-8-sig')
   block=original[original.index('local function calcMulExe'):original.index('--- Timestamp-based cooldown check')]
   assert block in production,'FWO regularity source profile drift'
   original=originals[2].read_text(encoding='utf-8-sig');block=original[original.index('function ISFitnessAction:exeLooped()'):].replace('function ISFitnessAction:exeLooped()','local function fwoEquipmentRepeat(self)',1).replace('    vanilla_exeLooped(self)','    fwoMood(self.character)\n    SAONpcExerciseCore.exeLooped(self)')
   assert block in production,'FWO equipment source profile drift'
   receipt['sourceProfiles']=5
   receipt['checks']=cases.read_text(encoding='utf-8').count("check('");receipt['controls']=[]
   for name,before,after,marker in [('baseline',None,None,None)]+([]if args.baseline_only else CONTROLS):
    code=production
    if before:assert before in code,name;code=code.replace(before,after,1)
    variant=out/(name+'-owner.lua');variant.write_text(code,encoding='utf-8')
    reload=out/(name+'-reload.lua');reload.write_text('__reloadExercise=function()\n'+code+'\nend\nEvents.OnTick={Add=function()end}\n',encoding='utf-8')
    paths=[preludes[0],*native,preludes[1],definitions,*sources,PLAN,SKILL,variant,
      GAME/'media/lua/shared/TimedActions/ISFitnessAction.lua',originals[3],originals[2],originals[0],reload,GAME/'media/lua/client/TimedActions/ISTimedActionQueue.lua',HERE/'teardown_queue.lua',cases]
    status,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'D2SourceExerciseProbe',GAME,*paths],work)
    if marker:assert status!=0 and 'SOURCE_EXERCISE:'+marker in log,(name,log[-6000:]);receipt['controls'].append({'name':name,'reason':marker})
    else:assert status==0 and 'PASS source exercise '+str(receipt['checks']) in log,log[-7000:]
   receipt['inputsAfter']={str(p):sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift';receipt['status']='PASS'
 except Exception as e:receipt['failure']=str(e);save();print('FAIL',e);return 1
 save();print('PASS source exercise',receipt['checks'],len(receipt['controls']));return 0
if __name__=='__main__':raise SystemExit(main())
