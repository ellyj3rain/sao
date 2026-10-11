#!/usr/bin/env python3
"""D3.13 installed metal shelter producer and existing person-private consumer."""
from __future__ import annotations
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile,sys
from pathlib import Path
BOOT_ROOT=Path(__file__).resolve().parent.parent
for bootstrap in [BOOT_ROOT/'tools/d3_shelter_construction_test.py',BOOT_ROOT/'tools/native_proof_preflight.py']:
    if not bootstrap.is_file():print('FAILED metal shelter: owned proof inputs absent: '+str(bootstrap));raise SystemExit(1)
import d3_shelter_construction_test as common
from native_proof_preflight import presence
ROOT,GAME,JDK,LUA=common.ROOT,common.GAME,common.JDK,common.LUA
PROBE=ROOT/'tools/resource_production_checks/MetalShelterNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/metal_shelter_cases.lua'
EXTRA=[LUA/'client/SAO_Study.lua',LUA/'client/SAO_SourceUse.lua']
JAVA=[ROOT/f'java/src/com/sao/{path}' for path in ['engine/SAOShelterConstruction.java','engine/SAONeeds.java','engine/SAOWorldSources.java','bridge/SAOBridge.java','engine/SAOIsoPlayerShell.java','engine/SAOShelterStairs.java','engine/SAODoubleGate.java']]
NATIVE=[GAME/'media/lua/server/CraftRecipeCode/CraftRecipe_BuildMenu.lua',GAME/'media/lua/shared/TimedActions/ISReadABook.lua']
DEFS=[GAME/f'media/scripts/generated/entities/walls/{name}.txt' for name in ['entity_metal_wallframe','entity_metal_walllvl1','entity_metal_walllvl2','entity_metal_doorframelvl1','entity_metal_doorframelvl2','entity_metal_doorlvl1','entity_metal_doorlvl2']]
DEFS += [GAME/'media/scripts/generated/items/drainable.txt',GAME/'media/scripts/generated/items/literature.txt']
READER=ROOT/'tools/resource_production_checks/recipe_reading_cases.lua'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def replace_contract(source,old,new,scope=None):
    if scope:
        head,body=source.split('function '+scope+'(',1);match=re.search(r'\nfunction [A-Za-z_][A-Za-z0-9_.]*\(',body)
        at=match.start() if match else len(body);section,tail=body[:at],body[at:]
        if section.count(old)!=1:raise ValueError((scope,old,section.count(old)))
        return head+'function '+scope+'('+section.replace(old,new,1)+tail
    if source.count(old)!=1:raise ValueError((old,source.count(old)))
    return source.replace(old,new,1)
CONTROLS=[
    ('owned-reading-before-reconcile','controller.lua','if SAO.Study and SAO.Study.active(id,body) then return false end\n        if SAO.Study and SAO.Study.reconcileRecipe then SAO.Study.reconcileRecipe(id,body) end','if SAO.Study and SAO.Study.reconcileRecipe then SAO.Study.reconcileRecipe(id,body) end','ordinary_controller_recovery_tick_preserves_current_native_shelter_read','Knowledge','Ctl.offerRecovery'),
    ('exact-reading-purpose-admission','planner.lua','local s=state(id);local p=s and s.purposes[w.purposeId];local step=p and p.steps[p.cursor]','local p,step=P.recipeReadingPurpose(id)','exact_chosen_shelter_read_leaves_unrelated_available_gate_untouched','Knowledge','P.admitRecipeReading'),
    ('original-selection-anchor','production.lua','if intention[key]~=anchor[key] then return false end','if false then return false end','foreign_saved_actor_world_site_intention_cannot_admit_upgrade','Guards','shelter.intendedUpgrade'),
    ('false-book-actionability','planner.lua','local book=recipeNeeded and context.recipeBooks and context.recipeBooks[option.recipeName] or nil','local book=recipeNeeded and context.recipeBooks and context.recipeBooks[option.recipeName]','ordinary_shelter_planner_selects_actual_native_recipe_reading','Knowledge',None),
    ('actual-knowledge-visibility','production.lua','body:isRecipeActuallyKnown(recipe:getName())==true','CraftRecipeManager.hasPlayerLearnedRecipe(recipe,body)==true','ordinary_shelter_planner_selects_actual_native_recipe_reading','Knowledge','shelter.learned'),
    ('knowledge-at-effect','production.lua','if not shelter.learned(rt.policy.recipe,body) then return false end','if false then return false end','actual_knowledge_revocation_before_effect_prevents_native_payment','Guards','shelter.bound'),
    ('current-standing-at-effect','production.lua','local query=current and SAO.Standing.mayTakeCurrent or SAO.Standing.mayAttemptBelieved','if current then return true end\n    local query=current and SAO.Standing.mayTakeCurrent or SAO.Standing.mayAttemptBelieved','current_standing_revocation_before_effect_prevents_native_payment','Guards','shelter.permission'),
    ('metered-charge-payment','production.lua','after~=before-row.quantity','after~=before-row.quantity+1','native_metered_payment_measures_current_charge_decrement','Guards','collector.usePayment'),
    ('exact-native-recipe-identity','production.lua','w.recipeId~=w.entityId','not textId(w.recipeId)','foreign_saved_recipe_identity_cannot_earn_build_credit','Guards','shelter.identity'),
    ('native-dontrecordinput','production.lua',' or req.recordInput~=(not weld and w.entityId=="Base.DoubleWireGate" and i==3)','','changed_saved_dontrecordinput_contract_cannot_earn_build_credit','Guards','shelter.identity'),
    ('exact-native-metal-policy','production.lua','["Base.MetalWallFrame"]={kind="wall-frame",counts={1,3,1}','["Base.MetalWallFrame"]={kind="wall-frame",counts={1,4,1}','complete_native_metal_recipe_policy_is_available','Policy',None),
    ('native-eligibility-before-cap','sources.lua','if itemFilter then filterOk,eligible=pcall(itemFilter,item and item.type) end','if false then filterOk,eligible=pcall(itemFilter,item and item.type) end','native_exact_material_predicate_filters_before_private_action_capacity','Categories','WS.actionOptions'),
    ('source-quantity-custody','planner.lua','(purpose.gateAccess or purpose.shelterConstruction) and completed','purpose.gateAccess and completed','changed_authoritative_source_item_actor_quantity_cannot_advance_metal_shelter','Acquisition','P.consumeSourceResult'),
    ('delayed-exact-acquisition','planner.lua','if retained and selected.delayed and not source and current and current.owner=="SAO.SourceUse" then','if false then','saved_acquisition_refusal_waits_existing_exact_retry_clock','Acquisition','P.planShelterConstruction'),
    ('healthy-grade1-retention','production.lua','and (not site.upgradeOpportunity or shelter.intendedUpgrade(id,body,retained,site))','and true','healthy_grade1_wall_is_not_a_new_shelter_breach_or_forced_upgrade','Guards','R.shelterOptions'),
    ('acquired-upgrade-copy','perception.lua',',"upgradeOpportunity"','', 'healthy_grade1_wall_is_not_a_new_shelter_breach_or_forced_upgrade','Guards',None),
    ('retained-metal-completed-edge','planner.lua',' or canonical.entityId:find("MetalWallLvl",1,true) or canonical.entityId:find("MetalDoorLvl",1,true)','','successful_native_metal_wall_enters_retained_completed_edges','Guards','P.consumeShelterConstructionResult'),
    ('saved-native-feedback-model','models.lua','["Base.MetalDoorFrameLvl1"]=true,','', 'saved_private_feedback_replays_actual_build_once','Guards','validEvent'),
]
def expected(group):
    case=CASES.read_text(encoding='utf-8-sig')
    def literals(name):
        section=case.split('function __runMetal'+name+'()',1)[1]
        next_function=re.search(r'\n(?:local )?function [A-Za-z_][A-Za-z0-9_.]*\(',section)
        if next_function:section=section[:next_function.start()]
        return set(re.findall(r"check\('([a-z0-9_]+)',",section))
    groups={name:literals(name) for name in ['Knowledge','UrgentReading','Acquisition','ManualAcquisition','Categories','Guards','Policy']}
    groups['Families']={'family'+str(n)+'_'+face+'_'+suffix for n in range(1,8) for face in ['N','W'] for suffix in ['native_admission','saved_exact_use_inputs','native_payment_and_grade','native_stage_index','independent_private_build_feedback']}
    chain=case.split('local function chain(',1)[1].split('function __runMetalChains()',1)[0]
    names=set(re.findall(r"chainCheck\('([a-z0-9_]+)'",chain))
    groups['Chains']={kind+str(grade)+'_'+face+'_'+name for kind in ['chain','wallchain'] for grade in [1,2] for face in ['N','W'] for name in names}
    early={'ordinary_shelter_concern_admits_native_stage','native_frame_keeps_original_shelter_concern','native_leaf_continues_same_concern'}
    groups['DoorGuards']={('native_'+kind+'_authority_refuses_' if prefix=='native' else 'ordinary_'+kind+'_keeps_original_unfinished_shelter_')+str(1 if kind=='lock' else 2)+'_'+face for prefix in ['native','ordinary'] for kind in ['lock','barricade','obstruction'] for face in ['N','W']}
    groups['DoorGuards']|={'refusal_'+kind+'_chain'+str(1 if kind=='lock' else 2)+'_'+face+'_'+name for kind in ['lock','barricade','obstruction'] for face in ['N','W'] for name in early}
    groups['Guards']|={entity+'_'+face+'_native_wood_frame_substitution' for entity in ['MetalWallLvl1','MetalWallLvl2'] for face in ['N','W']}
    groups['Guards']|={'MetalDoor_'+face+'_native_wood_doorframe_substitution' for face in ['N','W']}|{'WoodWall_'+face+'_native_metal_frame_substitution' for face in ['N','W']}
    return set.union(*(groups[name] for name in group))
def chunks():
    out=common.sources()
    out['rain-fixture.lua']='__metalCases=true\n'+out['rain-fixture.lua']
    tail={key:out.pop(key) for key in ['production.lua','experience.lua','needs.lua','needs-ports.lua','controller.lua','controller-cases.lua']}
    out['native-metal-menu.lua']=NATIVE[0].read_text(encoding='utf-8-sig')
    out['native-read.lua']=NATIVE[1].read_text(encoding='utf-8-sig')
    out['reading-ports.lua']=READER.read_text(encoding='utf-8-sig').split('local checks={}',1)[0]
    out.update(tail)
    ctl=common.CONTROLLER.read_text(encoding='utf-8-sig')
    resource='function Ctl.resourceContext('+ctl.split('function Ctl.resourceContext(',1)[1].split('-- This read-only preflight',1)[0]
    out['controller.lua']+='\n'+resource
    for path in EXTRA:out[path.stem+'.lua']=path.read_text(encoding='utf-8-sig')
    out['metal-cases.lua']=CASES.read_text(encoding='utf-8-sig')
    return out
def execute(out,sources,classes,run,override=None):
    out.mkdir();shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
    for name,source in {**sources,'run.lua':run}.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    cp=os.pathsep.join(map(str,[*([override] if override else []),classes,GAME/'projectzomboid.jar',ROOT/'mod/42.20/media/java/SAO.jar',GAME/'ZombieBuddy.jar']))
    command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',cp,'MetalShelterNativeProbe',str(GAME),*paths]
    with (out/'output.log').open('w',encoding='utf-8') as stream:
        try:done=subprocess.run(command,cwd=out,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
        except subprocess.TimeoutExpired:done=subprocess.CompletedProcess(command,124)
    output=(out/'output.log').read_text(encoding='utf-8',errors='replace')
    pairs=re.findall(r'^METAL ([a-zA-Z0-9_]+)=(true|false)$',output,re.M);checks=dict(pairs)
    return {'command':command,'exitCode':done.returncode,'checks':checks,'failed':[k for k,v in checks.items() if v!='true'],'duplicateVerdicts':sorted({k for k,v in pairs if sum(name==k for name,value in pairs)>1}),'complete':'METAL COMPLETE' in output,'logSha256':digest(out/'output.log')}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--required',action='store_true');parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--families-only',action='store_true');parser.add_argument('--chain-only',action='store_true');parser.add_argument('--knowledge-only',action='store_true');parser.add_argument('--acquisition-only',action='store_true');parser.add_argument('--guards-only',action='store_true');parser.add_argument('--categories-only',action='store_true');parser.add_argument('--door-guards-only',action='store_true');parser.add_argument('--no-controls',action='store_true');parser.add_argument('--control',help='One named focused detecting mutation.');args=parser.parse_args()
    owned=[Path(__file__),Path(common.__file__),ROOT/'tools/native_proof_preflight.py',PROBE,CASES,READER,common.PROBE,common.CASES,common.CTL_CASES,common.CONTROLLER,common.BASE,common.BOARD,common.PLUMB,*common.LEAVES.values(),*EXTRA,*JAVA,ROOT/'tools/luacheck/LuaSyntax.java',ROOT/'tools/luacheck/MovementCrossingProbe.java']
    installed=[*common.NATIVE,*common.SCRIPTS,*NATIVE,*DEFS,GAME/'media/lua/shared/defines.lua',GAME/'media/lua/server/BuildingObjects/ISBuildUtil.lua',GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe',ROOT/'mod/42.20/media/java/SAO.jar']
    readiness=presence(owned,installed,args.required,'metal shelter')
    if readiness is not None:return readiness
    out=args.out.resolve()
    if out.exists():raise ValueError('immutable receipt directory already exists')
    out.mkdir(parents=True);before={str(p):digest(p) for p in owned+installed};classes=out/'classes';classes.mkdir()
    cp=os.pathsep.join(map(str,[GAME/'projectzomboid.jar',ROOT/'mod/42.20/media/java/SAO.jar',GAME/'ZombieBuddy.jar']))
    command=[str(JDK/'javac.exe'),'-cp',cp,'-d',str(classes),str(PROBE),str(common.PROBE),str(ROOT/'tools/luacheck/MovementCrossingProbe.java'),str(ROOT/'tools/luacheck/LuaSyntax.java'),*map(str,JAVA)]
    compiled=subprocess.run(command,capture_output=True,text=True,timeout=90);(out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    receipt={'status':'FAIL','inputPins':before,'compile':{'command':command,'exitCode':compiled.returncode,'logSha256':digest(out/'compile.log')},'controls':[]}
    if compiled.returncode==0:
        syntax=subprocess.run([str(JDK/'java.exe'),'-cp',str(classes)+os.pathsep+cp,'LuaSyntax',*map(str,[CASES,*common.LEAVES.values(),*EXTRA,common.CONTROLLER])],capture_output=True,text=True,timeout=90);(out/'syntax.log').write_text(syntax.stdout+syntax.stderr,encoding='utf-8');receipt['syntax']={'exitCode':syntax.returncode,'logSha256':digest(out/'syntax.log')}
        run='__runMetalFamilies()' if args.families_only else '__runMetalChains()' if args.chain_only else '__runMetalKnowledge();__runMetalUrgentReading()' if args.knowledge_only else '__runMetalAcquisition();__runMetalManualAcquisition()' if args.acquisition_only else '__runMetalGuards()' if args.guards_only else '__runMetalCategories()' if args.categories_only else '__runMetalDoorGuards()' if args.door_guards_only else '__runMetalFamilies();__runMetalChains();__runMetalKnowledge();__runMetalUrgentReading();__runMetalAcquisition();__runMetalManualAcquisition();__runMetalCategories();__runMetalGuards();__runMetalDoorGuards()'
        selected=next((names for flag,names in [(args.families_only,['Families']),(args.chain_only,['Chains']),(args.knowledge_only,['Knowledge','UrgentReading']),(args.acquisition_only,['Acquisition','ManualAcquisition']),(args.guards_only,['Guards']),(args.categories_only,['Categories']),(args.door_guards_only,['DoorGuards'])] if flag),['Families','Chains','Knowledge','UrgentReading','Acquisition','ManualAcquisition','Categories','Guards','DoorGuards','Policy'])
        if 'Policy' in selected:run+=';__runMetalPolicy()'
        captured=chunks();receipt['normal']=execute(out/'normal',captured,classes,run+';print("METAL COMPLETE")')
        normal=receipt['normal'];normal['missing']=sorted(expected(selected)-normal['checks'].keys());normal['extra']=sorted(normal['checks'].keys()-expected(selected))
        receipt['status']='PASS' if syntax.returncode==0 and normal['exitCode']==0 and normal['complete'] and normal['checks'] and not normal['failed'] and not normal['missing'] and not normal['extra'] and not normal['duplicateVerdicts'] else 'FAIL'
        if receipt['status']=='PASS' and not args.no_controls:
            mutations=[m for m in CONTROLS if not args.control or m[0]==args.control]
            if args.control and not mutations and args.control!='visible-native-predecessor':raise ValueError('unknown control '+args.control)
            for name,file,old,new,target,group,scope in mutations:
                variant=dict(captured);before_source=variant[file];variant[file]=replace_contract(before_source,old,new,scope)
                result=execute(out/('control-'+name),variant,classes,'__runMetal'+group+'();print("METAL COMPLETE")')
                result.update(name=name,target=target,mutationMatches=1,sourcePreimageSha256=hashlib.sha256(before_source.encode()).hexdigest(),sourceMutantSha256=hashlib.sha256(variant[file].encode()).hexdigest(),landed=before_source!=variant[file])
                result['detected']=result['exitCode']==0 and result['complete'] and result['checks'].get(target)=='false'
                receipt['controls'].append(result);print('CONTROL',name,result['detected'],flush=True)
            if not args.control or args.control=='visible-native-predecessor':
                directory=out/'control-visible-native-predecessor';directory.mkdir();source=JAVA[0].read_text(encoding='utf-8-sig')
                mutant=replace_contract(source,'if(!neighborVisible&&!visibleDoor&&!visibleUpgrade)continue;','if(!neighborVisible&&!visibleDoor)continue;')
                p=directory/'SAOShelterConstruction.java';p.write_text(mutant,encoding='utf-8');override=directory/'classes';override.mkdir()
                command=[str(JDK/'javac.exe'),'-cp',str(classes)+os.pathsep+cp,'-d',str(override),str(p)]
                built=subprocess.run(command,capture_output=True,text=True,timeout=60);(directory/'compile.log').write_text(built.stdout+built.stderr,encoding='utf-8')
                result=execute(directory/'native',captured,classes,'__runMetalGuards();print("METAL COMPLETE")',override) if built.returncode==0 else {'exitCode':-1,'complete':False,'checks':{}}
                result.update(name='visible-native-predecessor',target='retained_actual_grade2_intention_accepts_native_grade1_replacement',compileExit=built.returncode,compileCommand=command,sourcePreimageSha256=hashlib.sha256(source.encode()).hexdigest(),sourceMutantSha256=digest(p),landed=source!=mutant,mutationMatches=1)
                result['detected']=built.returncode==0 and result['exitCode']==0 and result['complete'] and result['checks'].get(result['target'])=='false';receipt['controls'].append(result);print('CONTROL visible-native-predecessor',result['detected'],flush=True)
            if not receipt['controls'] or not all(c['detected'] and c['landed'] for c in receipt['controls']):receipt['status']='FAIL'
    receipt['sourcePreserved']=all(digest(Path(p))==sha for p,sha in before.items())
    receipt['compiledClassPins']={str(p.relative_to(classes)).replace('\\','/'):digest(p) for p in classes.rglob('*.class')}
    if not receipt['sourcePreserved']:receipt['status']='FAIL'
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(receipt['status'],len(receipt.get('normal',{}).get('checks',{})),'receipt',out/'receipt.json');return 0 if receipt['status']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
