#!/usr/bin/env python3
"""Installed NPC/Fitness/Kahlua physical repetition and owned leisure custody.

Animation/queue callbacks, private concept availability and Standing are controlled;
Fitness.exerciseRepeat, Stats, native bodies, shipped action/base/definitions and
serialization are actual installed owners. No loaded/rendered game claim.
"""
import argparse,hashlib,json,os,subprocess,tempfile
from pathlib import Path
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureExercise.lua'
PLAN=ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
CASES=ROOT/'tools/d2_exercise_observation/cases.lua'
PRELUDE=CASES.with_name('prelude.lua')
KA=Path(r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3797356103\mods\KnoxAquarium\42\media\lua\shared')
CONTROLS=[
 ('omit-native-repeat','self.fitness:exerciseRepeat();','-- omitted native physical repetition','actual_native_repeat_effect'),
 ('duration-only-success','active.progress.repetitions>0 and active.progress.elapsedMinutes>=w.minutes','active.progress.elapsedMinutes>=w.minutes','duration_without_repeat_not_success'),
 ('late-stop-success','active.durationReached==true and active.progress.repetitions>0','active.progress.repetitions>0','late_external_stop_not_completion'),
 ('clock-mutation','-- The operator owns the global game clock.','setGameSpeed(1);','no_operator_clock_mutation'),
 ('ignore-standing','or not permission(id,body) then return {}','or false then return {}','standing_required'),
 ('ignore-concept','conceptual and conceptual.status=="expectation"','true','concept_required'),
 ('stale-generation','and live(w.actorId,active.body) and bodyMatches(w,active.body)','and live(w.actorId,active.body)','stale_body_no_effect'),
 ('aquarium-duplicate','seen[row.key]=true;seen[obj]=true','-- omit source identity retention','aquarium_duplicate_tank_not_counted'),
 ('aquarium-stale','and row.at<=tick and tick-row.at<=120','and row.at<=tick','aquarium_stale_observation_refused'),
 ('aquarium-hidden','and row.source=="native-personal-visibility" and finite(row.at)','and finite(row.at)','aquarium_hidden_not_acquired'),
 ('aquarium-water-change','and (tonumber(data.water) or 0)>0 then','then','aquarium_water_change_refused'),
 ('aquarium-fish-change','#(data.fish or {})>=K.comfort.minFish','true','aquarium_fish_change_refused'),
 ('aquarium-silent-no-effect','stats:remove(CharacterStat.STRESS,amounts.STRESS)','-- omit one actual receiver','aquarium_actual_source_effect'),
 ('bypass-typed-admission','if not P or not P.admitHobbyWork or not P.admitHobbyWork(id,purposeId,sequence,"SAO.LeisureExercise") then','if false then','typed_admission_precedes_native_queue'),
 ('omit-terminal-consumption','admission and admission.ownerName=="SAO.LeisureExercise" and P.consumeHobbyOutcome\n        and P.consumeHobbyOutcome(w.actorId,w.sequence,"SAO.LeisureExercise")==true','false','actual_planner_consumes_native_completion'),
 ('bypass-current-typed-custody','return admitted and r and validWork(w,w.actorId)','return r and validWork(w,w.actorId)','retired_purpose_cannot_repeat_native_exercise'),
]
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--baseline-only',action='store_true');args=p.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
 probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
 helpers=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/cognition_checks/CognitionUseProbe.java']
 jars=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
 native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',GAME/'media/lua/shared/Definitions/FitnessExercises.lua']
 aquarium_sources=[KA/'KA_Core.lua',KA/'KA_Comfort.lua']
 inputs=[Path(__file__),OWNER,PLAN,PRELUDE,CASES,probe,*helpers,*jars,*native,*aquarium_sources,GAME/'stdlib.lua',GAME/'media/lua/shared/TimedActions/ISFitnessAction.lua']
 absent=installed_presence(inputs,GAME,JDK,'D2 d2_exercise_observation_test',installed_roots=(KA,));
 if absent is not None:return absent
 receipt={'status':'INCOMPLETE','inputsBefore':{str(f):sha(f) for f in inputs},'runs':[],
 'boundary':__doc__}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(name,cmd,cwd):
  result=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=100)
  log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr)
  receipt['runs'].append({'name':name,'exitCode':result.returncode,'log':str(log),'sha256':sha(log)});save()
  return result.returncode,log.read_text(encoding='utf-8',errors='replace')
 try:
  with tempfile.TemporaryDirectory(prefix='sao-exercise-') as temporary:
   work=Path(temporary);(work/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
   java=probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class D2ExerciseProbe')
   java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class','zombie.iso.sprite.IsoSprite.class,zombie.characters.BodyDamage.Metabolics.class,zombie.characters.BodyDamage.Fitness.class,zombie.ai.states.FitnessState.class,zombie.ai.states.IdleState.class,\n            IsoCell.class,zombie.iso.IsoGridSquare.class')
   java=java.replace('env.rawset("__body",body);','var aquarium=new IsoObject(cell);aquarium.setSquare(body.getCurrentSquare());\n        var aquariumSprite=new zombie.iso.sprite.IsoSprite();aquariumSprite.setName("fixture-aquarium");aquarium.setSprite(aquariumSprite);\n        body.getCurrentSquare().getObjects().add(aquarium);env.rawset("__tank",aquarium);\n        env.rawset("__body",body);')
   java=java.replace('env.rawset("__body",body);','env.rawset("__enduranceMoodle",zombie.scripting.objects.MoodleType.ENDURANCE);\n        env.rawset("__body",body);')
   generated=out/'D2ExerciseProbe.java';generated.write_text(java,encoding='utf-8')
   cp=os.pathsep.join(map(str,jars));code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
   source=OWNER.read_text(encoding='utf-8-sig');expected=CASES.read_text(encoding='utf-8').count("check('")
   planner=out/'actual-planner.lua';planner.write_bytes(PLAN.read_bytes())
   receipt['checks']=expected;receipt['controls']=[]
   variants=[('baseline',None,None,None)]+([] if args.baseline_only else CONTROLS)
   for name,before,after,marker in variants:
    text=source
    if before:
     assert before in text,(name,'missing mutation')
     text=text.replace(before,after,1)
    variant=out/(name+'-owner.lua');variant.write_text(text,encoding='utf-8')
    code,log=run(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
     '-cp',str(work)+os.pathsep+cp,'D2ExerciseProbe',GAME,PRELUDE,*native,*aquarium_sources,planner,variant,CASES],work)
    if marker:
     assert code!=0 and 'EXERCISE:'+marker in log,(name,log[-4000:]);receipt['controls'].append({'name':name,'reason':marker})
    else:assert code==0 and 'PASS exercise observation '+str(expected) in log,log[-6000:]
   receipt['inputsAfter']={str(f):sha(f) for f in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'input drift'
   receipt['status']='PASS'
 except Exception as error:receipt['failure']=str(error);save();print('FAIL',error);return 1
 save();print('PASS exercise observation',receipt['checks'],'checks',len(receipt['controls']),'controls');return 0
if __name__=='__main__':raise SystemExit(main())
