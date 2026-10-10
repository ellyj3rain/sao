#!/usr/bin/env python3
"""D3.5 installed collector recipes/build actions/factory and exact SAO ownership.

Private VM outputs; actor/map/dispatch/UI receivers are controlled. Actual Java
weather/supplier geometry is qualified by the material owner's companion proof.
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
PROBE=ROOT/'tools/resource_production_checks/BedConstructionNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/bed_construction_cases.lua'
CTL_CASES=ROOT/'tools/resource_production_checks/bed_controller_cases.lua'
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
    'media/lua/server/BuildingObjects/ISBuildIsoEntity.lua','media/lua/client/BuildingObjects/TimedActions/ISBuildAction.lua']]
SCRIPTS=[GAME/p for p in ['media/scripts/generated/entities/furniture/entity_carpentry_bed.txt','media/newtiledefinitions.tiles',
    'media/scripts/generated/items/normal.txt','media/scripts/generated/items/moveable.txt','media/scripts/generated/items/container.txt',
    'media/scripts/generated/items/weapon.txt','media/scripts/generated/timedactions.txt']]

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
    chunks['controller.lua']='local Ctl=SAO.Controller\nlocal function setState(agent,id,state) agent.state=state;return true end\nlocal function policy() return {desperation=.85} end\nlocal function mayEnterBelieved() return true end\nlocal function resolvedHomeAddress() return 0,0,0 end\nlocal function occupiesKnownHome() return true end\nlocal function rememberedRecoveryInquiry() end\nlocal function recoveryPlaceReason() return "visible bed" end\nlocal function pendingRecoveryPlaceCopy(place) return place end\nlocal function log() end\nfunction Ctl.beginConstructionAcquisition('+acquire+'\nfunction Ctl.admitRecoveryPlace('+admission+'\nfunction Ctl.bedConstructionContext('+recovery
    chunks['controller-cases.lua']=CTL_CASES.read_text(encoding='utf-8-sig')
    return chunks

def execute(out,chunks,classes,expected):
    out.mkdir()
    shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua')
    paths=[]
    for name,source in chunks.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),
        '-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar'),'BedConstructionNativeProbe',str(GAME),*paths]
    done=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=90)
    log=out/'output.log';log.write_text(done.stdout+done.stderr,encoding='utf-8')
    checks=dict(re.findall(r'^([a-zA-Z0-9_]+)=(true|false)$',done.stdout,re.M))
    return {'exitCode':done.returncode,'checks':checks,'failed':sorted(k for k,v in checks.items() if v!='true'),
        'missing':sorted(expected-checks.keys()),'extra':sorted(checks.keys()-expected),'logSha256':digest(log)}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path);parser.add_argument('--required',action='store_true')
    parser.add_argument('--native-preflight',action='store_true')
    args=parser.parse_args()
    java_sources=[ROOT/'java/src/com/sao/engine/SAOBedConstruction.java',ROOT/'java/src/com/sao/engine/SAONeeds.java',
        ROOT/'java/src/com/sao/engine/SAOWorldSources.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java']
    movement=ROOT/'tools/luacheck/MovementCrossingProbe.java'
    owned=[Path(__file__),PROBE,CASES,CTL_CASES,CONTROLLER,BASE,BOARD,PLUMB,*LEAVES.values(),ROOT/'tools/luacheck/LuaSyntax.java',*java_sources,movement]
    missing=[str(p) for p in owned if not p.is_file()]
    if missing:print('FAIL mandatory owned bed construction inputs absent: '+', '.join(missing));return 1
    installed=[*NATIVE,*SCRIPTS,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',ROOT/'mod/42.20/media/java/SAO.jar']
    missing=[str(p) for p in installed if not p.is_file()]
    if missing:
        print(('FAIL required' if args.required else 'UNCHECKED')+' installed bed construction runtime absent: '+', '.join(missing))
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
        '-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar'),'BedConstructionNativeProbe',str(GAME)],
        cwd=out,text=True,capture_output=True,timeout=60)
    (out/'bootstrap.log').write_text(bootstrap.stdout+bootstrap.stderr,encoding='utf-8')
    bootstrap_ok=bootstrap.returncode==0 and "PAYMENT true" in bootstrap.stdout and bootstrap.stdout.count("sameGrid=true")==2
    if args.native_preflight:
        print(bootstrap.stdout);print(bootstrap.stderr)
        return 0 if bootstrap_ok and syntax.returncode==0 else 1
    geometry=subprocess.run([str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),
        '-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar'),
        'BedConstructionNativeProbe',str(GAME),'--geometry'],cwd=out,text=True,capture_output=True,timeout=60)
    (out/'geometry.log').write_text(geometry.stdout+geometry.stderr,encoding='utf-8')
    geometry_checks=dict(re.findall(r'^JAVA ([A-Za-z0-9_]+)=(true|false)$',geometry.stdout,re.M))
    samples=re.search(r'SLEEP_SAMPLE before=([0-9.Ee-]+) after=([0-9.Ee-]+)',geometry.stdout)
    chunks=sources()
    if samples:chunks['native-sleep-sample.lua']='__nativeSleepBefore='+samples.group(1)+';__nativeSleepAfter='+samples.group(2)
    chunks['run.lua']='__runBedConstructionCases();__runBedControllerCases();__runBedPrivateAcquisitionCases();__runBedCustodyCases()'
    fixture=CASES.read_text(encoding='utf-8-sig')
    expected={'native_bed_'+face+'_'+contract for face in ['S','E'] for contract in ['admission_no_credit','allparts_exactpayment','private_construction_only','observed_recovery_source']}
    expected.update(re.findall(r"__bedCheck\('([a-z0-9_]+)'",CTL_CASES.read_text(encoding='utf-8-sig')))
    expected.update(re.findall(r"check\('([a-z0-9_]+)'",CASES.read_text(encoding='utf-8-sig').split('function __runBedCustodyCases()',1)[1]))
    normal=execute(out/'normal',chunks,classes,expected)

    controls=[]
    mutations=[
        ('dependent-recovery-successor','planner.lua','then recovery.status="available" end','then recovery.status="dependent" end',
            'canonical_bed_creation_unlocks_recovery_without_relief'),
        ('interrupted-recovery-retirement','planner.lua','p.lastAdmission=dataCopy(a);p.admission=nil;step.status="available"',
            'p.lastAdmission=dataCopy(a);step.status="available"','native_quiet_exit_retires_only_recovery_attempt'),
        ('physiology-fact-projection','cognition.lua','entry and receipt.sourceId or nil','receipt.sourceId',
            'construction_and_recovery_have_separate_private_credit'),
        ('native-construction-ack','production.lua','if not plumbRetired(rt) or rec~=rt.record or rec.resourceProductionWork~=w or not bed.identity(rt.id,w)',
            'if false or rec~=rt.record or rec.resourceProductionWork~=w or not bed.identity(rt.id,w)','pending_native_bed_ack_retains_single_work_claim'),
        ('all-parts-measurement','production.lua','#parts~=2 or parts[1]==parts[2]','#parts~=1 or parts[1]==parts[2]',
            'native_bed_S_allparts_exactpayment'),
        ('constructor-owner-effect','production.lua','if not c or not c.performing or not plumbCurrent(c) or not collector.bound(rt,true)',
            'if not c or false or not plumbCurrent(c) or not collector.bound(rt,true)','direct_native_bed_create_cannot_pay')]
    for name,file,old,new,detector in mutations:
        variant=dict(chunks);count=variant[file].count(old)
        if count!=1:controls.append({'name':name,'detected':False,'mutationMatches':count});continue
        variant[file]=variant[file].replace(old,new,1)
        if name=='all-parts-measurement':variant['run.lua']='__runBedConstructionCases()'
        elif name=='interrupted-recovery-retirement':variant['run.lua']='__selectedBedControl="interrupted-recovery-retirement";__runBedControllerCases()'
        result=execute(out/name,variant,classes,{detector})
        controls.append({'name':name,'target':detector,'detected':result['exitCode']==0 and result['checks'].get(detector)=='false',**result})
    java_controls=[]
    bed_source=java_sources[0].read_text(encoding='utf-8-sig')
    for name,old,new,detector in [
        ('native-head-end','return !(x==0&&y==0&&','return !(false&&','head_end_only_cannot_offer_bed_S'),
        ('retained-approach-clearance','&& exactApproach(body,base,face,site.ax,site.ay)','&& true','retained_approach_occupant_refuses_S')]:
        directory=out/name;directory.mkdir()
        if bed_source.count(old)!=1:java_controls.append({'name':name,'detected':False,'mutationMatches':bed_source.count(old)});continue
        changed=directory/'SAOBedConstruction.java';changed.write_text(bed_source.replace(old,new,1),encoding='utf-8')
        cp=str(classes)+os.pathsep+str(GAME/'projectzomboid.jar')+os.pathsep+str(ROOT/'mod/42.20/media/java/SAO.jar')+os.pathsep+str(GAME/'ZombieBuddy.jar')
        compiled_control=subprocess.run([str(JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(directory),str(changed)],capture_output=True,text=True,timeout=60)
        (directory/'compile.log').write_text(compiled_control.stdout+compiled_control.stderr,encoding='utf-8')
        command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(directory),'-cp',str(directory)+os.pathsep+cp,
            'BedConstructionNativeProbe',str(GAME),'--geometry']
        verdict=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=60)
        log=directory/'output.log';log.write_text(verdict.stdout+verdict.stderr,encoding='utf-8')
        values=dict(re.findall(r'^JAVA ([A-Za-z0-9_]+)=(true|false)$',verdict.stdout,re.M))
        # Actual Java assertions name their failed native branch and exit1.
        java_controls.append({'name':name,'target':detector,'detected':compiled_control.returncode==0 and values.get(detector)=='false'
            and verdict.returncode==1 and 'AssertionError: '+detector in verdict.stderr,'compileExit':compiled_control.returncode,
            'exitCode':verdict.returncode,'checks':values,'logSha256':digest(log)})
    after={str(p):digest(p) for p in inputs}
    passed=geometry.returncode==0 and geometry_checks and all(v=='true' for v in geometry_checks.values()) and bootstrap_ok and syntax.returncode==0 and normal['exitCode']==0 and not normal['failed'] and not normal['missing'] and before==after and all(c['detected'] for c in controls+java_controls)
    receipt={'status':'PASS' if passed else 'FAIL','inputsBefore':before,'inputsAfter':after,'sourcePreserved':before==after,'normal':normal,'controls':controls,'javaControls':java_controls,
        'geometry':{'exitCode':geometry.returncode,'checks':geometry_checks,'logSha256':digest(out/'geometry.log')},'compileExit':compiled.returncode,'syntaxExit':syntax.returncode,'bootstrapExit':bootstrap.returncode,
        'boundary':'Actual installed entity recipe/parser/manual BuildLogic payment/factory and native sprite-grid metadata; installed Lua build/transfer/equip/queue and actual SAO private planning/cognition. Actor/map/dispatch/source/recovery query receivers controlled; existing native recovery evidence remains separate.'}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(receipt['status']+' bed construction '+str(len(normal['checks']))+' cases; '+str(out/'receipt.json'))
    if not passed:print(normal);print((out/'normal/output.log').read_text(encoding='utf-8')[-5000:])
    return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
