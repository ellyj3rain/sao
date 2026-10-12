#!/usr/bin/env python3
"""Original furniture native effects/action/private recovery qualification.
Native world and receiver fixtures are isolated; no loaded game/render/MP claim.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,time,shutil
S=Path(__file__).resolve().parent.parent
G=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
J=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--required',action='store_true');ap.add_argument('--controls',action='store_true');ap.add_argument('--phase',choices=['native','private','human','lifecycle','admitted'],default='native');a=ap.parse_args()
 out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True);target=out/'receipt.json'
 if target.exists():raise RuntimeError('Preserve prior receipt; choose a fresh output')
 runtime=[S/('mod/42.20/media/lua/'+p) for p in ['shared/SAO_FurnitureRelocation.lua','shared/SAO_FurnitureRelocationAction.lua',
  'client/SAO_FurnitureWork.lua','client/SAO_FurnitureMenu.lua','client/SAO_FurnitureMovement.lua','shared/SAO_Perception.lua',
  'shared/SAO_Standing.lua','shared/SAO_ProceduralPlanning.lua','client/SAO_Controller.lua','shared/SAO_Cognition.lua','shared/SAO_Identity.lua','client/SAO_Needs.lua',
  'shared/SAO_CognitiveModels.lua','client/SAO_Locomotion.lua','client/SAO_RecoveryPose.lua']]
 sources=[S/'tools/furniture_checks/FurnitureNativeProbe.java',S/'tools/luacheck/MovementCrossingProbe.java',
  S/'java/src/com/sao/engine/SAOFurnitureObservation.java',S/'java/src/com/sao/bridge/SAOBridge.java',
  S/'tools/orienting_checks/OrientationProbe.java',S/'tools/orienting_checks/RecoveryPoseProbe.java']
 inputs=runtime+sources+[Path(__file__),S/'tools/furniture_checks/native_prelude.lua',S/'tools/furniture_checks/native_cases.lua',
  S/'mod/42.20/media/java/SAO.jar',G/'projectzomboid.jar',G/'ZombieBuddy.jar',G/'media/lua/shared/Moveables/ISMoveableSpriteProps.lua',
  G/'media/lua/shared/Moveables/ISMoveableDefinitions.lua',G/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',G/'media/lua/shared/ISBaseObject.lua',
  G/'media/scripts/generated/items/moveable.txt',G/'media/scripts/generated/items/normal.txt',G/'media/lua/client/TimedActions/ISTimedActionQueue.lua',G/'media/lua/client/TimedActions/WalkToTimedAction.lua',G/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
  S/'tools/furniture_checks/private_prelude.lua',S/'tools/furniture_checks/private_cases.lua',S/'tools/furniture_checks/human_cases.lua',S/'tools/furniture_checks/private_lifecycle_cases.lua',J/'java.exe',J/'javac.exe']
 inputs += [G/'media/lua/shared/TimedActions/ISGetOnBedAction.lua',G/'media/lua/shared/defines.lua',G/'media/AnimSets/player/onbed/GetOnBed_FootRight.xml',
  S/'tools/resource_production_checks/ShelterConstructionNativeProbe.java',S/'tools/luacheck/LuaSyntax.java',G/'stdlib.lua',G/'jassimp64.dll',Path(__import__('sys').executable)]
 inputs += [G/('media/anims_X/Bob/'+name+'.x') for name in ['Bob_LookLeft','Bob_LookRight','Bob_LookDown','Bob_LookUp','Bob_Idle','Bob_Walk',
  'Bob_Awake','Bob_Asleep','Bob_AwakeToAsleep','Bob_AsleepToAwake','Bob_SitGround_ActionIdle','Bob_SitGround_toActionIdle']]
 inputs += [G/('media/AnimSets/player/onbed/'+name+'.xml') for name in ['OnBedAwake','OnBedAsleep']]
 owned=runtime+sources+[Path(__file__),S/'tools/furniture_checks/native_prelude.lua',S/'tools/furniture_checks/native_cases.lua',
  S/'tools/furniture_checks/private_prelude.lua',S/'tools/furniture_checks/private_cases.lua',S/'tools/furniture_checks/private_lifecycle_cases.lua',S/'tools/furniture_checks/human_cases.lua',
  S/'mod/42.20/media/java/SAO.jar',S/'tools/luacheck/LuaSyntax.java',S/'tools/resource_production_checks/ShelterConstructionNativeProbe.java']
 missing=[str(p) for p in owned if not p.is_file()]
 if missing:print('FAIL missing owned furniture inputs: '+', '.join(missing));return 1
 missing=[str(p) for p in inputs if not p.is_file()]
 if missing:
  target.write_text(json.dumps({'status':'NATIVE_UNAVAILABLE','missing':missing,'required':a.required,'sourcePins':{str(p):sha(p) for p in owned}},indent=2)+'\n')
  print(('FAIL' if a.required else 'NATIVE_UNAVAILABLE')+' installed furniture inputs absent: '+', '.join(missing));return 1 if a.required else 0
 receipt={'status':'RUNNING','sourcePins':{str(p):sha(p) for p in inputs},'runs':[],
  'controls':[],'environment':{'phase':a.phase,'nativeGame':str(G),'jdk':str(J),'python':__import__('sys').executable,'platform':__import__('platform').platform()},
  'boundary':'Native cell/sprites/grid/items/containers and full installed moveable Lua; native actor/action dispatcher. Scene, time/end flags, network and queue controlled. No live game, save, render or MP.'}
 def save():target.write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  before=time.monotonic();done=subprocess.run([str(x) for x in cmd],cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
  log=out/(name+'.log');log.write_text(done.stdout+done.stderr,encoding='utf-8')
  r={'name':name,'command':[str(x) for x in cmd],'cwd':str(cwd),'exitCode':done.returncode,'elapsedSeconds':round(time.monotonic()-before,3),
   'log':str(log),'logSha256':sha(log),'checks':[line[6:] for line in done.stdout.splitlines() if line.startswith('CHECK ')]}
  receipt['runs'].append(r);save();return r
 save()
 try:
  classes=out/'classes';classes.mkdir();cp=';'.join(str(p) for p in [S/'mod/42.20/media/java/SAO.jar',G/'projectzomboid.jar',G/'ZombieBuddy.jar'])
  frozen=out/'frozen';frozenSources=[]
  for p in inputs:
   if p.is_relative_to(S):
    q=frozen/p.relative_to(S);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
  frozenSources=[frozen/p.relative_to(S) for p in sources]+[frozen/'tools/luacheck/LuaSyntax.java']
  compile=run('compile',[J/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',classes,*frozenSources],S)
  if compile['exitCode']!=0:raise RuntimeError('scratch compiler refused inputs')
  syntax=run('syntax',[J/'java.exe','-cp',str(classes)+';'+cp,'LuaSyntax',*[frozen/p.relative_to(S) for p in runtime]],S)
  if syntax['exitCode']!=0:raise RuntimeError('native normal/debug source compiler refused inputs')
  native=run('native',[J/'java.exe','--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-Djava.library.path='+str(G),
   '-Duser.home='+str(out/'home'),'-Dsao.furnitureCache='+str(out/'cache'),'-cp',str(classes)+';'+cp,
   'FurnitureNativeProbe',G,frozen,frozen/runtime[0].relative_to(S),a.phase],G)
  if native['exitCode']!=0 or not native['checks'] or any(c.endswith('=false') for c in native['checks']):raise RuntimeError('native furniture qualification failed')
  if a.controls:
   specs={
    'admitted':[('admitted-reconciliation','shared/SAO_ProceduralPlanning.lua','p.lastAdmission=dataCopy(a);p.admission=nil;step.status="available";p.status="maintained"\n f.recoverySequenceBefore=nil;f.uncertainBenefit=true','p.lastAdmission=dataCopy(a);step.status="available";p.status="maintained"\n f.recoverySequenceBefore=nil;f.uncertainBenefit=true','private_admitted_reconciliation_releases_exact_work')],
    'native':[
     ('member-salvage','shared/SAO_FurnitureRelocation.lua','b.character:getInventory():AddItem(m.carried)','do end','grid_partial_pickup_member_conserved_1'),
     ('native-end','shared/SAO_FurnitureRelocationAction.lua','or not ended(self)','or false','native_unfinished_perform_refused')],
    'private':[('fresh-bed-source','client/SAO_FurnitureWork.lua','if allowed and sameBed(expected.members,members) then','if allowed and expected.key==place.key and sameBed(expected.members,members) then','private_reconstructed_source_bound'),
     ('private-owner','shared/SAO_FurnitureRelocationAction.lua','(not s.validate or s.validate(s)==true)','true','private_actor_rejects_effort'),
     ('actual-retreat','client/SAO_FurnitureWork.lua','if not reached(body,at) then','if false then','private_actual_loco_retreat_requested'),
     ('stale-reload-callback','client/SAO_FurnitureWork.lua','r.furnitureWork~=work or ','','private_interrupted_save_once')],
    'human':[('retired-walk','client/SAO_FurnitureMenu.lua','if not current(self) then return false end','if false then return false end','human_push_retired_walk_preserves_effort')],
    'lifecycle':[('passage-check','client/SAO_FurnitureWork.lua','return option and option.contact and option.retreat\n  and SAO.Standing.mayAttemptBelieved(id,option.contact.x,option.contact.y,option.admission)\n  and SAO.Standing.mayAttemptBelieved(id,option.retreat.x,option.retreat.y,option.admission)','return option and option.contact and option.retreat','private_push_contact_passage_refused'),
     ('use-sequence-tombstone','client/SAO_FurnitureWork.lua',' or sequence<=(s.useSequenceFloor[origin] or 0)','','private_evicted_use_replay_invariant'),
     ('contrary-physical-learning','shared/SAO_CognitiveModels.lua','retain("relocate","body",e.succeeded)','retain("relocate","body",true)','private_contrary_individual_prediction_differs'),
     ('pact-alteration','shared/SAO_Standing.lua','if group and group==other then return true end','if group and S.pactBetween(group,other) then return true end; if group and group==other then return true end','private_standing_pact_not_alteration')]
   }
   for name,path,old,new,verdict in specs.get(a.phase,[]):
    changed=frozen/'mod/42.20/media/lua'/path;original=changed.read_text(encoding='utf-8');count=original.count(old)
    if count!=1:raise RuntimeError('control landing count differs: '+name+' '+str(count))
    changed.write_text(original.replace(old,new),encoding='utf-8')
    mutationHash=sha(changed)
    cmd=list(native['command']);cmd[cmd.index('-Duser.home='+str(out/'home'))]='-Duser.home='+str(out/(name+'-home'))
    cmd[cmd.index('-Dsao.furnitureCache='+str(out/'cache'))]='-Dsao.furnitureCache='+str(out/(name+'-cache'))
    result=run('control-'+name,cmd,G)
    changed.write_text(original,encoding='utf-8')
    detected=result['exitCode']!=0 and verdict+'=false' in result['checks']
    receipt['controls'].append({'name':name,'source':str(S/'mod/42.20/media/lua'/path),'landingCount':count,'beforeSha256':hashlib.sha256(original.encode()).hexdigest(),
     'mutatedSha256':mutationHash,'old':old,'new':new,'namedVerdict':verdict,'detected':detected,'run':result['name']});save()
    if not detected:raise RuntimeError('control did not detect declared violation: '+name)
  receipt['status']='PASS';receipt['inputStable']=all(sha(p)==h for p,h in receipt['sourcePins'].items());save()
  if not receipt['inputStable']:raise RuntimeError('inputs changed during qualification')
  print('PASS native furniture '+str(len(native['checks'])));return 0
 except Exception as e:
  receipt['status']='FAIL';receipt['error']=str(e);save();print('FAIL '+str(e));return 1
if __name__=='__main__':raise SystemExit(main())
