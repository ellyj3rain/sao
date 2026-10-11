#!/usr/bin/env python3
"""Native wooden/metal floors, private prerequisites, cover and reached shelter recovery."""
from __future__ import annotations
import argparse,json,os,re,shutil,subprocess
from pathlib import Path
import d3_shelter_construction_test as base
from native_proof_preflight import presence

ROOT=base.ROOT
CASES=ROOT/'tools/resource_production_checks/shelter_surface_cases.lua'
METAL_PROBE=ROOT/'tools/resource_production_checks/MetalShelterNativeProbe.java'
STUDY=base.LUA/'client/SAO_Study.lua'
SOURCE_USE=base.LUA/'client/SAO_SourceUse.lua'
READER=ROOT/'tools/resource_production_checks/recipe_reading_cases.lua'
FLUID_HELPER=ROOT/'tools/luacheck/ResourceApproachProbe.java'
LOCO=base.LUA/'client/SAO_Locomotion.lua'
JAVA=[ROOT/'java/src/com/sao/engine'/name for name in ['SAODoubleGate.java','SAOShelterStairs.java','SAOShelterSurface.java','SAOShelterConstruction.java','SAONeeds.java','SAOWorldSources.java','SAOIsoPlayerShell.java']]+[ROOT/'java/src/com/sao/bridge/SAOBridge.java']
PRODUCTION=[ROOT/'java/src/com/sao/engine/SAODoubleGate.java',ROOT/'java/src/com/sao/engine/SAOShelterSurface.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java',*[base.LUA/f'{area}/SAO_{name}.lua' for area,name in [('shared','Perception'),('shared','ProceduralPlanning'),('shared','Cognition'),('shared','CognitiveModels'),('client','Controller'),('client','ResourceProduction'),('client','CapabilityExperience')]]]
INSTRUMENTS=[Path(__file__),CASES,base.PROBE,METAL_PROBE,base.CASES,ROOT/'tools/check.sh']

def replace_once(source,old,new):
    if source.count(old)!=1:raise ValueError('control anchor count: '+str(source.count(old)))
    return source.replace(old,new,1)

def execute(out,chunks,classes,cp,run):
    out.mkdir();shutil.copy2(base.GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
    for name,source in chunks.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    command=[str(base.JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',classes+os.pathsep+cp,('MetalShelterNativeProbe' if run.startswith('metal') else 'ShelterConstructionNativeProbe'),str(base.GAME),'--surface-runtime',*paths]
    result=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=90)
    log=out/'output.log';log.write_text(result.stdout+result.stderr,encoding='utf-8')
    pairs=re.findall(r'^([a-zA-Z0-9_]+)=(true|false)$',result.stdout,re.M)
    checks=dict(pairs);case=CASES.read_text(encoding='utf-8-sig');expected=set()
    if run in ('metal-first','metal-all'):expected.update(name+'_grademetal' for name in re.findall(r"floorCheck\('([a-z0-9_]+)'",case))
    if run in ('all','first'):expected.update(name+'_grade'+str(grade) for name in re.findall(r"floorCheck\('([a-z0-9_]+)'",case) for grade in (1,2,3))
    if run in ('all','upper','metal-upper','metal-all'):expected.update(re.findall(r"(?:__shelterCheck|upperCheck|mixedCheck)\('([a-z0-9_]+)',",case.split('function __runShelterSurfaceUpper(',1)[1].split('local function focusedFixture(',1)[0]))
    if run in ('all','focused'):expected.update(re.findall(r"(?:__shelterCheck|upperCheck|mixedCheck)\('([a-z0-9_]+)',",case.split('function __runShelterSurfaceFocused()',1)[1].split('function __runMetalFloorUpper()',1)[0]))
    for mode,name in [('metal-knowledge','Knowledge'),('metal-guards','Guards'),('metal-lifecycle','Lifecycle'),('metal-acquisition','Acquisition'),('metal-repeat','Repeat'),('metal-capacity','Capacity'),('metal-mixed','Mixed')]:
        if run==mode or run=="metal-all":
            section=case.split('function __runMetalFloor'+name+'(',1)[1].split(')',1)[1]
            next_function=re.search(r'\n(?:local )?function [A-Za-z_][A-Za-z0-9_.]*\(',section)
            if next_function:section=section[:next_function.start()]
            expected.update(re.findall(r"(?:__shelterCheck|upperCheck|mixedCheck)\('([a-z0-9_]+)',",section))
            if mode=='metal-repeat':
                expected.update('floor_repeat_'+level+'_'+name for level in ('ground','upper') for name in re.findall(r"repeatCheck\('([a-z0-9_]+)'",section))
                upper=case.split('function __runShelterSurfaceUpper(',1)[1].split('if f.stopAfterFloor',1)[0]
                expected.update('floor_repeat_upper_'+name for name in re.findall(r"(?:__shelterCheck|upperCheck|mixedCheck)\('([a-z0-9_]+)',",upper))
            if mode=='metal-acquisition':expected.update({('floor_'+prefix+'_'+name) for prefix in ('manual','sheet') for name in re.findall(r"sourceCheck\('([a-z0-9_]+)'",section) if prefix=='manual' or name!='actual_acquired_magazine_teaches_original_floor_recipe'})
    complete=result.returncode==0 and set(checks)==expected and len(pairs)==len(checks)
    return {'command':command,'processComplete':'SURFACE COMPLETE' in result.stdout,'status':'PASS' if complete and all(v=='true' for v in checks.values()) else 'FAIL','nativeExit':result.returncode,'checks':checks,'expectedChecks':sorted(expected),'complete':complete,'log':str(log.relative_to(ROOT)),'logSha256':base.digest(log)}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',required=True,type=Path)
    parser.add_argument('--case',choices=('all','first','upper','focused','metal-first','metal-upper','metal-knowledge','metal-guards','metal-lifecycle','metal-acquisition','metal-repeat','metal-capacity','metal-mixed','metal-all'),default='all')
    parser.add_argument('--no-controls',action='store_true',help='Run selected positive/guard methods only.')
    parser.add_argument('--control',help='One focused metal-floor detecting mutation.');parser.add_argument('--required',action='store_true',help='Require the installed native runtime.')
    args=parser.parse_args();out=args.out.resolve();classes=out/'classes'
    cp=os.pathsep.join([str(base.GAME/'projectzomboid.jar'),str(ROOT/'mod/42.20/media/java/SAO.jar'),str(base.GAME/'ZombieBuddy.jar')])
    sources=[base.PROBE,METAL_PROBE,FLUID_HELPER,ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/LuaSyntax.java',*JAVA]
    inputs=list(dict.fromkeys([*INSTRUMENTS,*PRODUCTION,STUDY,SOURCE_USE,READER,LOCO,Path(base.__file__),base.CTL_CASES,base.BASE,base.BOARD,base.PLUMB,*base.LEAVES.values(),*base.NATIVE,*base.SCRIPTS,*JAVA,*sources,base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar',base.GAME/'stdlib.lua',*[base.GAME/f'media/scripts/generated/entities/walls/entity_wood_floorlvl{n}.txt' for n in (1,2,3)],base.GAME/'media/scripts/generated/entities/stairs/entity_carpentry_stairs.txt']))
    inputs.append(ROOT/'tools/native_proof_preflight.py')
    owned=[*INSTRUMENTS,*PRODUCTION,STUDY,SOURCE_USE,READER,LOCO,Path(base.__file__),base.CTL_CASES,base.BASE,base.BOARD,base.PLUMB,*base.LEAVES.values(),*JAVA,*sources,ROOT/'mod/42.20/media/java/SAO.jar',ROOT/'tools/native_proof_preflight.py']
    installed=[*base.NATIVE,*base.SCRIPTS,*[base.GAME/p for p in ['media/scripts/generated/entities/walls/entity_metal_floorlvl1.txt','media/scripts/generated/items/drainable.txt','media/scripts/generated/items/literature.txt','media/lua/shared/TimedActions/ISReadABook.lua',*[f'media/scripts/generated/entities/walls/{x}.txt' for x in ['entity_metal_wallframe','entity_metal_walllvl1','entity_metal_walllvl2','entity_metal_doorframelvl1','entity_metal_doorframelvl2','entity_metal_doorlvl1','entity_metal_doorlvl2']]]],base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',base.GAME/'stdlib.lua',*[base.GAME/f'media/scripts/generated/entities/walls/entity_wood_floorlvl{n}.txt' for n in (1,2,3)],base.GAME/'media/scripts/generated/entities/stairs/entity_carpentry_stairs.txt',base.JDK/'java.exe',base.JDK/'javac.exe']
    installed += [base.GAME/f'media/scripts/generated/{name}.txt' for name in ('fluids','fluids_Beverages','fluids_Alcoholic')]
    readiness=presence(owned,installed,args.required,'shelter surfaces')
    if readiness is not None:return readiness
    out.mkdir(parents=True);classes.mkdir()
    inputs=list(dict.fromkeys([*inputs,*owned,*installed]));before={str(p):base.digest(p) for p in inputs}
    compiled=subprocess.run([str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),*[str(p) for p in sources]],text=True,capture_output=True,timeout=60)
    (out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    receipt={'status':'FAIL','scope':'Current native floor grades and original-purpose upper-work/lower-use chain; four identified contract corrections qualified by focused causal controls.','compileExit':compiled.returncode,'case':args.case,'controls':{}}
    if compiled.returncode:
        receipt.update(inputsBefore=before,inputsAfter={str(p):base.digest(p) for p in inputs})
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(compiled.stderr);return 1
    syntax=subprocess.run([str(base.JDK/'java.exe'),'-cp',str(classes)+os.pathsep+cp,'LuaSyntax',str(CASES),str(base.CONTROLLER),str(STUDY),str(SOURCE_USE),*[str(p) for p in base.LEAVES.values()]],text=True,capture_output=True,timeout=60)
    (out/'syntax.log').write_text(syntax.stdout+syntax.stderr,encoding='utf-8');receipt['syntaxExit']=syntax.returncode
    chunks={'surface-enable.lua':'__surfaceCases=true\n__metalFloorCases='+('true' if args.case.startswith('metal') else 'false')};chunks.update(base.sources())
    if args.case.startswith('metal'):
        chunks['native-read.lua']=(base.GAME/'media/lua/shared/TimedActions/ISReadABook.lua').read_text(encoding='utf-8-sig')
        chunks['reading-ports.lua']=READER.read_text(encoding='utf-8-sig').split('local checks={}',1)[0]
        chunks['study.lua']=STUDY.read_text(encoding='utf-8-sig')
        chunks['source-use.lua']=SOURCE_USE.read_text(encoding='utf-8-sig')
        ctl=base.CONTROLLER.read_text(encoding='utf-8-sig')
        resource='function Ctl.resourceContext('+ctl.split('function Ctl.resourceContext(',1)[1].split('-- This read-only preflight',1)[0]
        chunks['controller.lua']+='\n'+resource
    chunks['controller.lua']=chunks['controller.lua'].replace('local Ctl=SAO.Controller','local Ctl=SAO.Controller\nlocal tickCount=0',1).replace('\nlocal tickCount=0\nfunction __shelterControllerTick','\nfunction __shelterControllerTick',1)
    chunks['controller-cases.lua']+='\n__shelterControllerSetup=setup;__shelterControllerMaterials=materials'
    cancel=LOCO.read_text(encoding='utf-8-sig').split('function Loco.cancel(id)',1)[1].split('function Loco.status(id)',1)[0]
    chunks['actual-loco-cancel.lua']='local Loco=SAO.Locomotion\nlocal function observed()end\nlocal function log()end\nfunction Loco.cancel(id)'+cancel+'\n__shelterActualCancel=Loco.cancel'
    chunks['surface-cases.lua']=CASES.read_text(encoding='utf-8-sig')
    calls={'first':'for grade=1,3 do __runShelterSurfaceFirst(grade) end','upper':'__runShelterSurfaceUpper()','focused':'__runShelterSurfaceFocused()','metal-first':"__runShelterSurfaceFirst('metal')",'metal-upper':'__runMetalFloorUpper()','metal-knowledge':'__runMetalFloorKnowledge()','metal-guards':'__runMetalFloorGuards()','metal-lifecycle':'__runMetalFloorLifecycle()','metal-acquisition':'__runMetalFloorAcquisition()','metal-repeat':'__runMetalFloorRepeat()','metal-capacity':'__runMetalFloorCapacity()','metal-mixed':'__runMetalFloorMixed()'}
    calls['metal-all']=';'.join(calls[k] for k in ('metal-first','metal-upper','metal-knowledge','metal-guards','metal-lifecycle','metal-acquisition','metal-repeat','metal-capacity','metal-mixed'))
    chunks['run.lua']=';'.join(calls[k] for k in ('first','upper','focused')) if args.case=='all' else calls[args.case]
    chunks['run.lua']+=';print("SURFACE COMPLETE")'
    normal=execute(out/'normal',chunks,str(classes),cp,args.case);receipt.update(normal)
    if not args.no_controls and normal['status']=='PASS' and not args.case.startswith('metal'):
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
        surface=(ROOT/'java/src/com/sao/engine/SAOShelterSurface.java').read_text(encoding='utf-8-sig')
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

    if not args.no_controls and normal['status']=='PASS' and args.case.startswith('metal'):
        definitions=[
          ('ordinary-pending-feedback-writer','production.lua','if not craftLedgerRoom(rec) then','if false then','mixed_water_preserves_pending_floor_and_claim_at_capacity','metal-mixed','finish'),

          ('retained-surface-revision','planner.lua',' or option.kind=="build-shelter-surface" and own.stageHistory[site.key].revision~=site.revision','','floor_repeat_ground_saved_retained_purpose_admits_fresh_exact_floor_work','metal-repeat',None),
          ('upper-surface-revision','production.lua',' and retained.stageHistory[site.key] and retained.stageHistory[site.key].revision==site.revision','','floor_repeat_upper_saved_retained_purpose_admits_fresh_exact_floor_work','metal-repeat',None),
          ('pending-feedback-ledger','production.lua',' and oldest.experienceDelivered==true','','floor_capacity_paid_ack_preserves_pending_oldest_and_live_claim','metal-capacity',None),
          ('saved-floor-orientation','production.lua','or kind=="floor" and w.face~="W"','or false','floor_saved_native_north_face_cannot_authenticate_w_only_family','metal-guards',None),

          ('floor-policy','production.lua','counts={1,1,1},materials={"welding-torch","small-sheet-metal","welding-rods"}','counts={1,2,1},materials={"welding-torch","small-sheet-metal","welding-rods"}','floor_exact_native_one_charge_policy_is_available_without_skill_gate','metal-guards',None),
          ('actual-knowledge','production.lua','body:isRecipeActuallyKnown(recipe:getName())==true','CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body)==true','floor_actual_unknown_visible_recipe_selects_exact_native_reader','metal-knowledge',None),
          ('native-reader-floor','study.lua',',MetalFloorLvl1=true','', 'floor_actual_unknown_visible_recipe_selects_exact_native_reader','metal-knowledge',None),
          ('consumed-surface','planner.lua','if SAO.Perception and SAO.Perception.consumeShelterSurface then SAO.Perception.consumeShelterSurface(id,canonical) end','-- omitted exact authenticated surface retirement','floor_healthy_existing_native_surface_is_not_reoffered','metal-guards',None),
          ('charge-measurement','production.lua','after~=before-row.quantity','after~=before-row.quantity+1','floor_measured_native_payment_spends_one_charge_and_exact_sheet','metal-guards',None),
          ('saved-record-flag','production.lua',' or req.recordInput~=(not weld and w.entityId=="Base.DoubleWireGate" and i==3)','','floor_changed_saved_dontrecordinput_cannot_authenticate_result','metal-guards',None),
          ('current-standing','production.lua','local query=current and SAO.Standing.mayTakeCurrent or SAO.Standing.mayAttemptBelieved','if current then return true end\n    local query=current and SAO.Standing.mayTakeCurrent or SAO.Standing.mayAttemptBelieved','floor_current_standing_revocation_prevents_native_payment','metal-guards','shelter.permission'),
          ('floor-feedback','models.lua',',["Base.MetalFloorLvl1"]=true','','floor_saved_private_feedback_delivers_actual_build_once','metal-lifecycle',None),
        ]
        for name,file,old,new,target,run,scope in definitions:
            if args.control and args.control!=name:continue
            original=chunks[file]
            if scope:
                head,body=original.split('function '+scope+'(',1);match=re.search(r'\n(?:local )?function [A-Za-z_][A-Za-z0-9_.:]*\(',body);at=match.start() if match else len(body)
                mutant=head+'function '+scope+'('+replace_once(body[:at],old,new)+body[at:]
            elif name=='floor-feedback':
                if original.count(old)!=2:raise ValueError('two model whitelists required')
                at=original.rfind(old);mutant=original[:at]+original[at:].replace(old,new,1)
            else:mutant=replace_once(original,old,new)
            variant=dict(chunks);variant[file]=mutant;variant['run.lua']=calls[run]+';print("SURFACE COMPLETE")'
            control=execute(out/('control-'+name),variant,str(classes),cp,run)
            # A selected unavailable prerequisite has one deliberate negative branch.
            reached={'mixed_actual_floor_and_31_native_cancellations_fill_ledger','mixed_native_refill_measures_water_and_holds_exact_ack',target} if name=='ordinary-pending-feedback-writer' else {target} if name in ('floor-policy','actual-knowledge') else {target,'floor_native_magazine_admission_retains_same_purpose_and_item'} if name=='native-reader-floor' else set(control['expectedChecks'])
            branchComplete=control['nativeExit']==0 and control['processComplete'] and set(control['checks'])==reached
            control.update(name=name,target=target,positiveContractComplete=control['complete'],complete=branchComplete,
                landed=original!=mutant,sourcePreimageSha256=__import__('hashlib').sha256(original.encode()).hexdigest(),sourceMutantSha256=__import__('hashlib').sha256(mutant.encode()).hexdigest(),
                reachedNegativeBranchExpectedChecks=sorted(reached),status='DETECTED' if branchComplete and control['checks'].get(target)=='false' else 'NOT_DETECTED')
            receipt['controls'][name]=control;print('CONTROL '+name+' '+control['status'],flush=True)
        for nativeName in ('native-floor-credit','native-cache-revision'):
            if args.control and args.control!=nativeName:continue
            directory=out/('control-'+nativeName);directory.mkdir();source=ROOT/'java/src/com/sao/engine/SAOShelterSurface.java';original=source.read_text(encoding='utf-8-sig');mutant=replace_once(original,',"Base.MetalFloorLvl1"','')
            if nativeName=='native-cache-revision':mutant=replace_once(original,'if(measured){var sites=SITES.get(body);','if(false){var sites=SITES.get(body);')
            javaInput=directory/'SAOShelterSurface.java';javaInput.write_text(mutant,encoding='utf-8');shadow=directory/'classes';shadow.mkdir()
            command=[str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,'-d',str(shadow),str(javaInput)]
            built=subprocess.run(command,text=True,capture_output=True,timeout=60);(directory/'compile.log').write_text(built.stdout+built.stderr,encoding='utf-8')
            variant=dict(chunks);variant['run.lua']=calls['metal-guards']+';print("SURFACE COMPLETE")'
            control=execute(directory/'vm',variant,str(shadow)+os.pathsep+str(classes),cp,'metal-guards') if built.returncode==0 else {'nativeExit':-1,'complete':False,'checks':{}}
            target='floor_genuine_fresh_visible_gap_reenters_without_consumed_tombstone' if nativeName=='native-cache-revision' else 'floor_real_native_part_credit_matches_created_floor';control.update(name=nativeName,target=target,landed=original!=mutant,compileExit=built.returncode,compileCommand=command,sourcePreimageSha256=base.digest(source),sourceMutantSha256=base.digest(javaInput),status='DETECTED' if control['complete'] and control['checks'].get(target)=='false' else 'NOT_DETECTED')
            receipt['controls'][nativeName]=control;print('CONTROL '+nativeName+' '+control['status'],flush=True)
    receipt['compileCommand']=[str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),*[str(p) for p in sources]]
    receipt['compiledClassPins']={p.relative_to(classes).as_posix():base.digest(p) for p in classes.rglob('*.class')}
    receipt['javaShadowSourcePins']={p.relative_to(ROOT).as_posix():base.digest(p) for p in JAVA}
    after={str(p):base.digest(p) for p in inputs};receipt.update(inputsBefore=before,inputsAfter=after,sourcePreserved=before==after,
        productionInventory=[str(p.relative_to(ROOT)) for p in PRODUCTION],instrumentInventory=[str(p.relative_to(ROOT)) for p in INSTRUMENTS],
        boundary='Installed recipes, manual native payment/factory, floor validity/callback and roof propagation, actual native stair/door physics, native DataRoot enclosure/fullroof, actual RecoveryPlace and measured SleepingEvent fatigue. Initial existing room/map, actor/material/source/county clock/action dispatch, finite supported route nodes, animation/stride and recovery pose are controlled ports. The room is initial existing scene state; no newly native-published room, home/claim or weather improvement is credited. Focused cap pressure repeats a previously native-observed lower edge; it manufactures no world surface or arrival.')
    passed=normal['status']=='PASS' and syntax.returncode==0 and before==after and (args.no_controls or bool(receipt['controls']) and all(c['status']=='DETECTED' for c in receipt['controls'].values()))
    receipt['status']='PASS' if passed else 'FAIL';(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    print(receipt['status']+' shelter surfaces '+str(out/'receipt.json'))
    if not passed:print((out/'normal/output.log').read_text(encoding='utf-8')[-4500:])
    return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
