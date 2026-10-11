#!/usr/bin/env python3
"""D3.9 native wall/door recipes, exact construction and ordinary shelter use.

Private VM outputs; actor/map/dispatch/UI receivers are controlled. Native geometry, doorway and region effects have their own scoped proof.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA=ROOT/'mod/42.20/media/lua'
PROBE=ROOT/'tools/resource_production_checks/ShelterConstructionNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/shelter_construction_cases.lua'
CTL_CASES=ROOT/'tools/resource_production_checks/shelter_controller_cases.lua'
CONTROLLER=LUA/'client/SAO_Controller.lua'
BASE=ROOT/'tools/luacheck/window_repair_cases.lua'
BOARD=ROOT/'tools/luacheck/d3_native_boarding_cases.lua'
PLUMB=ROOT/'tools/resource_production_checks/plumbing_cases.lua'
LEAVES={k:LUA/f'{area}/SAO_{name}.lua' for k,area,name in [
    ('sources','shared','WorldSources'),('perception','shared','Perception'),
    ('models','shared','CognitiveModels'),('cognition','shared','Cognition'),('labor','shared','Labor'),
    ('planner','shared','ProceduralPlanning'),('production','client','ResourceProduction'),
    ('experience','client','CapabilityExperience'),('needs','client','Needs')]}
NATIVE=[GAME/p for p in [
    'media/lua/shared/ISBaseObject.lua','media/lua/shared/TimedActions/ISBaseTimedAction.lua',
    'media/lua/client/TimedActions/ISTimedActionQueue.lua','media/lua/shared/TimedActions/ISEquipWeaponAction.lua',
    'media/lua/client/TimedActions/ISInventoryTransferAction.lua','media/lua/shared/TimedActions/ISPlumbItem.lua',
    'media/lua/shared/TimedActions/ISTakeWaterAction.lua','media/lua/server/BuildingObjects/ISBuildingObject.lua',
    'media/lua/server/BuildingObjects/ISBuildIsoEntity.lua','media/lua/client/BuildingObjects/TimedActions/ISBuildAction.lua','media/lua/shared/TimedActions/ISOpenCloseDoor.lua','media/lua/server/BuildRecipeCode/buildRecipeCode.lua']]
SCRIPTS=[GAME/p for p in ['media/scripts/generated/entities/walls/'+name+'.txt' for name in [
    'entity_woodenwallframe','entity_wood_walllvl1','entity_wood_walllvl2','entity_wood_walllvl3',
    'entity_wood_doorframelvl1','entity_wood_doorframelvl2','entity_wood_doorframelvl3',
    'entity_woodendoorlvl1','entity_woodendoorlvl2','entity_woodendoorlvl3']]]+[GAME/p for p in [
    'media/newtiledefinitions.tiles','media/scripts/generated/items/normal.txt','media/scripts/generated/items/weapon.txt','media/scripts/generated/timedactions.txt']]

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def sources():
    chunks={'base.lua':BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()',1)[0],
        'boarding-fixture.lua':BOARD.read_text(encoding='utf-8-sig')+
        '\n__boardingFixture=fixture;__boardingItem=item;__boardingInventory=inventory\n'}
    chunks.update({f'native-{i}.lua':p.read_text(encoding='utf-8-sig') for i,p in enumerate(NATIVE)})
    chunks['plumbing-fixture.lua']=PLUMB.read_text(encoding='utf-8-sig').split('function __runPlumbingControl',1)[0]+'\n__plumbingFixture=fixture\n'
    chunks['rain-fixture.lua']=CASES.read_text(encoding='utf-8-sig')
    chunks.update({name+'.lua':p.read_text(encoding='utf-8-sig') for name,p in LEAVES.items()})
    chunks['needs-ports.lua']='SAO.Needs.read=function(body) return {hunger=.1,thirst=.1,fatigue=body.fatigue or .65,endurance=.8} end;SAO.Needs.busy=function(body) local q=ISTimedActionQueue.getTimedActionQueue(body);return q.current~=nil or #q.queue>0 end;SAO.Needs.workAvailable=function() return true end;SAO.Needs.ownsRecoveryBody=function(id,body) return SAO.Body.get(id)==body end'

    ctl=CONTROLLER.read_text(encoding='utf-8-sig')
    recovery=ctl.split("function Ctl.bedConstructionContext(",1)[1].split("-- One ordinary choice compares",1)[0]
    acquire=ctl.split("function Ctl.beginConstructionAcquisition(",1)[1].split("local function rememberConstructionDestination",1)[0]
    admission=ctl.split("function Ctl.admitRecoveryPlace(",1)[1].split("local function savedPreparationWorkBlocked",1)[0]
    arrival=ctl.split("function Ctl.finishRecoveryPlaceMovement(",1)[1].split("local function rememberedRecoveryInquiry",1)[0]
    chunks['controller.lua']='local Ctl=SAO.Controller\nlocal function setState(agent,id,state) agent.state=state;return true end\nlocal function policy() return {desperation=.85} end\nlocal function mayEnterBelieved() return true end\nlocal function resolvedHomeAddress() return 0,0,0 end\nlocal function occupiesKnownHome() return true end\nlocal function rememberedRecoveryInquiry() end\nlocal function recoveryPlaceReason() return "visible ground" end\nlocal function pendingRecoveryPlaceCopy(place) return place end\nlocal function log() end\nfunction Ctl.beginConstructionAcquisition('+acquire+'\nfunction Ctl.admitRecoveryPlace('+admission+'\nfunction Ctl.bedConstructionContext('+recovery
    chunks['controller.lua']+='\nlocal tickCount=0\nfunction __shelterControllerTick(value) tickCount=value end\nfunction Ctl.finishRecoveryPlaceMovement('+arrival
    chunks['controller-cases.lua']=CTL_CASES.read_text(encoding='utf-8-sig')
    return chunks

def execute(out,chunks,classes,expected):
    out.mkdir()
    shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua')
    paths=[]
    for name,source in chunks.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),
        '-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar'),'ShelterConstructionNativeProbe',str(GAME),*paths]
    log=out/'output.log'
    with log.open('w',encoding='utf-8') as stream:
        try:
            done=subprocess.run(command,cwd=out,text=True,stdout=stream,stderr=subprocess.STDOUT,timeout=90)
        except subprocess.TimeoutExpired:
            stream.write('\\nFAIL native case process timed out\\n')
            done=subprocess.CompletedProcess(command,124)
    output=log.read_text(encoding='utf-8',errors='replace')
    checks=dict(re.findall(r'^([a-zA-Z0-9_]+)=(true|false)$',output,re.M))
    return {'exitCode':done.returncode,'checks':checks,'failed':sorted(k for k,v in checks.items() if v!='true'),
        'missing':sorted(expected-checks.keys()),'extra':sorted(checks.keys()-expected),'logSha256':digest(log)}

def native_execute(out,classes,mode,expected,override=None):
    out.mkdir();shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua')
    cp=[*([str(override)] if override else []),str(classes),str(GAME/'projectzomboid.jar'),str(ROOT/'mod/42.20/media/java/SAO.jar'),str(GAME/'ZombieBuddy.jar')]
    command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',os.pathsep.join(cp),
        'ShelterConstructionNativeProbe',str(GAME),'--focused-native',mode]
    done=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=90)
    log=out/'output.log';log.write_text(done.stdout+done.stderr,encoding='utf-8')
    checks=dict(re.findall(r'^JAVA ([a-zA-Z0-9_]+)=(true|false)$',done.stdout,re.M))
    return {'exitCode':done.returncode,'checks':checks,'failed':sorted(k for k,v in checks.items() if v!='true'),
        'missing':sorted(expected-checks.keys()),'logSha256':digest(log)}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path);parser.add_argument('--required',action='store_true')
    parser.add_argument('--native-preflight',action='store_true')
    parser.add_argument('--ordinary-only',action='store_true')
    args=parser.parse_args()
    java_sources=[ROOT/'java/src/com/sao/engine/SAOShelterConstruction.java',ROOT/'java/src/com/sao/engine/SAONeeds.java',
        ROOT/'java/src/com/sao/engine/SAOWorldSources.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java']
    java_sources.append(ROOT/'java/src/com/sao/engine/SAOIsoPlayerShell.java')
    movement=ROOT/'tools/luacheck/MovementCrossingProbe.java'
    owned=[Path(__file__),PROBE,CASES,CTL_CASES,CONTROLLER,BASE,BOARD,PLUMB,*LEAVES.values(),ROOT/'tools/luacheck/LuaSyntax.java',*java_sources,movement]
    missing=[str(p) for p in owned if not p.is_file()]
    if missing:print('FAIL mandatory owned shelter construction inputs absent: '+', '.join(missing));return 1
    installed=[*NATIVE,*SCRIPTS,GAME/'media/lua/shared/defines.lua',GAME/'media/lua/server/BuildingObjects/ISBuildUtil.lua',GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',ROOT/'mod/42.20/media/java/SAO.jar']
    missing=[str(p) for p in installed if not p.is_file()]
    if missing:
        print(('FAIL required' if args.required else 'UNCHECKED')+' installed shelter construction runtime absent: '+', '.join(missing))
        return 1 if args.required else 0
    temporary=tempfile.TemporaryDirectory(prefix='sao-native-collector-') if args.out is None else None
    out=Path(temporary.name)/'proof' if temporary else args.out.resolve()
    if out.exists():raise ValueError('refuse replacing previous native proof')
    out.mkdir(parents=True)
    inputs=owned+installed;before={str(p):digest(p) for p in inputs}
    classes=out/'classes';classes.mkdir()
    compiled=subprocess.run([str(JDK/'javac.exe'),'-cp',str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar'),'-d',str(classes),
        str(PROBE),str(ROOT/'tools/luacheck/LuaSyntax.java'),str(movement),*[str(p) for p in java_sources]],text=True,capture_output=True,timeout=60)
    (out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    if compiled.returncode:print(compiled.stderr);return 1
    syntax=subprocess.run([str(JDK/'java.exe'),'-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar'),
        'LuaSyntax',str(CASES),str(CTL_CASES),str(CONTROLLER),*[str(p) for p in LEAVES.values()]],text=True,capture_output=True,timeout=60)
    (out/'syntax.log').write_text(syntax.stdout+syntax.stderr,encoding='utf-8')
    shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua')
    bootstrap=subprocess.run([str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),
        '-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar'),'ShelterConstructionNativeProbe',str(GAME)],
        cwd=out,text=True,capture_output=True,timeout=60)
    (out/'bootstrap.log').write_text(bootstrap.stdout+bootstrap.stderr,encoding='utf-8')
    bootstrap_ok=bootstrap.returncode==0 and "PAYMENT true" in bootstrap.stdout and bootstrap.stdout.count("ENTITY Base.")==10 and bootstrap.stdout.count("FACTORY face=")==20
    if args.native_preflight:
        print(bootstrap.stdout);print(bootstrap.stderr)
        return 0 if bootstrap_ok and syntax.returncode==0 else 1
    chunks=sources()
    chunks['run.lua']='__runShelterFocusedCases();__runShelterControllerCases()' if args.ordinary_only else '__runShelterConstructionCases();__runShelterFocusedCases();__runShelterControllerCases()'
    expected={'native_family_'+str(i)+'_'+face+'_'+contract for i in range(1,11) for face in ['N','W'] for contract in ['admission','payment_stage','private_feedback']}
    if args.ordinary_only:expected=set()
    expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",CTL_CASES.read_text(encoding='utf-8-sig')))
    expected.update(re.findall(r"check\('([a-z0-9_]+)'",CASES.read_text(encoding='utf-8-sig').split('function __runShelterFocusedCases()',1)[1].split('function __runShelterConstructionCases()',1)[0]))
    normal=execute(out/'normal',chunks,classes,expected)
    geometry=[]
    native_expected={
        'map-door':{'native_map_door_visible_opening','native_map_door_is_observed_occupied','native_map_door_preserves_other_wall_breach'},
        'map-door-closed':{'native_closed_door_breach_approach','native_closed_door_observation_bound',
            'native_closed_door_prevents_redundant_door_frame','native_closed_door_row_uses_observed_inside_approach'},
        'door-admission':{'native_constructed_closed_door_observe_and_lookup','native_closed_door_cannot_admit_passage',
            'native_constructed_door_opening_observed','native_opening_admits_exact_selected_capture',
            'native_occupied_exterior_is_visible_but_unavailable','native_occupied_exterior_refuses_selected_capture',
            'native_hidden_exterior_is_clear_but_unobserved','native_hidden_exterior_refuses_selected_capture'},
        'materials':{'native_'+kind+'_'+contract for kind in ['hinge','doorknob'] for contract in ['exact_category','world_source_projection','consumed_refuses']},
        'outside':{'native_safe_ground_place_excludes_doorway','native_shelter_outside_place_refuses'},
        'passage':{'native_other_door_approach','native_other_door_opened','native_selected_door_approach','native_selected_capture_admitted',
            'native_route_around_arrival_does_not_credit_selected_door','native_inward_capture_admitted','native_setter_before_postupdate_does_not_credit_passage'}}
    for mode,names in native_expected.items():
        result=native_execute(out/('native-'+mode),classes,mode,names);geometry.append({'name':mode,**result})
        print('NATIVE '+mode+' exit='+str(result['exitCode'])+' failed='+','.join(result['failed'])+' missing='+','.join(result['missing']),flush=True)
    geometry_ok=all(g['exitCode']==0 and not g['failed'] and not g['missing'] for g in geometry)
    controls=[];java_controls=[]
    mutations=[
        ('candidate-bound','planner.lua','for i,choice in ipairs(ranked) do\n        if i>15 then break end',
            'for i,choice in ipairs(ranked) do\n        if i>32 then break end',
            'thirty_two_offers_use_actual_continue_plus_fifteen_models','__selectedShelterControl="candidate-bound";__runShelterFocusedCases()'),
        ('ground-canonical-key','needs.lua','sourceId=work.pose and work.pose.place and work.pose.place.key or nil',
            'sourceId=work.pose and work.pose.place and work.pose.place.kind=="bed" and work.pose.place.key or nil',
            'native_sleep_finishes_original_shelter_concern','__runShelterControllerCases()'),
        ('canonical-ground-mismatch','planner.lua','or canonical.sourceId~=own.recoveryKey or sequence<=',
            'or false or sequence<=','canonical_ground_key_mismatch_cannot_finish','__runShelterControllerCases()'),
        ('itemless-use-feedback-gate','models.lua','if e.kind=="shelter-use" then\n            return e.category=="body"',
            'if false and e.kind=="shelter-use" then\n            return e.category=="body"',
            'construction_use_and_recovery_keep_independent_feedback','__runShelterControllerCases()'),
        ('saved-shelter-normalization','production.lua','if w.kind=="build-wood-bed" or w.kind=="build-shelter-edge" then row.feedsFixture=nil;row.parts={} end',
            'if w.kind=="build-wood-bed" then row.feedsFixture=nil;row.parts={} end',
            'saved_shelter_work_reconciles_without_fabricated_parts_or_passage','__runShelterFocusedCases()')]
    if geometry_ok:
        for name,file,old,new,detector,run in mutations:
            variant=dict(chunks);count=variant[file].count(old)
            if count!=1:controls.append({'name':name,'detected':False,'mutationMatches':count});continue
            variant[file]=variant[file].replace(old,new,1);variant['run.lua']=run
            result=execute(out/name,variant,classes,{detector})
            controls.append({'name':name,'target':detector,'mutationMatches':count,
                'detected':result['exitCode']==0 and result['checks'].get(detector)=='false',**result})
            print('CONTROL '+name+' detected='+str(controls[-1]['detected']),flush=True)
        shelter_source=java_sources[0].read_text(encoding='utf-8-sig')
        java_mutations=[
            ('route-around-arrival','passage','native_route_around_arrival_does_not_credit_selected_door',[
                ('if(last==p.from.get()&&current==p.to.get()&&open(door)','if(current==p.to.get()&&open(door)')]),
            ('setter-before-post','passage','native_setter_before_postupdate_does_not_credit_passage',[
                ('var current=body.getCurrentSquare();var last=body.getLastSquare();','var current=body.getCurrentSquare();var last=p.last.get();')]),
            ('native-map-door','map-door','native_map_door_is_observed_occupied',[
                ('if(o instanceof IsoDoor)return o;','if(false&&o instanceof IsoDoor)return o;'),
                ('if(object instanceof IsoDoor)return "door";','if(false&&object instanceof IsoDoor)return "door";')]),
            ('closed-door-occupancy','map-door-closed','native_closed_door_prevents_redundant_door_frame',[
                ('if(occupiedMode.equals("door")||occupiedMode.equals("door-leaf"))hasDoor=true;',
                    'if(false&&(occupiedMode.equals("door")||occupiedMode.equals("door-leaf")))hasDoor=true;')]),
            ('closed-door-row','map-door-closed','native_closed_door_row_uses_observed_inside_approach',[
                ('if(!neighborVisible&&!visibleDoor)continue;','if(!neighborVisible)continue;')]),
            ('passage-hidden-exterior','door-admission','native_hidden_exterior_refuses_selected_capture',[
                ('||!visible(body,outside)','||false')]),
            ('passage-occupied-exterior','door-admission','native_occupied_exterior_refuses_selected_capture',[
                ('||!free(body,from)||!free(body,to)','||false')]),
            ('outside-shelter-place','outside','native_shelter_outside_place_refuses',None)]
        for name,mode,detector,replacements in java_mutations:
            directory=out/('control-'+name);directory.mkdir();variant=shelter_source;matches=[]
            if replacements is None:
                start=variant.index('public static synchronized boolean recoveryValid(');body=variant.index('{',start);end=body+1;depth=1
                while depth:
                    if variant[end]=='{':depth+=1
                    elif variant[end]=='}':depth-=1
                    end+=1
                variant=variant[:body+1]+'return true;'+variant[end-1:];matches=[1]
            else:
                for old,new in replacements:
                    matches.append(variant.count(old));variant=variant.replace(old,new,1)
            if any(count!=1 for count in matches):java_controls.append({'name':name,'detected':False,'mutationMatches':matches});continue
            changed=directory/'SAOShelterConstruction.java';changed.write_text(variant,encoding='utf-8');control_classes=directory/'classes';control_classes.mkdir()
            cp=os.pathsep.join([str(classes),str(GAME/'projectzomboid.jar'),str(ROOT/'mod/42.20/media/java/SAO.jar'),str(GAME/'ZombieBuddy.jar')])
            compiled_control=subprocess.run([str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(control_classes),str(changed)],capture_output=True,text=True,timeout=60)
            (directory/'compile.log').write_text(compiled_control.stdout+compiled_control.stderr,encoding='utf-8')
            if compiled_control.returncode:
                java_controls.append({'name':name,'detected':False,'compileExit':compiled_control.returncode});continue
            result=native_execute(directory/'run',classes,mode,{detector},control_classes)
            java_controls.append({'name':name,'target':detector,'compileExit':compiled_control.returncode,'mutationMatches':matches,
                'detected':result['exitCode']==1 and result['checks'].get(detector)=='false'
                    and 'AssertionError: '+detector in (directory/'run/output.log').read_text(encoding='utf-8'),**result})
            print('CONTROL '+name+' detected='+str(java_controls[-1]['detected']),flush=True)
    after={str(p):digest(p) for p in inputs}
    passed=bootstrap_ok and syntax.returncode==0 and normal['exitCode']==0 and not normal['failed'] and not normal['missing'] and before==after and geometry_ok\
        and len(controls)==len(mutations) and len(java_controls)==8 and all(c['detected'] for c in controls+java_controls)
    receipt={'status':'PASS' if passed else 'FAIL','inputsBefore':before,'inputsAfter':after,'sourcePreserved':before==after,
        'normal':normal,'controls':controls,'javaControls':java_controls,'nativeGeometry':geometry,'compileExit':compiled.returncode,'syntaxExit':syntax.returncode,'bootstrapExit':bootstrap.returncode,
        'boundary':'Actual installed recipe/manual BuildLogic payment/factory and installed Lua build/transfer/equip/queue; SAO ordinary Controller/Needs/Planner and independent feedback. Actual same-body native movement/collision/selected-door passage, DataRoot enclosure/fullroof, RecoveryPlace safe ground admission and SleepingEvent fatigue. Actor/map/source/dispatch, animation/stride/pose and county clock are explicit controlled ports. Full play, animation qualification and native server execution are outside this packet.'}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(receipt['status']+' shelter construction '+str(len(normal['checks']))+' cases; '+str(out/'receipt.json'))
    if not passed:print(normal);print((out/'normal/output.log').read_text(encoding='utf-8')[-5000:])
    return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
