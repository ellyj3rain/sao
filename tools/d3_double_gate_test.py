#!/usr/bin/env python3
"""Installed double-gate family through private construction, native opening/passage/closure."""
from __future__ import annotations
import argparse,hashlib,json,os,re,shutil,subprocess,sys
from pathlib import Path
try:
    from native_proof_preflight import presence,OWNED_GUARD
except ModuleNotFoundError:
    print('FAILED double gates owned proof inputs absent: '+str(Path(__file__).with_name('native_proof_preflight.py')))
    raise SystemExit(1)
import d3_shelter_construction_test as base
ROOT=base.ROOT
PROBE=ROOT/'tools/resource_production_checks/DoubleGateNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/double_gate_cases.lua'
JAVA=[ROOT/'java/src/com/sao/engine'/name for name in ['SAODoubleGate.java','SAOEnclosureEdge.java','SAOMovement.java','SAOShelterConstruction.java','SAOShelterStairs.java','SAOShelterSurface.java','SAONeeds.java','SAOWorldSources.java','SAOIsoPlayerShell.java']]+[ROOT/'java/src/com/sao/bridge/SAOBridge.java']
PRODUCTION=[*JAVA,*[base.LUA/f'{area}/SAO_{name}.lua' for area,name in [('shared','Perception'),('shared','ProceduralPlanning'),('shared','Cognition'),('shared','CognitiveModels'),('shared','WorldSources'),('client','Controller'),('client','ResourceProduction'),('client','CapabilityExperience')]]]
INSTRUMENTS=[Path(__file__),PROBE,CASES,base.PROBE,base.CASES,Path(base.__file__),ROOT/'tools/check.sh']
DEFINITIONS=[base.GAME/f'media/scripts/generated/entities/walls/{name}.txt' for name in ['entity_wood_doubledoor','entity_metal_doublepolegate','entity_metal_doublewiregate']]
def execute(out,chunks,classes,cp,expected):
    out.mkdir();shutil.copy2(base.GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
    for name,source in chunks.items():p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    command=[str(base.JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',str(classes)+os.pathsep+cp,'DoubleGateNativeProbe',str(base.GAME),*paths]
    done=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=120);log=out/'output.log';log.write_text(done.stdout+done.stderr,encoding='utf-8')
    pairs=re.findall(r'^([A-Za-z0-9_]+)=(true|false)$',done.stdout,re.M);checks=dict(pairs)
    complete=done.returncode==0 and set(checks)==expected and len(pairs)==len(checks)
    return {'status':'PASS' if complete and all(v=='true' for v in checks.values()) else 'FAIL','nativeExit':done.returncode,'complete':complete,'checks':checks,
        'expectedChecks':sorted(expected),'command':command,'log':str(log.relative_to(ROOT)),'logSha256':base.digest(log)}
def named_checks(case,name):
    section=case.split('function __runDoubleGate'+name+'(',1)[1]
    section=re.split(r'\n(?:function __runDoubleGate|local function (?:buildGuard|savedGate|acquisitionFixture))',section,maxsplit=1)[0]
    return set(re.findall(r"check\('([a-z0-9_]+)',",section))
def review_checks(case):
    section=case.split('function __runDoubleGateReviewPhases()',1)[1].split('function __runDoubleGateReviewSites()',1)[0]
    names=re.findall(r"phaseCheck\('([a-z0-9_]+)',",section)
    races=case.split('function __runDoubleGateReviewRace()',1)[1];raceNames=re.findall(r"raceCheck\('([a-z0-9_]+)',",races)
    return {name+'_'+family+'_'+face for name in [*names,*raceNames] for family in ['DoubleDoor','DoubleFenceGate','DoubleWireGate'] for face in ['N','W']} | named_checks(case,'ReviewSites')
def replace_contract(source,old,new,scope=None):
    if scope:
        head,section=source.split('function '+scope+'(',1)
        match=re.search(r'\nfunction [A-Za-z_][A-Za-z0-9_.]*\(',section)
        end=match.start() if match else len(section);body,tail=section[:end],section[end:]
        assert body.count(old)==1,(scope,old,body.count(old));return head+'function '+scope+'('+body.replace(old,new,1)+tail
    assert source.count(old)==1,(old,source.count(old));return source.replace(old,new,1)
def preflight_controls(folder,owned):
    folder.mkdir();fixture=folder/'owned';fixture.mkdir();helper=ROOT/'tools/native_proof_preflight.py'
    for source in owned:
        target=fixture/source.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(source.read_bytes() if source in (Path(__file__),Path(base.__file__),helper) else b'controlled owned presence fixture\n')
    environment=os.environ.copy();environment.update(PZ_DIR=str(fixture/'absent-engine'),JDK_BIN=str(fixture/'absent-jdk'),PYTHONDONTWRITEBYTECODE='1')
    def run(label,required=False):
        command=[sys.executable,'-B',str(fixture/Path(__file__).relative_to(ROOT)),'--out',str(fixture/'never-executed')]+(['--required'] if required else [])
        result=subprocess.run(command,cwd=fixture,env=environment,capture_output=True,text=True,timeout=15)
        log=folder/(label+'.log');log.write_text(result.stdout+result.stderr);return {'command':command,'exitCode':result.returncode,'log':str(log.relative_to(ROOT)),'logSha256':base.digest(log),'stdout':result.stdout}
    default,required=run('default'),run('required',True)
    absent=default['exitCode']==0 and 'SKIPPED' in default['stdout'] and required['exitCode']==1 and 'FAILED' in required['stdout']
    copiedProbe=fixture/PROBE.relative_to(ROOT);copiedProbe.unlink();missing=[run('missing-owned'),run('missing-owned-required',True)]
    own=all(r['exitCode']==1 and 'owned proof inputs absent' in r['stdout'] and str(copiedProbe) in r['stdout'] for r in missing)
    copiedHelper=fixture/helper.relative_to(ROOT);original=copiedHelper.read_text();mutant=replace_contract(original,OWNED_GUARD,'    if False:\n');copiedHelper.write_bytes(mutant.encode())
    preservedMutant=folder/'mutant-native_proof_preflight.py';preservedMutant.write_bytes(copiedHelper.read_bytes())
    omission=run('omit-owned-guard');detected=omission['exitCode']==0 and 'SKIPPED' in omission['stdout']
    copiedHelper.unlink();bootstrap=[run('missing-helper'),run('missing-helper-required',True)]
    boot=all(r['exitCode']==1 and 'owned proof inputs absent' in r['stdout'] and str(copiedHelper) in r['stdout'] for r in bootstrap)
    return {'status':'PASS' if absent and own and detected and boot else 'FAIL','boundary':'Actual runner/base/helper CLI; remaining inputs are presence fixtures and installed game/JDK are absent. No native execution.',
        'classificationCases':[default,required,*missing,*bootstrap],'ownedGuardOmission':{'detectedUnsafeSkip':detected,'originalSha256':base.digest(helper),'mutantSha256':base.digest(preservedMutant),'mutantPath':str(preservedMutant.relative_to(ROOT)),'run':omission}}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',required=True,type=Path);parser.add_argument('--required',action='store_true')
    parser.add_argument('--family',choices=('all','DoubleDoor','DoubleFenceGate','DoubleWireGate'),default='all');parser.add_argument('--face',choices=('all','N','W'),default='all')
    parser.add_argument('--no-controls',action='store_true',help='Current affected positives with separately retained detecting control evidence.');parser.add_argument('--control',help='Select one previously incomplete detecting control without repeating unrelated controls.');parser.add_argument('--pool-only',action='store_true');parser.add_argument('--knowledge-only',action='store_true');parser.add_argument('--guards-only',action='store_true');parser.add_argument('--lifecycle-only',action='store_true');parser.add_argument('--acquisition-only',action='store_true');parser.add_argument('--review-corrections-only',action='store_true',help='Current external-toggle and consumed-site contracts; reuse unchanged native recipe/payment/group proofs.');args=parser.parse_args();out=args.out.resolve();classes=out/'classes'
    sources=[PROBE,base.PROBE,ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/LuaSyntax.java',*JAVA]
    inputs=list(dict.fromkeys([*PRODUCTION,*INSTRUMENTS,*sources,base.BASE,base.BOARD,base.PLUMB,base.CTL_CASES,*base.LEAVES.values(),*base.NATIVE,*base.SCRIPTS,*DEFINITIONS,
        ROOT/'tools/resource_production_checks/recipe_reading_cases.lua',base.LUA/'client/SAO_Study.lua',base.LUA/'client/SAO_SourceUse.lua',base.GAME/'media/lua/shared/TimedActions/ISReadABook.lua',base.GAME/'media/scripts/generated/items/drainable.txt',base.GAME/'media/scripts/generated/items/literature.txt',base.GAME/'projectzomboid.jar',base.GAME/'ZombieBuddy.jar',base.GAME/'stdlib.lua',ROOT/'mod/42.20/media/java/SAO.jar',ROOT/'tools/native_proof_preflight.py']))
    cp=os.pathsep.join([str(base.GAME/'projectzomboid.jar'),str(ROOT/'mod/42.20/media/java/SAO.jar'),str(base.GAME/'ZombieBuddy.jar')])
    owned=[p for p in inputs if p.is_relative_to(ROOT) and not p.is_relative_to(base.GAME) and not p.is_relative_to(base.JDK)]
    readiness=presence(owned,[p for p in inputs if p not in owned]+[base.JDK/'java.exe',base.JDK/'javac.exe'],args.required,'double gates')
    if readiness is not None:return readiness
    out.mkdir(parents=True);classes.mkdir();before={str(p):base.digest(p) for p in inputs}
    compiled=subprocess.run([str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',cp,'-d',str(classes),*[str(p) for p in sources]],text=True,capture_output=True,timeout=60)
    (out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8');receipt={'status':'FAIL','compileExit':compiled.returncode,'controls':{}}
    if compiled.returncode:print(compiled.stderr);(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');return 1
    syntax=subprocess.run([str(base.JDK/'java.exe'),'-cp',str(classes)+os.pathsep+cp,'LuaSyntax',str(CASES),*[str(p) for p in PRODUCTION if p.suffix=='.lua']],text=True,capture_output=True,timeout=60)
    (out/'syntax.log').write_text(syntax.stdout+syntax.stderr);receipt['syntaxExit']=syntax.returncode
    chunks=base.sources()
    ctl=base.CONTROLLER.read_text(encoding='utf-8-sig')
    gateController=ctl.split('function Ctl.doubleGateContext(',1)[1].split('function Ctl.tryWindowRepair(',1)[0]
    chunks['controller.lua']+='\nfunction Ctl.doubleGateContext('+gateController
    reader=ROOT/'tools/resource_production_checks/recipe_reading_cases.lua'
    readerText=reader.read_text(encoding='utf-8-sig');attach=readerText.split('    f.book=__boardingItem(',1)[1].split('    f.purpose={',1)[0]
    chunks['native-recipe-reading.lua']=(base.GAME/'media/lua/shared/TimedActions/ISReadABook.lua').read_text(encoding='utf-8-sig')
    chunks['reading-ports.lua']=readerText.split('local checks={}',1)[0]+'\nfunction __attachGateRecipeBook(f,literature)\n    literature=literature or \"Base.MetalworkMag3\"\n    f.book=__boardingItem('+attach+'\nend'
    chunks['study.lua']=(base.LUA/'client/SAO_Study.lua').read_text(encoding='utf-8-sig')
    chunks['source-use.lua']=(base.LUA/'client/SAO_SourceUse.lua').read_text(encoding='utf-8-sig')
    chunks['double-gate-cases.lua']=CASES.read_text(encoding='utf-8-sig')
    families=['DoubleDoor','DoubleFenceGate','DoubleWireGate'] if args.family=='all' else [args.family];faces=['N','W'] if args.face=='all' else [args.face]
    chunks['run.lua']=';'.join("__runDoubleGateFamily('Base."+family+"','"+face+"')" for family in families for face in faces)
    expected={name+'_'+family+'_'+face for name in re.findall(r"gateCheck\('([a-z0-9_]+)',",CASES.read_text(encoding='utf-8')) for family in families for face in faces}
    expected.update('native_'+operation+'_under_same_retained_purpose_'+family+'_'+face for operation in ['open','pass','close'] for family in families for face in faces)
    case=CASES.read_text(encoding='utf-8');selected=next((name for flag,name in [(args.pool_only,'Pool'),(args.knowledge_only,'Knowledge'),(args.guards_only,'Guards'),(args.lifecycle_only,'Lifecycle'),(args.acquisition_only,'Acquisition')] if flag),None)
    if selected:chunks['run.lua']='__runDoubleGate'+selected+'()';expected=named_checks(case,selected)
    elif args.family=='all' and args.face=='all':
        for name in ['Pool','Knowledge','Guards','Lifecycle','Acquisition','Capacity','Payment','PassageEdge']:
            chunks['run.lua']+=';__runDoubleGate'+name+'()';expected.update(named_checks(case,name))
        chunks['run.lua']+=';__runDoubleGateReviewPhases();__runDoubleGateReviewSites();__runDoubleGateReviewRace()';expected.update(review_checks(case))
    if args.review_corrections_only:chunks['run.lua']='__runDoubleGateReviewPhases();__runDoubleGateReviewSites();__runDoubleGateReviewRace()';expected=review_checks(case)
    normal=execute(out/'normal',chunks,classes,cp,expected);receipt.update(normal)
    if normal['status']=='PASS' and not args.no_controls:
        directory=out/'controls';directory.mkdir()
        mutations=[
            ('private-intent','planner.lua','context.boundaryConcern~=true','false','no_gate_work_without_person_boundary_concern','Guards',None),
            ('pooled-planner-cap','planner.lua','#option.inputs > ((option.kind=="build-double-gate" or option.productionKind=="build-double-gate") and 38 or 32)','#option.inputs > 32','all_pooled_gate_objects_reach_ready_saved_and_observed_plan','Capacity',None),
            ('pooled-production-cap','production.lua','rows[#rows+1]={inputIndex=requirement.inputIndex','if #rows>=32 then return rows end\n                rows[#rows+1]={inputIndex=requirement.inputIndex','all_pooled_gate_objects_reach_ready_saved_and_observed_plan','Capacity',None),
            ('native-use-payment','production.lua','after~=before-row.quantity','after~=before-row.quantity+1','native_charge_payment_measurement_accepts_exact_installed_use_deltas','Payment',None),
            ('current-whole-space-standing','production.lua','if query(id,site.x+x,site.y+y,"standing")~=true then return false end','if false then return false end','revoked_current_operating_permission_refuses_native_toggle_callback','Guards','gate.permission'),
            ('frozen-scalar-anchor','production.lua','w.startedAt==rt.startedAt','true','changed_current_saved_scalar_anchor_refuses_native_effect','Guards','gate.anchors'),
            ('admitted-phase-custody','production.lua','row.operation~=expected.operation','false','changed_saved_operation_cannot_substitute_passage_for_opening','Lifecycle','gate.outcome'),
            ('retired-effect-retry','production.lua','if rt.operation~="pass" and rt.nativeAttempted','if false and rt.nativeAttempted','ordinary_tick_publishes_retired_native_effect_after_capacity_clears','Lifecycle','gate.tick'),
            ('pending-ledger-recovery','production.lua','if #rows>=CRAFT_LIMIT and rows[1].purposeId and not rows[1].purposeDelivered then return false end','if false then return false end','saved_gate_recovery_preserves_pending_oldest_at_capacity','Lifecycle','gate.recover'),
            ('saved-world-generation-before-retirement','production.lua','w.world~=world:getWorld() or w.bodyToken~=body:getModData().SAOExternalToken','false','saved_changed_world_generation_sequence_clock_refuse_before_queue_retirement','Lifecycle','gate.recover'),
            ('acquisition-exact-custody','planner.lua','(purpose.collector or purpose.gateAccess)','purpose.collector','changed_authoritative_source_item_actor_quantity_cannot_advance_gate','Acquisition','P.consumeSourceResult'),
            ('acquisition-item-units','planner.lua','if purpose.gateAccess and completed and (','if false and completed and (','changed_authoritative_source_item_actor_quantity_cannot_advance_gate','Acquisition','P.consumeSourceResult'),
        ]
        reviewMutations=[
            ('live-observed-phase','planner.lua','local current=SAO.Perception and SAO.Perception.currentDoubleGateGroup(id,SAO.Body.get(id),own.groupId,own.entityId,own.site)','local current=nil','personally_observed_external_open_selects_pass_without_own_open_credit_DoubleDoor_N','ReviewPhases',None),
            ('reopening-attempt-identity','planner.lua','local phaseId="double-gate-"..operation..":"..tostring(own.opened or own.builtWorkId)','local phaseId="double-gate-"..operation','current_external_reclosure_selects_real_reopen_before_original_pass_DoubleDoor_N','ReviewPhases',None),
            ('constructed-site-consumption','planner.lua','if SAO.Perception and SAO.Perception.consumeDoubleGateSite then SAO.Perception.consumeDoubleGateSite(id,row) end','if false then SAO.Perception.consumeDoubleGateSite(id,row) end','completed_occupied_gap_cannot_start_second_purpose_or_material_collection','ReviewSites',None),
            ('personal-group-observation','perception.lua','row.observed~=true','false','hidden_external_group_change_cannot_manufacture_current_open_fact','ReviewSites','P.currentDoubleGateGroup'),
            ('newer-free-observation','perception.lua',' or site.observedAtHours>row.atHours','','late_old_build_receipt_cannot_erase_newer_free_site_observation','ReviewSites','P.consumeDoubleGateSite'),
            ('post-cross-current-openness','production.lua','or row.operation=="close" and (row.afterGroup.open~=false','or row.operation=="pass" and row.afterGroup.open~=true or row.operation=="close" and (row.afterGroup.open~=false','recorded_native_crossing_retires_after_external_closure_DoubleDoor_N','ReviewRace','gate.outcome'),
        ]
        mutations=reviewMutations if args.review_corrections_only else [*mutations,*reviewMutations]
        for name,leaf,old,new,target,group,scope in mutations:
            if args.control and args.control!=name:continue
            variant=dict(chunks);variant[leaf]=replace_contract(chunks[leaf],old,new,scope);variant['run.lua']='__runDoubleGate'+group+'()'
            if group in ('ReviewPhases','ReviewRace'):
                pattern='phaseCheck' if group=='ReviewPhases' else 'raceCheck';section=case.split('function __runDoubleGate'+group+'()',1)[1]
                if group=='ReviewPhases':section=section.split('function __runDoubleGateReviewSites()',1)[0]
                selectedChecks={name+'_'+family+'_'+face for name in re.findall(pattern+r"\('([a-z0-9_]+)',",section) for family in ['DoubleDoor','DoubleFenceGate','DoubleWireGate'] for face in ['N','W']}
            else:selectedChecks=named_checks(case,group)
            result=execute(directory/name,variant,classes,cp,selectedChecks);result.update(target=target,productionContract=scope or leaf,
                originalSourceSha256=hashlib.sha256(chunks[leaf].encode()).hexdigest(),mutantSourceSha256=base.digest(directory/name/leaf))
            result['status']='DETECTED' if result['complete'] and result['checks'].get(target)=='false' else 'NOT_DETECTED'
            receipt['controls'][name]=result;(directory/name/'receipt.json').write_text(json.dumps(result,indent=2)+'\n')
        native=ROOT/'java/src/com/sao/engine/SAODoubleGate.java'
        for name,old,new,target,group in [
            ('competing-native-member','&&competitor.getNorth()==anchor.getNorth()','&&false&&competitor.getNorth()==anchor.getNorth()','competing_copy_at_native_operating_position_refuses_group','Guards'),
            ('exact-native-passage-edge','&&p.crossed','&&true','same_body_route_around_boundary_cannot_credit_selected_gate_passage','PassageEdge')]:
            if args.review_corrections_only:continue
            if args.control and args.control!=name:continue
            folder=directory/name;folder.mkdir();mutant=folder/native.name;mutant.write_text(replace_contract(native.read_text(),old,new));shadow=folder/'classes';shadow.mkdir()
            command=[str(base.JDK/'javac.exe'),'-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,'-d',str(shadow),str(mutant)]
            compiledControl=subprocess.run(command,text=True,capture_output=True,timeout=60);(folder/'compile.log').write_text(compiledControl.stdout+compiledControl.stderr)
            variant=dict(chunks);variant['run.lua']='__runDoubleGate'+group+'()';result=execute(folder/'run',variant,str(shadow)+os.pathsep+str(classes),cp,named_checks(case,group)) if compiledControl.returncode==0 else {'complete':False,'checks':{}}
            result.update(target=target,compileExit=compiledControl.returncode,compileCommand=command,originalSourceSha256=base.digest(native),mutantSourceSha256=base.digest(mutant),
                compiledClassPins={str(p.relative_to(shadow)).replace('\\','/'):base.digest(p) for p in shadow.rglob('*.class')})
            result['status']='DETECTED' if result['complete'] and result['checks'].get(target)=='false' else 'NOT_DETECTED';receipt['controls'][name]=result;(folder/'receipt.json').write_text(json.dumps(result,indent=2)+'\n')
        if args.control and not receipt['controls']:raise ValueError('Unknown selected detecting control '+args.control)
        if not args.control:receipt['preflightControls']=preflight_controls(out/'preflight-controls',owned)
    after={str(p):base.digest(p) for p in inputs};receipt.update(inputsBefore=before,inputsAfter=after,sourcePreserved=before==after,
        productionInventory=[str(p.relative_to(ROOT)).replace('\\','/') for p in PRODUCTION],instrumentInventory=[str(p.relative_to(ROOT)).replace('\\','/') for p in INSTRUMENTS],
        compiledClassPins={str(p.relative_to(classes)).replace('\\','/'):base.digest(p) for p in classes.rglob('*.class')},
        boundary='Installed registered recipe/skill/learned admission, exact native manual BuildLogic payment and drainable uses, native entity factory, complete group metadata, native ToggleDoor/relocation/collision and same-body native postupdate passage. Controlled actor/source/dispatch ports and finite native-supported route nodes/stride. Initial freestanding boundary geometry is supplied; gates are absent initially and no roof/fatigue purpose supplies admission.')
    receipt['status']='PASS' if normal['status']=='PASS' and syntax.returncode==0 and before==after and all(c['status']=='DETECTED' for c in receipt['controls'].values()) and receipt.get('preflightControls',{'status':'PASS'})['status']=='PASS' else 'FAIL'
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(receipt['status']+' double gates '+str(out/'receipt.json'))
    if receipt['status']!='PASS':print((out/'normal/output.log').read_text(encoding='utf-8')[-6000:])
    return 0 if receipt['status']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
