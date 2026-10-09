"""Installed recovery-place geometry and actual bed animation; controlled native scene, no rendered-game claim."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,sys,shutil
import concept_observation_test as base

ROOT=base.ROOT
OUT=ROOT/'_scratch/d1-shared-reasoning/recovery-place/native'
OUT=Path(os.environ.get('SAO_RECOVERY_PLACE_OUTPUT',OUT))
MANIFEST=json.loads((ROOT/'tools/recovery_source_manifest.json').read_bytes())
EXTERNAL=ROOT/'mod/42.20'

SOURCE=ROOT/'java/src/com/sao/engine/SAORecoveryPlace.java'
PROBE=ROOT/'tools/javacheck/RecoveryPlaceProbe.java'
POSE=ROOT/'mod/42.20/media/lua/client/SAO_RecoveryPose.lua'
CASES=ROOT/'tools/recovery_place_cases.lua'
RUNNER=ROOT/'tools/luacheck/LuaRun.java'

def run(jar_path=None):
    if not all(p.is_file()for p in [base.GAME/'projectzomboid.jar',base.JDK/'java.exe',base.JDK/'javac.exe']):
        print('Recovery place SKIPPED: installed engine/JDK or packaged recovery input absent');return
    jars=[base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',Path(jar_path or ROOT/'mod/42.20/media/java/SAO.jar').resolve()]
    sources=[SOURCE,base.SOURCE,base.BRIDGE,PROBE,base.BOOT,ROOT/'java/src/com/sao/engine/SAORecoveryPose.java',
        ROOT/'java/src/com/sao/engine/SAOOrientationAnimation.java',ROOT/'tools/orienting_checks/RecoveryPoseProbe.java',ROOT/'tools/orienting_checks/OrientationProbe.java']
    files=[*sources,*jars,Path(__file__),POSE,CASES,RUNNER,base.GAME/'stdlib.lua',
        ROOT/'mod/42.20/media/lua/shared/TimedActions/SAORecoveryTransitionAction.lua',
        base.GAME/'media/lua/shared/TimedActions/ISGetOnBedAction.lua',base.GAME/'media/AnimSets/player/onbed/OnBedAsleep.xml',
        base.GAME/'media/AnimSets/player/onbed/OnBedAwake.xml',base.GAME/'media/newtiledefinitions.tiles',base.GAME/'media/seating.txt',
        base.GAME/'media/lua/shared/ISBaseObject.lua',base.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
        base.GAME/'media/AnimSets/player/onbed/GetOnBed_FootRight.xml',base.GAME/'media/anims_X/Bob/Bob_GetInBed_Right.x']
    pin=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    inputs=pin();out=OUT/hashlib.sha256(json.dumps(inputs,sort_keys=True).encode()).hexdigest()[:12];out.mkdir(parents=True,exist_ok=True)
    receipt={'status':'INCOMPLETE','boundary':__doc__,'inputs':inputs,'variants':[],
        'selection':{'native':os.environ.get('SAO_RECOVERY_PLACE_VARIANTS','all'),'lua':os.environ.get('SAO_RECOVERY_PLACE_LUA_VARIANTS','all')}}
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    save();cp=os.pathsep.join(map(str,jars));original=SOURCE.read_text()
    variants=[('production',None,None,None),
        ('omit-native-bed-entry-event',None,None,'native_foot_entry_event'),
        ('chair-facing-as-bed-facing','String facing=object.getProperties().get("Facing");','String facing=zombie.seating.SeatingManager.getInstance().getFacingDirection(object);','actual_bed_dresser_head_blocked_foot_side_offered'),
        ('omit-foot-approaches','for(double[] point:approaches)','for(double[] point:java.util.Arrays.copyOf(approaches,2))','actual_bed_dresser_head_blocked_foot_side_offered'),
        ('drop-query-diagnostics','result.rawset("diagnostics",report);',';','query_admission_diagnostic'),
        ('hidden-bed-diagnostics','if(!visible(body,square,radius))continue;','if(square==null)continue;','diagnostics_do_not_enumerate_unseen_beds'),
        ('ignore-doorway','square.getDoorTo(adjacent)!=null','false','doorway_ground_refused'),
        ('ignore-wall','square.isBlockedTo(adjacent)','false','wall_envelope_refused'),
        ('ignore-occupant','if (other != body && other.isCharacter()) return true;','if (false) return true;','other_body_even_noncollidable_refused'),
        ('ignore-bed-occupant','player.isOnBed()','false','sleeping_bed_occupant_refused'),
        ('false-arrival','Math.hypot(body.getX()-x,body.getY()-y)>.35','false','bed_far_approach_refused'),
        ('drop-unsupported-bed','var head=resolvedHead==null?object:resolvedHead;',
         'var head=resolvedHead==null?object:resolvedHead;if(resolvedHead==null)continue;','unsupported_visible_bed_retained')]
    for name,old,new,marker in variants:
        if os.environ.get('SAO_RECOVERY_PLACE_VARIANTS') and name not in os.environ['SAO_RECOVERY_PLACE_VARIANTS'].split(','):continue
        target=out/name;target.mkdir(exist_ok=True);candidate=target/SOURCE.name
        text=original
        if old:
            assert text.count(old)==(2 if name=='chair-facing-as-bed-facing' else 1),name
            text=text.replace(old,new,2 if name=='chair-facing-as-bed-facing' else 1)
        candidate.write_text(text)
        cmd=[base.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',target,candidate,*sources[1:]]
        compiled=subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
        (target/'compile.log').write_bytes((compiled.stdout+compiled.stderr).encode())
        assert compiled.returncode==0,compiled.stdout+compiled.stderr
        cmd=[base.JDK/'java.exe','-Dsao.test.recoveryExternalRoot='+str(EXTERNAL),'-Duser.home='+str(target),'-Djava.awt.headless=true','-Dsao.test.omitBedEntryEvent='+str(name=='omit-native-bed-entry-event').lower(),'-Djava.library.path='+str(base.GAME),'-cp',str(target)+os.pathsep+cp,'RecoveryPlaceProbe',base.GAME,POSE]
        result=subprocess.run(list(map(str,cmd)),cwd=base.GAME,capture_output=True,text=True,timeout=150);log=result.stdout+result.stderr
        (target/'run.log').write_bytes(log.encode())
        receipt['variants'].append({'name':name,'exit':result.returncode,'marker':marker,'logSha256':hashlib.sha256(log.encode()).hexdigest(),'command':list(map(str,cmd))});save()
        assert (result.returncode!=0 and 'RECOVERY_PLACE:'+marker in log) if marker else (result.returncode==0 and 'PASS recovery place' in log),log
        print(name+': '+(marker or next(line for line in log.splitlines() if line.startswith('PASS recovery place'))),flush=True)
    lua=out/'lua';lua.mkdir(exist_ok=True);shutil.copy2(base.GAME/'stdlib.lua',lua/'stdlib.lua')
    (lua/'prelude.lua').write_text('SAO={} require=function()end\n')
    cmd=[base.JDK/'javac.exe','-cp',jars[0],'-d',lua,RUNNER]
    compiled=subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    assert compiled.returncode==0,compiled.stdout+compiled.stderr
    original=POSE.read_text()
    lua_variants=[('production',None,None,None),
        ('chair-direction-action','action.setBeforeSitDirection=bedBeforeSitDirection','-- no override','bed_direction_ignores_chair_position'),
        ('pending-bed-race','if P.bedUsers[work.bed] and not P.bedUsers[work.bed].retired then','if false then','pending_bed_entry_is_exclusive'),
        ('start-occupancy-race','if work.bed and SAOJavaBridge:recoveryBed(work.body,work.place.key)~=work.bed then','if false then','occupancy_race_blocks_start'),
        ('skip-ground-clearance','if not SAOJavaBridge:recoveryGroundClear(body, destination[1], destination[2], destination[3]) then return false end','if false then return false end','blocked_offset_cannot_move_body'),
        ('early-pose-admission','if not P.observed(body,"rest") then return "preparing" end','if false then return "preparing" end','flag_without_pose_cannot_admit')]
    for name,old,new,marker in lua_variants:
        if os.environ.get('SAO_RECOVERY_PLACE_LUA_VARIANTS') and name not in os.environ['SAO_RECOVERY_PLACE_LUA_VARIANTS'].split(','):continue
        text=original
        if old:
            assert text.count(old)>=1,name
            text=text.replace(old,new,1)
        candidate=lua/(name+'.lua');candidate.write_text(text)
        cmd=[base.JDK/'java.exe','-cp',str(lua)+os.pathsep+str(jars[0]),'LuaRun',lua/'prelude.lua',base.GAME/'media/lua/shared/ISBaseObject.lua',base.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',base.GAME/'media/lua/shared/TimedActions/ISGetOnBedAction.lua',candidate,CASES,'--','__result']
        result=subprocess.run(list(map(str,cmd)),cwd=lua,capture_output=True,text=True,timeout=60);log=result.stdout+result.stderr
        (lua/(name+'.log')).write_bytes(log.encode())
        receipt['variants'].append({'name':'lua-'+name,'exit':result.returncode,'marker':marker,'logSha256':hashlib.sha256(log.encode()).hexdigest(),'command':list(map(str,cmd))});save()
        assert (result.returncode!=0 and 'RECOVERY_PLACE_LUA:'+marker in log) if marker else (result.returncode==0 and 'PASS recovery place Lua' in log),log
        print('lua-'+name+': '+(marker or log.strip()),flush=True)
    receipt['inputsAfter']=pin();assert receipt['inputsAfter']==inputs,'proof inputs changed';receipt['status']='PASS';save();print(out/'receipt.json')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument("--jar",type=Path);args=parser.parse_args()
    try:run(args.jar)
    except Exception as error: print('FAIL recovery place: '+str(error),file=sys.stderr);raise SystemExit(1)
