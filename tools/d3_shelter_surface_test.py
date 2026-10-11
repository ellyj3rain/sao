#!/usr/bin/env python3
"""Bounded native wooden floors, cover, original-purpose return and usable shelter."""
from __future__ import annotations
import argparse,json,os,re,shutil,subprocess
from pathlib import Path
import d3_shelter_construction_test as base
from native_proof_preflight import presence

ROOT=base.ROOT
CASES=ROOT/'tools/resource_production_checks/shelter_surface_cases.lua'
LOCO=base.LUA/'client/SAO_Locomotion.lua'
JAVA=[ROOT/'java/src/com/sao/engine'/name for name in ['SAOShelterSurface.java','SAOShelterConstruction.java','SAONeeds.java','SAOWorldSources.java','SAOIsoPlayerShell.java']]+[ROOT/'java/src/com/sao/bridge/SAOBridge.java']
PRODUCTION=[ROOT/'java/src/com/sao/engine/SAOShelterSurface.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java',*[base.LUA/f'{area}/SAO_{name}.lua' for area,name in [('shared','Perception'),('shared','ProceduralPlanning'),('shared','Cognition'),('shared','CognitiveModels'),('client','Controller'),('client','ResourceProduction'),('client','CapabilityExperience')]]]
INSTRUMENTS=[Path(__file__),CASES,base.PROBE,base.CASES,ROOT/'tools/check.sh']

def replace_once(source,old,new):
    if source.count(old)!=1:raise ValueError('control anchor count: '+str(source.count(old)))
    return source.replace(old,new,1)

def execute(out,chunks,classes,cp,run):
    out.mkdir();shutil.copy2(base.GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
    for name,source in chunks.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    command=[str(base.JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',classes+os.pathsep+cp,'ShelterConstructionNativeProbe',str(base.GAME),'--surface-runtime',*paths]
    result=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=90)
    log=out/'output.log';log.write_text(result.stdout+result.stderr,encoding='utf-8')
    pairs=re.findall(r'^([a-zA-Z0-9_]+)=(true|false)$',result.stdout,re.M)
    checks=dict(pairs);case=CASES.read_text(encoding='utf-8-sig');expected=set()
    if run in ('all','first'):expected.update(name+'_grade'+str(grade) for name in re.findall(r"floorCheck\('([a-z0-9_]+)'",case) for grade in (1,2,3))
    if run in ('all','upper'):expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterSurfaceUpper()',1)[1].split('local function focusedFixture(',1)[0]))
    if run in ('all','focused'):expected.update(re.findall(r"__shelterCheck\('([a-z0-9_]+)'",case.split('function __runShelterSurfaceFocused()',1)[1]))
    complete=result.returncode==0 and set(checks)==expected and len(pairs)==len(checks)
    return {'status':'PASS' if complete and all(v=='true' for v in checks.values()) else 'FAIL','nativeExit':result.returncode,'checks':checks,'expectedChecks':sorted(expected),'complete':complete,'log':str(log.relative_to(ROOT)),'logSha256':base.digest(log)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',required=True,type=Path)
    parser.add_argument('--case',choices=('all','first','upper','focused'),default='all')
    parser.add_argument('--no-controls',action='store_true',help='Run selected positive/guard methods only.')
    parser.add_argument('--required',action='store_true',help='Require the installed native runtime.')
    args=parser.parse_args();out=args.out.resolve();classes=out/'classes'
    cp=os.pathsep.join([str(base.GAME/'projectzomboid.jar'),str(ROOT/'mod/42.20/media/java/SAO.jar'),str(base.GAME/'ZombieBuddy.jar')])
    sources=[base.PROBE,ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/LuaSyntax.java',*JAVA]
    inputs=list(dict.fromkeys([*INSTRUMENTS,*PRODUCTION,LOCO,Path(base.__file__),base.CTL_CASES,base.BASE,base.BOARD,base.PLUMB,*base.LEAVES.values(),*base.NATIVE,*base.SCRIPTS,*JAVA,*sources,base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar',base.GAME/'stdlib.lua',*[base.GAME/f'media/scripts/generated/entities/walls/entity_wood_floorlvl{n}.txt' for n in (1,2,3)],base.GAME/'media/scripts/generated/entities/stairs/entity_carpentry_stairs.txt']))
    inputs.append(ROOT/'tools/native_proof_preflight.py')
    owned=[*INSTRUMENTS,*PRODUCTION,LOCO,Path(base.__file__),base.CTL_CASES,base.BASE,base.BOARD,base.PLUMB,*base.LEAVES.values(),*JAVA,*sources,ROOT/'mod/42.20/media/java/SAO.jar',ROOT/'tools/native_proof_preflight.py']
    installed=[*base.NATIVE,*base.SCRIPTS,base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',base.GAME/'stdlib.lua',*[base.GAME/f'media/scripts/generated/entities/walls/entity_wood_floorlvl{n}.txt' for n in (1,2,3)],base.GAME/'media/scripts/generated/entities/stairs/entity_carpentry_stairs.txt',base.JDK/'java.exe',base.JDK/'javac.exe']
    readiness=presence(owned,installed,args.required,'shelter surfaces')
    if readiness is not None:return readiness
    out.mkdir(parents=True);classes.mkdir()
    before={str(p):base.digest(p) for p in inputs}
    compiled=subprocess.run([str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),*[str(p) for p in sources]],text=True,capture_output=True,timeout=60)
    (out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    receipt={'status':'FAIL','scope':'Current native floor grades and original-purpose upper-work/lower-use chain; four identified contract corrections qualified by focused causal controls.','compileExit':compiled.returncode,'case':args.case,'controls':{}}
    if compiled.returncode:
        receipt.update(inputsBefore=before,inputsAfter={str(p):base.digest(p) for p in inputs})
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(compiled.stderr);return 1
    syntax=subprocess.run([str(base.JDK/'java.exe'),'-cp',str(classes)+os.pathsep+cp,'LuaSyntax',str(CASES),str(base.CONTROLLER),*[str(p) for p in base.LEAVES.values()]],text=True,capture_output=True,timeout=60)
    (out/'syntax.log').write_text(syntax.stdout+syntax.stderr,encoding='utf-8');receipt['syntaxExit']=syntax.returncode
    chunks={'surface-enable.lua':'__surfaceCases=true'};chunks.update(base.sources())
    chunks['controller.lua']=chunks['controller.lua'].replace('local Ctl=SAO.Controller','local Ctl=SAO.Controller\nlocal tickCount=0',1).replace('\nlocal tickCount=0\nfunction __shelterControllerTick','\nfunction __shelterControllerTick',1)
    chunks['controller-cases.lua']+='\n__shelterControllerSetup=setup;__shelterControllerMaterials=materials'
    cancel=LOCO.read_text(encoding='utf-8-sig').split('function Loco.cancel(id)',1)[1].split('function Loco.status(id)',1)[0]
    chunks['actual-loco-cancel.lua']='local Loco=SAO.Locomotion\nlocal function observed()end\nlocal function log()end\nfunction Loco.cancel(id)'+cancel+'\n__shelterActualCancel=Loco.cancel'
    chunks['surface-cases.lua']=CASES.read_text(encoding='utf-8-sig')
    calls={'first':'for grade=1,3 do __runShelterSurfaceFirst(grade) end','upper':'__runShelterSurfaceUpper()','focused':'__runShelterSurfaceFocused()'}
    chunks['run.lua']=';'.join(calls.values()) if args.case=='all' else calls[args.case]
    normal=execute(out/'normal',chunks,str(classes),cp,args.case);receipt.update(normal)
    if not args.no_controls and normal['status']=='PASS':
        controls=out/'controls';controls.mkdir();changes=[]
        begin=chunks['production.lua'].index('local relevant=site.z==math.floor(body:getZ())')
        end=chunks['production.lua'].index('            if relevant and (not retained',begin)
        changes.append(('purpose-before-cap','needed_upper_surface_survives_more_than_32_stale_edge_alternatives',{'production.lua':chunks['production.lua'][:begin]+'local relevant=true\n'+chunks['production.lua'][end:]}))
        old='local unresolved={};for _,need in ipairs(b.shelterCoverNeeds or {}) do unresolved[need.x..":"..need.y..":"..need.z]=need end'
        perception=replace_once(chunks['perception.lua'],old,'local unresolved={}')
        planner=replace_once(chunks['planner.lua'],'for _,need in ipairs(own.coverNeeds or {}) do unresolved[need.x..":"..need.y..":"..need.z]=need end','-- restored old absence-as-resolution behavior')
        changes.append(('acquired-cover-reset','acquired_lower_cover_need_survives_unavailable_and_hidden_reads',{'perception.lua':perception,'planner.lua':planner}))
        begin=chunks['controller.lua'].index('    if not job.done then\n        local ok,cancelled=pcall(function()return SAOJavaBridge:cancelMove(body)end)')
        end=chunks['controller.lua'].index('    if not SAO.ProceduralPlanning.finishShelterMovement',begin)
        changes.append(('route-timeout-owner','shelter_access_deadline_preserves_owner_until_native_ack',{'controller.lua':chunks['controller.lua'][:begin]+'    if not job.done then SAO.Locomotion.cancel(id) end\n'+chunks['controller.lua'][end:]}))
        surface=JAVA[0].read_text(encoding='utf-8-sig')
        old='var region=eye.getIsoWorldRegion();return region instanceof zombie.iso.areas.isoregion.regions.IsoWorldRegion nativeRegion\n            &&nativeRegion.isEnclosed()&&square.getIsoWorldRegion()==region;'
        changed=replace_once(surface,old,'return false; // restored room-only intake')
        native=controls/'roomless-region';native.mkdir();javaInput=native/'input/SAOShelterSurface.java';javaInput.parent.mkdir();javaInput.write_text(changed,encoding='utf-8')
        nativeClasses=native/'classes';nativeClasses.mkdir()
        result=subprocess.run([str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,'-d',str(nativeClasses),str(javaInput)],capture_output=True,text=True,timeout=60)
        (native/'compile.log').write_text(result.stdout+result.stderr)
        if result.returncode==0:
            controlChunks=dict(chunks);controlChunks['run.lua']=calls['focused']
            control=execute(native/'vm',controlChunks,str(nativeClasses)+os.pathsep+str(classes),cp,'focused');target='actual_unroofed_enclosure_without_room_admits_roof_inquiry'
            control.update(status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED',target=target,mutationScope='Restore room-only native cover intake.',mutationSourceSha256=base.digest(javaInput))
        else:control={'status':'CONTROL_COMPILE_FAIL','compileExit':result.returncode}
        (native/'receipt.json').write_text(json.dumps(control,indent=2)+'\n');receipt['controls']['roomless-region']=control
        for name,target,overrides in changes:
            controlChunks=dict(chunks);controlChunks.update(overrides);controlChunks['run.lua']=calls['focused']
            control=execute(controls/name,controlChunks,str(classes),cp,'focused')
            control.update(status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED',target=target,mutationScope=name)
            (controls/name/'receipt.json').write_text(json.dumps(control,indent=2)+'\n');receipt['controls'][name]=control
    after={str(p):base.digest(p) for p in inputs};receipt.update(inputsBefore=before,inputsAfter=after,sourcePreserved=before==after,
        productionInventory=[str(p.relative_to(ROOT)) for p in PRODUCTION],instrumentInventory=[str(p.relative_to(ROOT)) for p in INSTRUMENTS],
        boundary='Installed recipes, manual native payment/factory, floor validity/callback and roof propagation, actual native stair/door physics, native DataRoot enclosure/fullroof, actual RecoveryPlace and measured SleepingEvent fatigue. Initial existing room/map, actor/material/source/county clock/action dispatch, finite supported route nodes, animation/stride and recovery pose are controlled ports. The room is initial existing scene state; no newly native-published room, home/claim or weather improvement is credited. Focused cap pressure repeats a previously native-observed lower edge; it manufactures no world surface or arrival.')
    passed=normal['status']=='PASS' and syntax.returncode==0 and before==after and (args.no_controls or len(receipt['controls'])==4 and all(c['status']=='DETECTED' for c in receipt['controls'].values()))
    receipt['status']='PASS' if passed else 'FAIL';(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(receipt['status']+' shelter surfaces '+str(out/'receipt.json'))
    if not passed:print((out/'normal/output.log').read_text(encoding='utf-8')[-4500:])
    return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
