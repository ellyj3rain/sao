#!/usr/bin/env python3
"""Border 228: physical route progress and stable private tactical commitments."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LOCO = Path('mod/42.20/media/lua/client/SAO_Locomotion.lua')
COORD = Path('mod/42.20/media/lua/shared/SAO_Coordination.lua')
ORG = Path('mod/42.20/media/lua/shared/SAO_Organization.lua')
STATE = Path('java/src/com/sao/engine/SAORouteState.java')
BRIDGE = Path('java/src/com/sao/bridge/SAOBridge.java')

PRELUDE = r'''
SAO={Log={line=function() end}}
local body={x=0,y=0,z=0}
function body:getX() return self.x end
function body:getY() return self.y end
function body:getZ() return self.z end
__body=body;__verdict='ManualRoute';__point='MOVE_PROGRESS@0@100@0@0';__cancel=0
SAOJavaBridge={moveTo=function() return 'MOVE_STARTED' end,
 tickMove=function() return __verdict end,
 moveProgress=function() return __point end,
 cancelMove=function() __cancel=__cancel+1 end}
'''

PROBE = r'''(function()
local checks=0
local function check(name,value)
 if not value then error('ROUTE_PROGRESS:'..name) end
 checks=checks+1
end
local L=SAO.Locomotion
local function fresh()
 L.jobs={};__body.x=0;__body.y=0;__body.z=0;__verdict='ManualRoute';__cancel=0
 __point='MOVE_PROGRESS@0@100@0@0'
 check('route_admitted',L.order('a',__body,100,0,0,false)==true)
end
fresh()
for i=1,700 do __body.x=i*.02;L.tick('a') end
check('repeated_verdict_with_physical_progress_survives',not L.jobs.a.done and __cancel==0)
fresh()
for i=1,301 do L.tick('a') end
check('stationary_route_stalls',L.jobs.a.result=='stalled:ManualRoute' and __cancel==1)
fresh()
for i=1,301 do __verdict=i%2==0 and 'Working' or 'ManualRoute';L.tick('a') end
check('changing_verdict_without_progress_stalls',L.jobs.a.done and __cancel==1)
fresh()
for i=1,700 do __body.x=.001*(i%2);L.tick('a') end
check('subthreshold_jitter_stalls',L.jobs.a.done and __cancel==1)
fresh()
for i=1,700 do
 __body.x=10*math.cos(i/10);__body.y=10*math.sin(i/10);L.tick('a')
end
check('motion_without_new_route_progress_stalls',L.jobs.a.done and __cancel==1)
fresh()
for i=1,700 do
 __body.x=-i*.02;__point='MOVE_PROGRESS@0@-100@0@0';L.tick('a')
end
check('native_detour_away_from_final_goal_survives',not L.jobs.a.done)
fresh()
for i=1,290 do L.tick('a') end
__point='MOVE_PROGRESS@1@100@100@0';L.tick('a')
for i=1,100 do L.tick('a') end
check('advanced_native_waypoint_resets_stall',not L.jobs.a.done)
for i=1,200 do L.tick('a') end
check('new_waypoint_can_still_stall',L.jobs.a.done and __cancel==1)
fresh();__point='MOVE_PROGRESS_UNAVAILABLE'
for i=1,700 do __body.x=i*.02;L.tick('a') end
check('unavailable_waypoint_uses_selected_goal',not L.jobs.a.done)
fresh();__point='MOVE_PROGRESS@nan@nan@0@0'
for i=1,301 do L.tick('a') end
check('malformed_waypoint_grants_no_progress',L.jobs.a.done)
for _,missing in ipairs({'MOVE_PROGRESS_UNAVAILABLE','MOVE_PROGRESS@nan@nan@0@0','throw'}) do
 fresh()
 local originalRead=SAOJavaBridge.moveProgress
 SAOJavaBridge.moveProgress=function()
  if __point=='throw' then error('unavailable native progress') end
  return __point
 end
 for i=1,700 do
  __point=i%2==1 and 'MOVE_PROGRESS@0@50@0@0' or missing;L.tick('a')
 end
 check('intermittent_waypoint_reads_do_not_grant_progress_'..missing,L.jobs.a.done and __cancel==1)
 SAOJavaBridge.moveProgress=originalRead
end
fresh();__verdict='Succeeded';L.tick('a')
check('native_arrival_owns_success',L.jobs.a.result=='arrived' and __cancel==0)
fresh();__verdict='FailedObstacle:FAILED_LOCKED_DOOR';L.tick('a')
check('native_failure_remains_terminal',L.jobs.a.result==__verdict and __cancel==0)
fresh();L.tick('a');local original=L.jobs.a
L.order('a',__body,101,0,0,false)
check('same_goal_reissue_retains_progress_owner',L.jobs.a==original)
return 'PASS route progress '..checks
end)()'''

TACTICAL_PROBE = r'''(function()
local checks=0
local function check(name,value)
 if not value then error('ROUTE_PROGRESS:'..name) end
 checks=checks+1
end
__contacts.leader={{id='peer',beliefKey='peer',source='observed',hostile=false}}
__records.leader={id='leader',dead=false};__records.peer={id='peer',dead=false}
local C,O=SAO.Coordination,SAO.Organization
local situation={threat={x=40,y=30,z=0,dist=10,source='observed'},
 threatCount=1,position={x=30,y=30,z=0}}
local function originate() return C.originatePrivateSituation('leader',nil,'idle','border228',situation) end
local p=originate();check('real_tactical_process_created',p and p.revision==1)
O.recordReception(p.id,'peer',1,'spoken','leader',{})
O.appraiseMatter(p.id,'peer',{choice='accept',owner='border228',executor='border228',
 currentActivity='idle',capabilities={move=true},preferredRoles={withdraw=true},
 relationship=.6,ownNeed=.1,destinationKnown=true,
 constraints={executionOwnerAvailable=true,ownNeedAvailable=true},inputOwners={}})
O.deliverResponse(p.id,'peer','leader','spoken',{})
local work=O.activeCommitment('peer','strategic-cooperation')
check('real_returned_assent_creates_commitment',work~=nil)
O.noteWorkAdmission(work.id,'Locomotion','native-route-228',{stepId='move-fallback'})
local before=O.viewFor('leader',p.id,false).proposal.proposal
for i=1,30 do
 situation.position.x=30+i*.08;situation.position.y=30+i*.04
 local next,why=originate()
 check('actor_motion_keeps_revision',next.id==p.id and next.revision==1 and why=='continuing')
end
local after=O.viewFor('leader',p.id,false).proposal.proposal
check('intended_ground_is_stable',before.destination.minX==after.destination.minX
 and before.destination.minY==after.destination.minY)
check('accepted_route_not_superseded',O.activeCommitment('peer','strategic-cooperation').id==work.id
 and work.status~='superseded' and work.work.pendingReceiptId=='native-route-228')
check('no_assent_manufactured',O.viewFor('peer',p.id,false).reception~=nil)
situation.threat.x=44;originate()
check('changed_private_threat_context_revises',p.revision==2 and work.status=='superseded')
local revision=p.revision;situation.position.z=1;situation.threat.z=1;originate()
check('changed_floor_revises',p.revision==revision+1)
revision=p.revision;situation.threatCount=3;originate()
check('changed_crowd_band_revises',p.revision==revision+1)
local oldRevision=p.revision
local ground=O.viewFor('leader',p.id,false).proposal.proposal.procedure[2].target
local known={key='same-cover',x=ground.x,y=ground.y,z=ground.z}
SAO.ProceduralPlanning={chooseFallback=function() return known end}
revision=p.revision;originate()
check('same_coordinate_private_cover_revises',p.revision==revision+1)
check('prior_geometric_proposal_remains_immutable',
 O.viewFor('leader',p.id,false,oldRevision).proposal.proposal.scope.spatialFact==nil)
revision=p.revision;known=nil;originate()
check('same_coordinate_private_cover_invalidation_revises',p.revision==revision+1)
known={key='new-cover',x=10,y=20,z=1}
revision=p.revision;originate()
check('new_private_cover_revises',p.revision==revision+1)
revision=p.revision;known.z=2;originate()
check('same_spatial_key_changed_floor_revises',p.revision==revision+1)
known.z=1;originate()
local temporary=O.activeCommitment('leader','strategic-cooperation')
O.pauseWork(temporary.id,'temporary-action-conflict',{})
revision=p.revision;originate()
check('temporary_pause_keeps_proposal',p.revision==revision and temporary.status=='paused')
revision=p.revision;known=nil;originate()
check('invalidated_private_cover_revises',p.revision==revision+1)
local own=O.activeCommitment('leader','strategic-cooperation')
O.noteWorkAdmission(own.id,'Posture','failed-posture-228',{stepId='watch-threat'})
local admitted,refusal=O.consumeProcedureResult({id='failed-posture-228',actorId='leader',
 commitmentId=own.id,stepId='watch-threat',token='posture:maintained',
 owner='Posture',status='failed',reason='native-refusal',at=101})
check('exact_procedure_failure_retained_'..tostring(refusal)..'_'..tostring(own.work.phase),
 admitted and own.work.phase=='step-failed' and own.status=='paused')
revision=p.revision;originate()
check('known_procedure_failure_revises',p.revision==revision+1 and own.status=='superseded')
check('failure_receipt_survives_revision',O.workReceipts['procedure:failed-posture-228']~=nil)
check('revision_requires_new_recipient_reception',O.viewFor('peer',p.id,false).reception==nil
 and O.activeCommitment('peer','strategic-cooperation')==nil)
own=O.activeCommitment('leader','strategic-cooperation')
local released=O.releaseProcedureStep(own.id,'watch-threat','private-disagreement',{})
revision=p.revision;originate()
check('known_released_step_revises',released and p.revision==revision+1)
SAO.ProceduralPlanning=nil
for _,row in ipairs({{42.5,true,'above_separation_boundary_keeps_revision'},
 {43,true,'exact_separation_boundary_keeps_revision'},
 {43.5,false,'below_separation_boundary_revises'}}) do
 situation={threat={x=40.2,y=40.2,z=0,dist=.2,source='observed'},
  threatCount=1,position={x=40.4,y=40.2,z=0}}
 local original=originate()
 local proposal=O.viewFor('leader',original.id,false).proposal.proposal
 local target=proposal.procedure[2].target
 check('measured_separation_fixture_ground',target.x==47 and target.y==40)
 local version=original.revision
 situation.threat.x=row[1];situation.threat.y=40
 local next,why=originate()
 check(row[3],row[2] and next.revision==version and why=='continuing'
  or not row[2] and next.revision==version+1)
end
return 'PASS tactical continuity '..checks
end)()'''

JAVA_PROBE = r'''
import com.sao.engine.SAORouteState;
import java.util.List;
public class RouteProgressProbe {
 static void check(String name, boolean value) { if(!value) throw new AssertionError(name); }
 public static void main(String[] args) {
  SAORouteState s=new SAORouteState();
  check("unowned_route_unavailable",s.progress().equals("MOVE_PROGRESS_UNAVAILABLE"));
  s.requested=true;s.targetX=10.5f;s.targetY=20.5f;s.targetZ=1;
  check("native_selected_target",s.progress().equals("MOVE_PROGRESS@-1@10.5@20.5@1.0"));
  s.setRoute(List.of(new float[]{3,4,0},new float[]{5,6,1}));
  check("native_current_waypoint",s.progress().equals("MOVE_PROGRESS@0@3.0@4.0@0.0"));
  String a=s.progress();check("read_does_not_advance",s.progress().equals(a)&&s.routeIndex==0);
  s.advance();check("actual_node_advance_visible",s.progress().equals("MOVE_PROGRESS@1@5.0@6.0@1.0"));
  s.requested=false;check("retired_route_unavailable",s.progress().equals("MOVE_PROGRESS_UNAVAILABLE"));
  System.out.println("PASS native route progress 6");
 }
}
'''

JAVA_BRIDGE_PROBE = '\nimport com.sao.bridge.SAOBridge;\nimport com.sao.engine.SAOIsoPlayerShell;\nimport com.sao.engine.SAORouteState;\nimport java.lang.reflect.Field;\nimport java.util.Map;\nimport java.util.WeakHashMap;\nimport sun.misc.Unsafe;\npublic class RouteBridgeProbe {\n static void check(String name, boolean ok) { if(!ok) throw new AssertionError(name); }\n public static void main(String[] args) throws Exception {\n  Field access=Unsafe.class.getDeclaredField("theUnsafe");access.setAccessible(true);\n  Unsafe unsafe=(Unsafe)access.get(null);\n  SAOIsoPlayerShell shell=(SAOIsoPlayerShell)unsafe.allocateInstance(SAOIsoPlayerShell.class);\n  SAOBridge bridge=SAOBridge.INSTANCE;\n  check("foreign_object_refused",bridge.moveProgress(new Object()).equals("NOT_A_SHELL"));\n  check("missing_route_unavailable",bridge.moveProgress(shell).equals("MOVE_PROGRESS_UNAVAILABLE"));\n  Field field=SAOBridge.class.getDeclaredField("routes");field.setAccessible(true);\n  Object previous=field.get(bridge);\n  Map<SAOIsoPlayerShell,SAORouteState> failed=new WeakHashMap<>() {\n   @Override public SAORouteState get(Object key) { throw new IllegalStateException("injected-route-read"); }\n  };\n  try {\n   field.set(bridge,failed);\n   check("bridge_read_failure_unavailable",bridge.moveProgress(shell).equals("MOVE_PROGRESS_UNAVAILABLE"));\n  } finally { field.set(bridge,previous); }\n  System.out.println("PASS actual Bridge route 3");\n }\n}\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    game=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    if not all(p.is_file() for p in (game/'projectzomboid.jar',game/'stdlib.lua',jdk/'java.exe',jdk/'javac.exe')):
        print('Border 228 SKIPPED: installed engine/JDK unavailable')
        return 0
    receipt={'schema':'sao-route-progress/1','status':'running','controls':[],
             'sources':{str(p):hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
                        for p in (LOCO,COORD,ORG,STATE,BRIDGE,Path('tools/route_progress_test.py'))},
             'nativeDependencies':{str(p):hashlib.sha256(p.read_bytes()).hexdigest()
                                   for p in (ROOT/'mod/42.20/media/java/SAO.jar',game/'projectzomboid.jar',game/'ZombieBuddy.jar')}}
    output=args.output.resolve() if args.output else None
    if output: output.mkdir(parents=True,exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix='sao-route-progress-') as tmp:
            work=Path(tmp)
            def run(command,label):
                done=subprocess.run([str(v) for v in command],cwd=work,capture_output=True,
                                    text=True,encoding='utf-8',errors='replace',timeout=120)
                text=done.stdout+done.stderr
                if output: (output/(label+'.log')).write_text(text,encoding='utf-8')
                return done.returncode,text
            code,text=run([jdk/'javac.exe','-cp',game/'projectzomboid.jar','-d',work,
                           ROOT/'tools/luacheck/LuaRun.java'],'compile-lua')
            assert code==0,text
            shutil.copy2(game/'stdlib.lua',work/'stdlib.lua')
            cp=os.pathsep.join((str(game/'projectzomboid.jar'),str(work)))
            def lua(prelude,sources,probe,label):
                files=[]
                for name,source in [('prelude.lua',prelude),*sources,('probe.lua','__result='+probe)]:
                    (work/name).write_text(source,encoding='utf-8');files.append(work/name)
                return run([jdk/'java.exe','-cp',cp,'LuaRun',*files,'--','__result'],label)
            loco=(ROOT/LOCO).read_text(encoding='utf-8')
            code,text=lua(PRELUDE,[('locomotion.lua',loco)],PROBE,'route-production')
            assert code==0 and 'VALUE PASS route progress' in text,text
            receipt['routeCases']=int(re.search(r'PASS route progress (\d+)',text)[1])
            spec=importlib.util.spec_from_file_location('natural_fixture',ROOT/'tools/natural_cooperation_test.py')
            fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
            coord=(ROOT/COORD).read_text(encoding='utf-8');org=(ROOT/ORG).read_text(encoding='utf-8')
            code,text=lua(fixture.FORMATION_PRELUDE,[('org.lua',org),('coord.lua',coord)],TACTICAL_PROBE,'tactical-production')
            assert code==0 and 'VALUE PASS tactical continuity' in text,text
            receipt['tacticalCases']=int(re.search(r'PASS tactical continuity (\d+)',text)[1])
            controls=[
                ('separation-exclusive',coord,
                 '>= MIN_TACTICAL_FALLBACK_SEPARATION_SQUARED',
                 '> MIN_TACTICAL_FALLBACK_SEPARATION_SQUARED',
                 'exact_separation_boundary_keeps_revision'),
                ('unsafe-separation-retained',coord,
                 'dx * dx + dy * dy >= MIN_TACTICAL_FALLBACK_SEPARATION_SQUARED',
                 'true','below_separation_boundary_revises'),
                ('verdict-stall-restored',loco,'if job.noProgressTicks >= STALL_TICKS then',
                 'if job.sameVerdictTicks >= STALL_TICKS then','repeated_verdict_with_physical_progress_survives'),
                ('stall-disabled',loco,'if job.noProgressTicks >= STALL_TICKS then',
                 'if false then','stationary_route_stalls'),
                ('final-goal-instead-of-native-waypoint',loco,'if ok then\n        index, tx, ty, tz =',
                 'if false then\n        index, tx, ty, tz =','native_detour_away_from_final_goal_survives'),
                ('tactical-motion-revision-restored',coord,'if not needsRevision and sameEvidence and priorKey == situationKey',
                 'if false and sameEvidence and priorKey == situationKey','actor_motion_keeps_revision'),
                ('changed-threat-ignored',coord,'if not needsRevision and sameEvidence and priorKey == situationKey',
                 'if not needsRevision and sameEvidence and priorKey','changed_private_threat_context_revises'),
                ('new-private-cover-ignored',coord,
                 'sameEvidence = (prior.scope and prior.scope.spatialFact) == candidate.spatialFact',
                 'sameEvidence = true or (prior.scope and prior.scope.spatialFact) == candidate.spatialFact',
                 'same_coordinate_private_cover_revises'),
                ('procedure-failure-ignored',coord,'needsRevision = true','needsRevision = false',
                 'known_procedure_failure_revises'),
                ('intermittent-progress-restored',loco,'if retained then','if false then',
                 'intermittent_waypoint_reads_do_not_grant_progress_MOVE_PROGRESS_UNAVAILABLE'),
                ('equal-intent-bypasses-evidence',coord,
                 'if not needsRevision and sameEvidence and tostring(prior.intentKey or "") == intentKey then',
                 'if not needsRevision and tostring(prior.intentKey or "") == intentKey then',
                 'same_coordinate_private_cover_revises'),
                ('known-cover-floor-ignored',coord,'and fallback.y == candidate.y and fallback.z == candidate.z',
                 'and fallback.y == candidate.y','same_spatial_key_changed_floor_revises'),
            ]
            for label,source,old,new,marker in controls:
                assert source.count(old)==1,label+' seam drift'
                candidate=source.replace(old,new,1);assert candidate!=source
                if source==loco:
                    code,text=lua(PRELUDE,[('locomotion.lua',candidate)],PROBE,label)
                else:
                    code,text=lua(fixture.FORMATION_PRELUDE,[('org.lua',org),('coord.lua',candidate)],TACTICAL_PROBE,label)
                assert code!=0 and 'ROUTE_PROGRESS:'+marker in text,label+': '+text
                receipt['controls'].append({'name':label,'assertion':marker,'rejected':True})
            (work/'RouteProgressProbe.java').write_text(JAVA_PROBE,encoding='utf-8')
            state=(ROOT/STATE).read_text(encoding='utf-8')
            (work/'SAORouteState.java').write_text(state,encoding='utf-8')
            installed_cp=os.pathsep.join(map(str,[ROOT/'mod/42.20/media/java/SAO.jar',game/'projectzomboid.jar',game/'ZombieBuddy.jar']))
            route_cp=os.pathsep.join([str(work),installed_cp])
            code,text=run([jdk/'javac.exe','-cp',installed_cp,'-d',work,work/'SAORouteState.java',work/'RouteProgressProbe.java'],'compile-native')
            assert code==0,text
            code,text=run([jdk/'java.exe','-cp',route_cp,'RouteProgressProbe'],'native-production')
            assert code==0 and 'PASS native route progress 6' in text,text
            receipt['nativeCases']=6
            old='(node == null ? -1 : routeIndex)';assert state.count(old)==1
            (work/'SAORouteState.java').write_text(state.replace(old,'(node == null ? -1 : 0)',1),encoding='utf-8')
            code,text=run([jdk/'javac.exe','-cp',installed_cp,'-d',work,work/'SAORouteState.java',work/'RouteProgressProbe.java'],'compile-native-control')
            assert code==0,text
            code,text=run([jdk/'java.exe','-cp',route_cp,'RouteProgressProbe'],'native-control')
            assert code!=0 and 'actual_node_advance_visible' in text,text
            receipt['controls'].append({'name':'native-node-advance-hidden','assertion':'actual_node_advance_visible','rejected':True})
            bridge=(ROOT/BRIDGE).read_text(encoding='utf-8')
            assert re.search(r'public String moveProgress\(Object object\).*?routes.get\(shell\).*?state.progress\(\)',bridge,re.S)
            assert bridge.count('SAOAgent.log("moveProgress threw: " + throwable);')==1
            assert (ROOT/'mod/42.20/media/java/SAO.jar').is_file()
            assert (game/'ZombieBuddy.jar').is_file()
            bridge_work=work/'bridge-proof';bridge_work.mkdir()
            (bridge_work/'RouteBridgeProbe.java').write_text(JAVA_BRIDGE_PROBE,encoding='utf-8')
            code,text=run([jdk/'javac.exe','-cp',installed_cp,'-d',bridge_work,bridge_work/'RouteBridgeProbe.java'],'compile-actual-bridge')
            assert code==0,text
            sandbox=work/'bridge-home';sandbox.mkdir()
            actual_cp=os.pathsep.join([str(bridge_work),installed_cp])
            code,text=run([jdk/'java.exe','-Duser.home='+str(sandbox),'--enable-native-access=ALL-UNNAMED','-Djava.library.path='+str(game),'-cp',actual_cp,'RouteBridgeProbe'],'actual-bridge')
            assert code==0 and 'PASS actual Bridge route 3' in text,text
            receipt['bridgeCases']=3
            guarded = '    public String moveProgress(Object object) {\n        try {\n            if (!(object instanceof SAOIsoPlayerShell shell)) return "NOT_A_SHELL";\n            SAORouteState state = routes.get(shell);\n            return state == null ? "MOVE_PROGRESS_UNAVAILABLE" : state.progress();\n        } catch (Throwable throwable) {\n            SAOAgent.log("moveProgress threw: " + throwable);\n            return "MOVE_PROGRESS_UNAVAILABLE";\n        }\n    }'
            unguarded = '    public String moveProgress(Object object) {\n        if (!(object instanceof SAOIsoPlayerShell shell)) return "NOT_A_SHELL";\n        SAORouteState state = routes.get(shell);\n        return state == null ? "MOVE_PROGRESS_UNAVAILABLE" : state.progress();\n    }'
            assert bridge.count(guarded)==1
            candidate=bridge.replace(guarded,unguarded,1)
            mutant=work/'bridge-control';mutant.mkdir()
            (mutant/'SAOBridge.java').write_text(candidate,encoding='utf-8')
            code,text=run([jdk/'javac.exe','-cp',installed_cp,'-d',mutant,mutant/'SAOBridge.java'],'compile-bridge-control')
            assert code==0,text
            mutant_cp=os.pathsep.join([str(mutant),actual_cp])
            code,text=run([jdk/'java.exe','-Duser.home='+str(sandbox),'--enable-native-access=ALL-UNNAMED','-Djava.library.path='+str(game),'-cp',mutant_cp,'RouteBridgeProbe'],'bridge-control')
            assert code!=0 and 'injected-route-read' in text,text
            receipt['controls'].append({'name':'bridge-read-guard-removed','assertion':'injected-route-read','rejected':True})
        receipt['status']='passed'
        print(f"Border 228 PASS: {receipt['routeCases']} route, {receipt['tacticalCases']} tactical, 6 native route and 3 actual Bridge cases; {len(receipt['controls'])} rejected source controls")
        return 0
    except (AssertionError,OSError,subprocess.SubprocessError) as error:
        receipt['status']='failed';receipt['error']=str(error)
        print('Border 228 FAIL: '+str(error))
        return 1
    finally:
        if output: (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':
    raise SystemExit(main())
