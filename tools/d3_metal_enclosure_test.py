#!/usr/bin/env python3
"""D3.15 changed producer, private boundary and physical consumer proof."""
from __future__ import annotations
import argparse,hashlib,json,os,re,shutil,subprocess
from pathlib import Path
import d3_metal_shelter_test as metal
common=metal.common
ROOT,GAME,JDK,LUA=metal.ROOT,metal.GAME,metal.JDK,metal.LUA
PROBE=ROOT/'tools/resource_production_checks/MetalEnclosureNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/metal_enclosure_cases.lua'
ENTITIES=['MetalWindowFrameLvl1','MetalWindowFrameLvl2','MetalFenceLvl1','MetalFenceLvl2','MetalBigMetalFence','MetalBigWireFence','MetalSmallPoleFence','MetalSmallWireFence','MetalPoleFenceGate','MetalPoleFenceGateSmall','MetalWireFenceGate','MetalWireFenceGateSmall']
JAVA=list(dict.fromkeys([*metal.JAVA,ROOT/'java/src/com/sao/engine/SAOEnclosureEdge.java',ROOT/'java/src/com/sao/engine/SAOMovement.java']))
def chunks():
    sources=metal.chunks();sources.pop('metal-cases.lua')
    source=sources['rain-fixture.lua']
    source=source.replace('IsoObjectType=setmetatable','IsoFlagType=setmetatable(IsoFlagType or {},{__index=function(_,key)return key end})\nIsoObjectType=setmetatable',1)
    anchor='local policies={}'
    source=source.replace(anchor,'for _,id in ipairs({'+','.join('"Base.'+v+'"' for v in ENTITIES)+'}) do entities[#entities+1]=id end\n'+anchor,1)
    source=source.replace('for j=0,((id:find("WoodenDoorLvl",1,true) or id:find("MetalDoorLvl",1,true)) and 4 or 2) do','for j=0,__nativeShelter("inputCount",id)-1 do',1)
    source=source.replace('for j=0,((recipe.entityId:find("WoodenDoorLvl",1,true) or recipe.entityId:find("MetalDoorLvl",1,true)) and 4 or 2) do','for j=0,__nativeShelter("inputCount",recipe.entityId)-1 do',1)
    sources['rain-fixture.lua']=source
    if os.environ.get('SAO_ENCLOSURE_DEBUG'):
        source=sources['production.lua'];head,body=source.split('function shelter.begin(',1);section,tail=body.split('-- Native doorway use remains',1)
        index=0
        for line in section.splitlines():
            if 'return false' in line:
                index+=1;section=section.replace(line,line.replace('return false',f'print("BEGIN_REFUSAL{index}");return false'),1)
        sources['production.lua']=head+'function shelter.begin('+section+'-- Native doorway use remains'+tail
    ctl=common.CONTROLLER.read_text(encoding='utf-8-sig');sources['controller.lua']+='\nfunction Ctl.doubleGateContext('+ctl.split('function Ctl.doubleGateContext(',1)[1].split('function Ctl.tryWindowRepair(',1)[0]
    sources['enclosure-cases.lua']=CASES.read_text(encoding='utf-8-sig')
    return sources

def execute(out,sources,classes,run,override=None):
    out.mkdir();shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
    for name,source in {**sources,'run.lua':run}.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    cp=os.pathsep.join(map(str,[*([override] if override else []),classes,GAME/'projectzomboid.jar',ROOT/'mod/42.20/media/java/SAO.jar',GAME/'ZombieBuddy.jar']))
    command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',cp,'MetalEnclosureNativeProbe',str(GAME),*paths]
    with (out/'output.log').open('w',encoding='utf-8') as f:
        try:done=subprocess.run(command,cwd=out,stdout=f,stderr=subprocess.STDOUT,timeout=180)
        except subprocess.TimeoutExpired:done=subprocess.CompletedProcess(command,124)
    output=(out/'output.log').read_text(encoding='utf-8',errors='replace');pairs=re.findall(r'^METAL ([a-zA-Z0-9_]+)=(true|false)$',output,re.M)
    return {'command':command,'exitCode':done.returncode,'checks':dict(pairs),'failed':[k for k,v in pairs if v!='true'],'complete':'ENCLOSURE COMPLETE' in output,'log':str(out/'output.log'),'logSha256':metal.digest(out/'output.log')}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--required',action='store_true');parser.add_argument('--no-controls',action='store_true');parser.add_argument('--corrections-only',action='store_true');args=parser.parse_args()
    installed=[*common.NATIVE,*common.SCRIPTS,*metal.NATIVE,*metal.DEFS,GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',ROOT/'mod/42.20/media/java/SAO.jar',JDK/'java.exe',JDK/'javac.exe']
    entityFiles={re.search(r'entity\s+(\w+)',p.read_text(encoding='utf-8-sig')).group(1):p for p in (GAME/'media/scripts/generated/entities/walls').glob('entity_metal*.txt')}
    installed+=[entityFiles[name] for name in ENTITIES if name in entityFiles]
    inputs=[PROBE,CASES,metal.PROBE,common.PROBE,common.CASES,common.BASE,common.BOARD,common.PLUMB,common.CTL_CASES,metal.READER,*JAVA,*common.LEAVES.values(),*metal.EXTRA,common.CONTROLLER,Path(__file__),Path(metal.__file__),Path(common.__file__)]
    readiness=metal.presence(inputs,installed,args.required,'metal enclosure')
    if readiness is not None:return readiness
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False);classes=out/'classes';classes.mkdir()
    inputs=list(dict.fromkeys([*inputs,*installed]))
    before={str(p):metal.digest(p) for p in inputs}
    cp=os.pathsep.join(map(str,[GAME/'projectzomboid.jar',ROOT/'mod/42.20/media/java/SAO.jar',GAME/'ZombieBuddy.jar']))
    command=[str(JDK/'javac.exe'),'-cp',cp,'-d',str(classes),str(PROBE),str(metal.PROBE),str(common.PROBE),str(ROOT/'tools/luacheck/MovementCrossingProbe.java'),str(ROOT/'tools/luacheck/ResourceApproachProbe.java'),str(ROOT/'tools/luacheck/LuaSyntax.java'),*map(str,JAVA)]
    compiled=subprocess.run(command,capture_output=True,text=True,timeout=90);(out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    receipt={'status':'FAIL','sourcePins':before,'compile':{'command':command,'exitCode':compiled.returncode,'log':str(out/'compile.log')},'controls':[]}
    if compiled.returncode==0:
        captured=chunks();run='__runEnclosureCorrections()' if args.corrections_only else '__runEnclosureFrames();__runEnclosureBoundaries();__runEnclosureGateUses();__runEnclosureGuards();__runEnclosureCorrections()';receipt['normal']=execute(out/'normal',captured,classes,run+';print("ENCLOSURE COMPLETE")')
        normal=receipt['normal']
        expected={f'family{i}_{face}_{suffix}' for i in range(1,3) for face in ['N','W'] for suffix in ['native_admission','saved_exact_use_inputs','native_payment_and_grade','native_stage_index','independent_private_build_feedback']}
        expected|={f'boundary{i}_{face}_{suffix}' for i in range(1,11) for face in ['N','W'] for suffix in ['native_admission','native_payment_and_creation','actual_native_collision','no_shelter_or_recovery_credit','independent_private_feedback']}
        expected|={f'single{i}_{face}_{suffix}' for i in range(7,11) for face in ['N','W'] for suffix in [*[f'{op}_{kind}' for op in ['open','pass','close'] for kind in ['original_purpose','actual_native_effect']],'same_body_physical_passage','closure_replay_independent_feedback']}
        expected|=set(re.findall(r"check\('([a-z0-9_]+)'",CASES.read_text(encoding='utf-8')))
        if args.corrections_only:expected=set(re.findall(r"check\('([a-z0-9_]+)'",CASES.read_text(encoding='utf-8').split('function __runEnclosureCorrections()',1)[1]))
        expected|={f'{kind}_{suffix}' for kind in ['fence','single_gate'] for suffix in ['canonical_build_retires_exact_acquired_gap','ordinary_controller_replans_other_native_gap','saved_replay_preserves_consumed_gap_and_other_fact','old_completion_preserves_newer_boundary_revision']}
        normal['missing']=sorted(expected-normal['checks'].keys());normal['extra']=sorted(normal['checks'].keys()-expected)
        receipt['status']='PASS' if normal['exitCode']==0 and normal['complete'] and not normal['missing'] and not normal['extra'] and not normal['failed'] else 'FAIL'
        if receipt['status']=='PASS' and not args.corrections_only:
            movement=out/'native-frame-movement';movement.mkdir();shutil.copy2(GAME/'stdlib.lua',movement/'stdlib.lua')
            command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(movement),'-cp',str(classes)+os.pathsep+cp,'MetalEnclosureNativeProbe',str(GAME),'--frame-movement']
            with (movement/'output.log').open('w',encoding='utf-8') as log:done=subprocess.run(command,cwd=movement,stdout=log,stderr=subprocess.STDOUT,timeout=90)
            output=(movement/'output.log').read_text(encoding='utf-8',errors='replace');checks=dict(re.findall(r'^METAL ([a-zA-Z0-9_]+)=(true|false)$',output,re.M))
            receipt['frameMovement']={'command':command,'exitCode':done.returncode,'checks':checks,'log':str(movement/'output.log'),'complete':'ENCLOSURE COMPLETE' in output}
            if done.returncode or len(checks)!=12 or any(value!='true' for value in checks.values()):receipt['status']='FAIL'
        if receipt['status']=='PASS' and not args.no_controls and args.corrections_only:
            for name,file,old,new,target,scope in [
                ('eligible-before-private-cap','planner.lua','if index>128 then break end','if index>15 then break end','ordinary_controller_mixed_stream_preserves_new_native_family','P.planDoubleGate'),
                ('retained-before-provider-cap','production.lua','if not retained or retained.site and retained.site.key==acquired.key then','if true then','retained_native_boundary_filters_before_provider_capacity','R.boundaryOptions'),
                ('canonical-gap-retirement','perception.lua','local b=store(id);local site=b.boundarySites and b.boundarySites[row.site.key]','local b=store(id);local site=nil','fence_canonical_build_retires_exact_acquired_gap','P.consumeBoundarySite'),
            ]:
                variant=dict(captured);variant[file]=metal.replace_contract(variant[file],old,new,scope)
                result=execute(out/('control-'+name),variant,classes,'__runEnclosureCorrections();print("ENCLOSURE COMPLETE")');result.update(name=name,target=target,landed=variant[file]!=captured[file])
                result['detected']=result['exitCode']==0 and result['complete'] and result['checks'].get(target)=='false';receipt['controls'].append(result)
                if not result['detected']:receipt['status']='FAIL'
        if receipt['status']=='PASS' and not args.no_controls and not args.corrections_only:
            variant=dict(captured);old='rt.previous=(policy.kind=="wall" or policy.kind=="window-frame") and observed or nil';new='rt.previous=policy.kind=="wall" and observed or nil'
            variant['production.lua']=metal.replace_contract(variant['production.lua'],old,new)
            result=execute(out/'control-window-predecessor',variant,classes,'__runEnclosureFrames();print("ENCLOSURE COMPLETE")')
            result.update(name='window-native-predecessor',landed=old!=new,target='family1_N_native_payment_and_grade');result['detected']=result['exitCode']==0 and result['complete'] and result['checks'].get(result['target'])=='false'
            receipt['controls'].append(result)
            if not result['detected']:receipt['status']='FAIL'
            for name,old,new,target,scope in [
                ('boundary-current-standing','if site.mode=="double-gate" or site.mode=="fence" or site.mode=="single-gate" then return gate.permission(id,site,current) end','if site.mode=="double-gate" or site.mode=="fence" or site.mode=="single-gate" then return current or gate.permission(id,site,current) end','boundary_current_standing_revocation_prevents_native_payment','shelter.permission'),
                ('boundary-actual-learning','if not shelter.learned(rt.policy.recipe,body) then return false end','if false then return false end','boundary_actual_knowledge_revocation_prevents_native_payment','shelter.bound'),
            ]:
                variant=dict(captured);variant['production.lua']=metal.replace_contract(variant['production.lua'],old,new,scope)
                result=execute(out/('control-'+name),variant,classes,'__runEnclosureGuards();print("ENCLOSURE COMPLETE")')
                result.update(name=name,landed=old!=new,target=target);result['detected']=result['exitCode']==0 and result['complete'] and result['checks'].get(target)=='false'
                receipt['controls'].append(result)
                if not result['detected']:receipt['status']='FAIL'
            directory=out/'control-native-observer';directory.mkdir()
            # Find the exact existing shell-postupdate forwarding owner by name, not list order.
            sourcePath=ROOT/'java/src/com/sao/engine/SAOShelterConstruction.java';source=sourcePath.read_text(encoding='utf-8-sig')
            old='SAOEnclosureEdge.observePassage(body);';variantSource=metal.replace_contract(source,old,'')
            path=directory/'SAOShelterConstruction.java';path.write_text(variantSource,encoding='utf-8');override=directory/'classes';override.mkdir()
            command=[str(JDK/'javac.exe'),'-cp',str(classes)+os.pathsep+cp,'-d',str(override),str(path)]
            done=subprocess.run(command,capture_output=True,text=True,timeout=60);(directory/'compile.log').write_text(done.stdout+done.stderr,encoding='utf-8')
            result=execute(directory/'native',captured,classes,'__runEnclosureGateUses();print("ENCLOSURE COMPLETE")',override) if done.returncode==0 else {'exitCode':-1,'complete':False,'checks':{}}
            target='single7_N_same_body_physical_passage';result.update(name='native-shell-passage-observer',target=target,landed=source!=variantSource,compileCommand=command,compileExit=done.returncode)
            result['detected']=done.returncode==0 and result['exitCode']==0 and result['complete'] and result['checks'].get(target)=='false';receipt['controls'].append(result)
            if not result['detected']:receipt['status']='FAIL'

            directory=out/'control-frame-movement';directory.mkdir();path=directory/'SAOMovement.java'
            sourcePath=ROOT/'java/src/com/sao/engine/SAOMovement.java';source=sourcePath.read_text(encoding='utf-8-sig')
            old='IsoThumpable frame = current.getWindowTo(next) == null ? current.getWindowThumpableTo(next) : null;'
            variant=metal.replace_contract(source,old,'IsoThumpable frame = null;');path.write_text(variant,encoding='utf-8');override=directory/'classes';override.mkdir()
            command=[str(JDK/'javac.exe'),'-cp',str(classes)+os.pathsep+cp,'-d',str(override),str(path)];done=subprocess.run(command,capture_output=True,text=True,timeout=60)
            (directory/'compile.log').write_text(done.stdout+done.stderr,encoding='utf-8');native=directory/'native';native.mkdir();shutil.copy2(GAME/'stdlib.lua',native/'stdlib.lua')
            runCommand=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(native),'-cp',str(override)+os.pathsep+str(classes)+os.pathsep+cp,'MetalEnclosureNativeProbe',str(GAME),'--frame-movement']
            if done.returncode==0:
                with (native/'output.log').open('w',encoding='utf-8') as log:executed=subprocess.run(runCommand,cwd=native,stdout=log,stderr=subprocess.STDOUT,timeout=90)
                output=(native/'output.log').read_text(encoding='utf-8',errors='replace');checks=dict(re.findall(r'^METAL ([a-zA-Z0-9_]+)=(true|false)$',output,re.M))
                result={'exitCode':executed.returncode,'checks':checks,'complete':'ENCLOSURE COMPLETE' in output,'command':runCommand,'log':str(native/'output.log')}
            else:result={'exitCode':-1,'checks':{},'complete':False}
            target='frame_route1_N_native_window_state_admitted';result.update(name='native-window-frame-climb-path',target=target,landed=source!=variant,compileCommand=command,compileExit=done.returncode)
            result['detected']=done.returncode==0 and result['exitCode']==0 and result['complete'] and result['checks'].get(target)=='false';receipt['controls'].append(result)
            if not result['detected']:receipt['status']='FAIL'

    receipt['sourcePreserved']=all(metal.digest(Path(p))==sha for p,sha in before.items())
    if not receipt['sourcePreserved']:receipt['status']='FAIL'
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(receipt['status'],out/'receipt.json');return 0 if receipt['status']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
