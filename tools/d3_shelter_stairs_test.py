#!/usr/bin/env python3
"""Native stair construction from acquired footprint through upper work and usable shelter."""
from __future__ import annotations
import argparse,json,os,re,shutil,subprocess
from pathlib import Path
import d3_shelter_construction_test as base
import d3_shelter_surface_test as surface
from native_proof_preflight import presence

ROOT=base.ROOT
CASES=ROOT/'tools/resource_production_checks/shelter_stairs_cases.lua'
JAVA=list(dict.fromkeys([ROOT/'java/src/com/sao/engine/SAOShelterStairs.java',*surface.JAVA]))
PRODUCTION=list(dict.fromkeys([JAVA[0],ROOT/'java/src/com/sao/engine/SAOShelterConstruction.java',*surface.PRODUCTION]))
INSTRUMENTS=[Path(__file__),Path(surface.__file__),CASES,base.PROBE,base.CASES,base.CTL_CASES,surface.CASES,ROOT/'tools/d3_shelter_construction_test.py',ROOT/'tools/d3_bed_construction_test.py',ROOT/'tools/check.sh']

def execute(out,chunks,classes,cp,expected):
    out.mkdir();shutil.copy2(base.GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
    for name,source in chunks.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    command=[str(base.JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',classes+os.pathsep+cp,'ShelterConstructionNativeProbe',str(base.GAME),'--surface-runtime',*paths]
    result=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=120)
    log=out/'output.log';log.write_text(result.stdout+result.stderr,encoding='utf-8')
    pairs=re.findall(r'^([a-zA-Z0-9_]+)=(true|false)$',result.stdout,re.M);checks=dict(pairs)
    complete=result.returncode==0 and set(checks)==expected and len(pairs)==len(checks)
    return {'status':'PASS' if complete and all(v=='true' for v in checks.values()) else 'FAIL','nativeExit':result.returncode,'checks':checks,
        'expectedChecks':sorted(expected),'complete':complete,'command':command,'log':str(log.relative_to(ROOT)),'logSha256':base.digest(log)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',required=True,type=Path)
    parser.add_argument('--case',choices=('all','first','chain','guards','control','saturated'),default='all')
    parser.add_argument('--no-controls',action='store_true');parser.add_argument('--required',action='store_true')
    args=parser.parse_args();out=args.out.resolve();classes=out/'classes'
    cp=os.pathsep.join([str(base.GAME/'projectzomboid.jar'),str(ROOT/'mod/42.20/media/java/SAO.jar'),str(base.GAME/'ZombieBuddy.jar')])
    sources=[base.PROBE,ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/LuaSyntax.java',*JAVA]
    inputs=list(dict.fromkeys([*INSTRUMENTS,*PRODUCTION,surface.LOCO,Path(base.__file__),Path(surface.__file__),base.CTL_CASES,base.BASE,base.BOARD,base.PLUMB,
        *base.LEAVES.values(),*base.NATIVE,*base.SCRIPTS,*JAVA,*sources,base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar',base.GAME/'stdlib.lua',
        *[base.GAME/f'media/scripts/generated/entities/walls/entity_wood_floorlvl{n}.txt' for n in (1,2,3)],base.GAME/'media/scripts/generated/entities/stairs/entity_carpentry_stairs.txt',ROOT/'tools/native_proof_preflight.py']))
    owned=[p for p in inputs if p.is_relative_to(ROOT)]
    installed=[p for p in inputs if not p.is_relative_to(ROOT)]+[base.JDK/'java.exe',base.JDK/'javac.exe']
    readiness=presence(owned,installed,args.required,'shelter stairs')
    if readiness is not None:return readiness
    out.mkdir(parents=True);classes.mkdir();before={str(p):base.digest(p) for p in inputs}
    compiled=subprocess.run([str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),*[str(p) for p in sources]],text=True,capture_output=True,timeout=60)
    (out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    receipt={'status':'FAIL','compileExit':compiled.returncode,'case':args.case,'controls':{}}
    if compiled.returncode:
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(compiled.stderr);return 1
    syntax=subprocess.run([str(base.JDK/'java.exe'),'-cp',str(classes)+os.pathsep+cp,'LuaSyntax',str(CASES),str(base.CONTROLLER),*[str(p) for p in base.LEAVES.values()]],text=True,capture_output=True,timeout=60)
    (out/'syntax.log').write_text(syntax.stdout+syntax.stderr,encoding='utf-8');receipt['syntaxExit']=syntax.returncode
    chunks={'stairs-enable.lua':'__surfaceCases=true;__stairCases=true'};chunks.update(base.sources())
    chunks['controller.lua']=chunks['controller.lua'].replace('local Ctl=SAO.Controller','local Ctl=SAO.Controller\nlocal tickCount=0',1).replace('\nlocal tickCount=0\nfunction __shelterControllerTick','\nfunction __shelterControllerTick',1)
    chunks['controller-cases.lua']+='\n__shelterControllerSetup=setup;__shelterControllerMaterials=materials'
    chunks['surface-cases.lua']=surface.CASES.read_text(encoding='utf-8-sig')
    chunks['stairs-cases.lua']=CASES.read_text(encoding='utf-8-sig')
    calls={'first':"__runShelterStairsFirst('S');__runShelterStairsFirst('W')",'chain':'__runShelterStairsChain()','guards':'__runShelterStairsGuards()','control':'__runShelterStairsCapacity()','saturated':'__runShelterStairsSaturation()'}
    chunks['run.lua']=';'.join(calls.values()) if args.case=='all' else calls[args.case]
    case=CASES.read_text(encoding='utf-8-sig');expected=set()
    if args.case in ('all','first'):expected.update(name+'_'+face for name in re.findall(r"check\('([a-z0-9_]+)'",case.split('function __runShelterStairsFirst(face)',1)[1].split('function __runShelterStairsChain()',1)[0]) for face in ('S','W'))
    if args.case in ('all','chain'):
        expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterStairsChain()',1)[1].split('function __runShelterStairsGuards()',1)[0]))
        expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",surface.CASES.read_text(encoding='utf-8-sig').split('function __runShelterSurfaceUpper(',1)[1].split('local function focusedFixture(',1)[0]))
    if args.case in ('all','guards'):expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterStairsGuards()',1)[1].split('function __runShelterStairsCapacity()',1)[0]))
    if args.case in ('all','control'):expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterStairsCapacity()',1)[1].split('function __runShelterStairsSaturation()',1)[0]))
    if args.case in ('all','saturated'):expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterStairsSaturation()',1)[1]))
    normal=execute(out/'normal',chunks,str(classes),cp,expected);receipt.update(normal)
    if not args.no_controls and normal['status']=='PASS':
        controls=out/'controls';controls.mkdir();target='native_stair_capacity_preserves_all_twenty_two_inputs'
        controlChunks=dict(chunks);controlChunks['run.lua']=calls['control']
        mutations=[('planner-cap','planner.lua','#option.inputs > 32','#option.inputs > 16'),
            ('acquisition-cap','production.lua','rows[#rows+1]={inputIndex=requirement.inputIndex','if #rows>=16 then return rows end\n                rows[#rows+1]={inputIndex=requirement.inputIndex')]
        for name,leaf,old,new in mutations:
            altered=dict(controlChunks);altered[leaf]=surface.replace_once(chunks[leaf],old,new)
            control=execute(controls/name,altered,str(classes),cp,{target})
            control.update(status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED',target=target,mutationScope=name,
                mutationSha256=base.digest(controls/name/leaf))
            (controls/name/'receipt.json').write_text(json.dumps(control,indent=2)+'\n');receipt['controls'][name]=control
        guardsExpected=set(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterStairsGuards()',1)[1].split('function __runShelterStairsCapacity()',1)[0]))
        for name,target,old,new in [
            ('claim-standing','denied_middle_footprint_cannot_start_native_payment',' or not shelter.permission(id,step.site,true) then return false end',' then return false end'),
            ('revoked-standing','revoked_middle_footprint_refuses_before_native_effect','if not shelter.permission(rt.id,rt.site,true) then return false end','-- removed current whole-footprint Standing')]:
            altered=dict(chunks);altered['run.lua']=calls['guards'];altered['production.lua']=surface.replace_once(chunks['production.lua'],old,new)
            control=execute(controls/name,altered,str(classes),cp,guardsExpected)
            control.update(status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED',target=target,mutationScope=name,
                mutationSha256=base.digest(controls/name/'production.lua'))
            (controls/name/'receipt.json').write_text(json.dumps(control,indent=2)+'\n');receipt['controls'][name]=control
        target='new_stairs_cover_return_and_recovery_finish_same_retained_purpose';name='visible-interior-retirement'
        native=controls/name;native.mkdir();javaInput=native/'input/SAOShelterConstruction.java';javaInput.parent.mkdir()
        original=(ROOT/'java/src/com/sao/engine/SAOShelterConstruction.java').read_text(encoding='utf-8-sig')
        begin=original.index('        // A newly covered, visibly continuous interior retires its exact former cover boundary.')
        end=original.index('        while(sites.size()>128)',begin)
        javaInput.write_text(original[:begin]+original[end:],encoding='utf-8');nativeClasses=native/'classes';nativeClasses.mkdir()
        built=subprocess.run([str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,'-d',str(nativeClasses),str(javaInput)],text=True,capture_output=True,timeout=60)
        (native/'compile.log').write_text(built.stdout+built.stderr)
        chainExpected=set(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterStairsChain()',1)[1].split('function __runShelterStairsGuards()',1)[0]))
        chainExpected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",surface.CASES.read_text(encoding='utf-8-sig').split('function __runShelterSurfaceUpper(',1)[1].split('local function focusedFixture(',1)[0]))
        if built.returncode==0:
            altered=dict(chunks);altered['run.lua']=calls['chain']
            control=execute(native/'vm',altered,str(nativeClasses)+os.pathsep+str(classes),cp,chainExpected)
            control.update(status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED',target=target,
                mutationScope='Restore absence-only old edge retention despite exact visible interior cover.',mutationSha256=base.digest(javaInput))
        else:control={'status':'CONTROL_COMPILE_FAIL','compileExit':built.returncode}
        (native/'receipt.json').write_text(json.dumps(control,indent=2)+'\n');receipt['controls'][name]=control
        name='saved-movement-feedback';target='ordinary_saved_reconciliation_retries_movement_feedback_once'
        altered=dict(chunks);altered['run.lua']=calls['chain']
        old='if SAO.ProceduralPlanning and SAO.ProceduralPlanning.reconcileShelterFeedback then SAO.ProceduralPlanning.reconcileShelterFeedback(id) end'
        altered['production.lua']=surface.replace_once(chunks['production.lua'],old,'-- removed ordinary saved movement-feedback retry')
        control=execute(controls/name,altered,str(classes),cp,chainExpected)
        control.update(status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED',target=target,
            mutationScope='Remove saved-work reconciliation of retained pending native movement feedback.',mutationSha256=base.digest(controls/name/'production.lua'))
        (controls/name/'receipt.json').write_text(json.dumps(control,indent=2)+'\n');receipt['controls'][name]=control
        name='movement-arrival-feedback-gate';target='saturated_pending_feedback_never_gates_actual_native_arrival'
        altered=dict(chunks);altered['run.lua']=calls['saturated']
        old='    P.reconcileShelterFeedback(id)\n    p.lastAdmission=dataCopy(ad);p.admission=nil;p.status="maintained";step.status=arrived and "completed" or "available"'
        new='    P.reconcileShelterFeedback(id)\n    if arrived and #(s.shelterMovementResults or {})>=32 and not s.shelterMovementResults[1].experienceDelivered then return false end\n    p.lastAdmission=dataCopy(ad);p.admission=nil;p.status="maintained";step.status=arrived and "completed" or "available"'
        altered['planner.lua']=surface.replace_once(chunks['planner.lua'],old,new)
        saturatedExpected=set(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterStairsSaturation()',1)[1]))
        control=execute(controls/name,altered,str(classes),cp,saturatedExpected)
        control.update(status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED',target=target,
            mutationScope='Restore the saturated pending-feedback gate at genuine native arrival.',mutationSha256=base.digest(controls/name/'planner.lua'))
        (controls/name/'receipt.json').write_text(json.dumps(control,indent=2)+'\n');receipt['controls'][name]=control
    after={str(p):base.digest(p) for p in inputs};classPins={str(p.relative_to(classes)):base.digest(p) for p in classes.rglob('*.class')}
    receipt.update(inputsBefore=before,inputsAfter=after,sourcePreserved=before==after,compiledClassPins=classPins,
        productionInventory=[str(p.relative_to(ROOT)) for p in PRODUCTION],instrumentInventory=[str(p.relative_to(ROOT)) for p in INSTRUMENTS],
        scope='Installed full S/W stair recipes, exact22 native manual payment, installed validity and creation/landing callbacks, private lower footprint/Standing and original shelter chain through actual native stairs motion, cover, doorway/enclosure and measured recovery; plain native Kahlua save and independent private feedback.',
        boundary='Controlled unattached native actor/private Lua actor proxy, exact item/source lookup, SourceUse transfer/outcome ports and timed-action dispatch, finite route nodes/stride/animation and recovery pose. Native script dimensions, skill/payment/factory, upper clearance callback, multipart geometry/landing, body collision/stair gravity, cover/region and SleepingEvent physiology execute installed production. Upper landing coordinates are intended recipe effects until actual travel/observation. Existing scene room/geometry is initial state; no acquired upper geometry, new home or claim is fabricated.')
    passed=normal['status']=='PASS' and syntax.returncode==0 and before==after and (args.no_controls or len(receipt['controls'])==7 and all(c['status']=='DETECTED' for c in receipt['controls'].values()))
    receipt['status']='PASS' if passed else 'FAIL';(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(receipt['status']+' shelter stairs '+str(out/'receipt.json'))
    if not passed:print((out/'normal/output.log').read_text(encoding='utf-8')[-6500:])
    return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
