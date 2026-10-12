#!/usr/bin/env python3
"""D3.15 installed native movable-window producer joined to its SAO consumer."""
from __future__ import annotations
import argparse,json,os,re,shutil,subprocess
from pathlib import Path
import d3_metal_enclosure_test as enclosure
metal,common=enclosure.metal,enclosure.common
ROOT,GAME,JDK=metal.ROOT,metal.GAME,metal.JDK
PROBE=ROOT/'tools/resource_production_checks/MetalEnclosureWindowNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/metal_enclosure_window_cases.lua'
NATIVE=[GAME/'media/lua/shared/Moveables'/name for name in ['ISMoveableDefinitions.lua','ISMoveableSpriteProps.lua','ISMoveablesAction.lua']]+[GAME/'media/lua/shared/TimedActions/ISOpenCloseWindow.lua']
CONTROLS=[
 ('exact-native-payment','production.lua','rt.itemConsumed=not rt.inventory:contains(rt.item) and not craftCarried(rt.body,rt.itemId,rt.itemType)','rt.itemConsumed=true','unpaid_native_window_cannot_earn_installation','Guards',None),
 ('native-inserted-window','production.lua','rt.windowCreated=SAOJavaBridge:worldShelterGlazed(rt.body,rt.frame,object,rt.placedSprite,rt.site.face=="N")==true','rt.windowCreated=true','absent_native_window_cannot_earn_installation','Guards',None),
 ('current-standing-at-window-effect','production.lua','or not shelter.permission(rt.id,rt.site,true)','or false','current_standing_blocks_native_glazing_effect','Guards','shelter.glazeBound'),
 ('exact-window-purpose-item','production.lua','or step.itemId~=w.itemId','or false','foreign_step_item_identity_refuses_current_action','Guards','shelter.glazePurpose'),
 ('saved-exact-window-retirement','production.lua','local ok,retired=pcall(a._SAOPlumbRetireSaved,rec,w);if not ok or not retired then return false end','local ok,retired=true,true','saved_exact_queue_retires_without_native_credit','Guards','shelter.glazeRecover'),
 ('independent-window-feedback','models.lua','if e.kind~="animal-care" and e.kind~="window-installation" and','if e.kind~="animal-care" and','grade1_N_independent_feedback_and_unfinished_recovery','Install',None),
 ('native-window-consumer-reader','production.lua','local door=step.site.mode=="window" and SAOJavaBridge:worldShelterWindow(body,step.site.key,step.site.revision) or step.site.mode=="door" and SAOJavaBridge:worldShelterDoor(body,step.site.key,step.site.revision)','local door=SAOJavaBridge:worldShelterDoor(body,step.site.key,step.site.revision)','grade1_N_ordinary_window_use_keeps_original_purpose','Install',None),
]
CORRECTION_CONTROLS=[
 ('new-window-reading-whitelist','SAO_Study.lua',',MetalWindowFrameLvl1=true','', 'reading_window_ordinary_context_discovers_exact_native_manual','NewReading',None),
 ('new-boundary-reading-whitelist','SAO_Study.lua',',MetalPoleFenceGate=true','', 'reading_boundary_ordinary_context_discovers_exact_native_manual','NewReading',None),
 ('missing-tool-keeps-carried-window','production.lua','if props.isMoveable and props.type=="Window" and not props.isMultiSprite','if props.isMoveable and props.type=="Window" and not props.isMultiSprite and (not props.placeTool or props:hasTool(body,"place"))', 'ordinary_context_retains_exact_window_when_native_hammer_missing','ToolAcquisition','R.windowGlazingOptions'),
 ('ordinary-controller-placing-tool-source','controller.lua','elseif offer.item.placeToolAvailable==false then','elseif false then', 'ordinary_context_discovers_exact_private_native_placing_tool','ToolAcquisition','Ctl.shelterConstructionContext'),
 ('original-shelter-purpose-after-tool-transfer','planner.lua','if accepted and completed and (purpose.shelterConstruction or purpose.gateAccess) and purpose.status=="completed" then','if false then', 'canonical_tool_acquisition_retires_only_original_claim','ToolAcquisition','P.consumeSourceResult'),
 ('ordinary-controller-window-dispatch','controller.lua',' and step.productionKind~="glaze-shelter-window"','', 'acquired_placing_tool_continues_exact_original_window_installation','ToolAcquisition','Ctl.tryShelterConstruction'),
]
def chunks():
    sources=enclosure.chunks()
    sources['window-ports.lua']=CASES.read_text(encoding='utf-8-sig').split('local R,P,Ctl,N',1)[0]
    for index,path in enumerate(NATIVE):sources['native-window-'+str(index)+'.lua']=path.read_text(encoding='utf-8-sig')
    buildutil=(GAME/'media/lua/server/BuildingObjects/ISBuildUtil.lua').read_text(encoding='utf-8-sig')
    sources['native-window-buildutil.lua']='function buildUtil.setHaveConstruction('+buildutil.split('function buildUtil.setHaveConstruction(',1)[1].split('\nfunction ',1)[0]
    sources['window-cases.lua']='local R,P,Ctl,N'+CASES.read_text(encoding='utf-8-sig').split('local R,P,Ctl,N',1)[1]
    if os.environ.get('SAO_WINDOW_DEBUG'):
        sources['production.lua']=sources['production.lua'].replace('if nativeEntityKind(receipt.kind) then return collector.outcome(id, receipt) end','if nativeEntityKind(receipt.kind) then print("OUTCOME_DISPATCH",receipt.kind);return collector.outcome(id, receipt) end')
        sources['production.lua']=sources['production.lua'].replace('return collector.copy(row)\nend\nfunction shelter.glazeClose','local result=collector.copy(row);print("GLAZE_OUTCOME_COPY",result);return result\nend\nfunction shelter.glazeClose')
        source=sources['production.lua'];head,tail=source.split('function shelter.glazeOutcome(',1);body,end=tail.split('function shelter.glazeClose(',1)
        for index,line in enumerate(body.splitlines()):
            if 'return nil' in line:body=body.replace(line,line.replace('return nil',f'print("OUTCOME_REFUSED_{index}");return nil'),1)
        sources['production.lua']=head+'function shelter.glazeOutcome('+body+'function shelter.glazeClose('+end
        sources['production.lua']=sources['production.lua'].replace('local ok,result=pcall(complete,self)','local ok,result=pcall(complete,self);if not ok then print("NATIVE_COMPLETION_ERROR",result) end')
        sources['production.lua']=sources['production.lua'].replace('if not shelter.glazeIdentity(id,w) then return false end;rt.work,rt.workId=w,w.id','if not shelter.glazeIdentity(id,w) then for k,v in pairs(w) do print("BAD_IDENTITY",k,v) end;for k,v in pairs(w.site)do print("BAD_SITE",k,v) end;return false end;rt.work,rt.workId=w,w.id')
        source=sources['production.lua'];head,tail=source.split('function shelter.glazeBegin(',1);body,end=tail.split('function shelter.glazeRecover(',1)
        for index,line in enumerate(body.splitlines()):
            if 'then return false end' in line:body=body.replace(line,line.replace('then return false end',f'then print("GLAZE_REFUSED_{index}");return false end'),1)
        sources['production.lua']=head+'function shelter.glazeBegin('+body+'function shelter.glazeRecover('+end
    return sources

def correction_chunks():
    sources=chunks()
    ctl=common.CONTROLLER.read_text(encoding='utf-8-sig')
    section='function Ctl.doubleGateContext('+ctl.split('function Ctl.doubleGateContext(',1)[1].split('function Ctl.tryWindowRepair(',1)[0]
    if 'function Ctl.doubleGateContext(' not in sources['controller.lua']:sources['controller.lua']+='\n'+section
    out={}
    for name,source in sources.items():
        if name=='SAO_SourceUse.lua':out['native-correction-transfer.lua']=(GAME/'media/lua/shared/TimedActions/ISTransferAction.lua').read_text(encoding='utf-8-sig')
        out[name]=source
    return out

def execute(out,sources,classes,run,override=None):
    out.mkdir();shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua');paths=[]
    for name,source in {**sources,'run.lua':run+';print("WINDOW COMPLETE")'}.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    cp=os.pathsep.join(map(str,[*([override] if override else []),classes,GAME/'projectzomboid.jar',ROOT/'mod/42.20/media/java/SAO.jar',GAME/'ZombieBuddy.jar']))
    command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),'-cp',cp,'MetalEnclosureWindowNativeProbe',str(GAME),*paths]
    with (out/'output.log').open('w',encoding='utf-8') as stream:
        try:done=subprocess.run(command,cwd=out,stdout=stream,stderr=subprocess.STDOUT,timeout=180)
        except subprocess.TimeoutExpired:done=subprocess.CompletedProcess(command,124)
    output=(out/'output.log').read_text(encoding='utf-8',errors='replace');pairs=re.findall(r'^WINDOW ([a-zA-Z0-9_]+)=(true|false)$',output,re.M)
    return {'command':command,'exitCode':done.returncode,'checks':dict(pairs),'failed':[k for k,v in pairs if v!='true'],'complete':'WINDOW COMPLETE' in output,'log':str(out/'output.log'),'logSha256':metal.digest(out/'output.log')}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--required',action='store_true');parser.add_argument('--no-controls',action='store_true');parser.add_argument('--guards-only',action='store_true');parser.add_argument('--correction-only',action='store_true');parser.add_argument('--chooser-only',action='store_true');parser.add_argument('--reading-only',action='store_true');parser.add_argument('--tool-only',action='store_true');args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False);classes=out/'classes';classes.mkdir()
    owned=[Path(__file__),PROBE,CASES,Path(enclosure.__file__),Path(metal.__file__),Path(common.__file__),enclosure.PROBE,enclosure.CASES,metal.PROBE,common.PROBE,common.CASES,common.CTL_CASES,common.BASE,common.BOARD,common.PLUMB,metal.READER,*enclosure.JAVA,*common.LEAVES.values(),*metal.EXTRA,common.CONTROLLER,ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',ROOT/'tools/luacheck/LuaSyntax.java']
    installed=[*NATIVE,*common.NATIVE,*common.SCRIPTS,*metal.DEFS,*metal.NATIVE,GAME/'media/lua/server/BuildingObjects/ISBuildUtil.lua',GAME/'media/lua/shared/defines.lua',GAME/'media/scripts/generated/items/moveable.txt',GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe']
    installed += [GAME/f'media/scripts/generated/entities/walls/{name}.txt' for name in ['entity_metal_windowframelvl1','entity_metal_windowframelvl2','entity_metal_fencelvl1','entity_metal_fencelvl2','entity_metal_bigmetalfence','entity_metal_bigwirefence','entity_metal_smallpolelfence','entity_metal_smallwirefence','entity_metal_polefencegate','entity_metal_polefencegatesmall','entity_metal_wirefencegate','entity_metal_wirefencegatesmall']]
    if args.correction_only or args.tool_only:installed.append(GAME/'media/lua/shared/TimedActions/ISTransferAction.lua')
    pins={str(p):metal.digest(p) for p in owned+installed}
    cp=os.pathsep.join(map(str,[GAME/'projectzomboid.jar',ROOT/'mod/42.20/media/java/SAO.jar',GAME/'ZombieBuddy.jar']))
    command=[str(JDK/'javac.exe'),'-cp',cp,'-d',str(classes),str(PROBE),str(metal.PROBE),str(common.PROBE),str(ROOT/'tools/luacheck/MovementCrossingProbe.java'),str(ROOT/'tools/luacheck/ResourceApproachProbe.java'),str(ROOT/'tools/luacheck/LuaSyntax.java'),*map(str,enclosure.JAVA)]
    compiled=subprocess.run(command,capture_output=True,text=True,timeout=90);(out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    receipt={'status':'FAIL','sourcePins':pins,'compile':{'command':command,'exitCode':compiled.returncode,'log':str(out/'compile.log')},'controls':[]}
    if compiled.returncode==0:
        captured=correction_chunks() if args.correction_only or args.chooser_only or args.reading_only or args.tool_only else chunks()
        run='__runWindowToolAcquisition()' if args.tool_only else '__runWindowChooser()' if args.chooser_only else '__runWindowNewReading()' if args.reading_only else '__runWindowCorrection()' if args.correction_only else '__runWindowGuards()' if args.guards_only else '__runWindowInstall();__runWindowGuards()'
        receipt['normal']=execute(out/'normal',captured,classes,run);normal=receipt['normal']
        source=CASES.read_text(encoding='utf-8-sig');base=source.split('function __runWindowChooser()',1)[0];expected=set(re.findall(r"check\('([a-z0-9_]+)'",base))
        if args.correction_only or args.chooser_only or args.reading_only or args.tool_only:
            tail=source.split('function __runWindowChooser()',1)[1]
            expected={f'chooser_{face}_{name}' for face in ['N','W'] for name in re.findall(r"check\('chooser_'\.\.face\.\.'_([a-z0-9_]+)'",tail)}
            if args.reading_only:expected=set()
            if not args.chooser_only:expected|={name for name in re.findall(r"check\('([a-z0-9_]+)'",tail) if name not in {'chooser_','reading_'}} if not args.reading_only else {f'reading_{kind}_{name}' for kind in ['window','boundary'] for name in re.findall(r"check\('reading_'\.\.kind\.\.'_([a-z0-9_]+)'",tail)}
            if args.correction_only:expected|={f'reading_{kind}_{name}' for kind in ['window','boundary'] for name in re.findall(r"check\('reading_'\.\.kind\.\.'_([a-z0-9_]+)'",tail)}
            if args.tool_only:expected=set(re.findall(r"check\('([a-z0-9_]+)'",source.split('function __runWindowToolAcquisition()',1)[1]))
        elif not args.guards_only:expected|={f'grade{grade}_{face}_{name}' for grade in [1,2] for face in ['N','W'] for name in re.findall(r"check\(prefix\.\.'([a-z0-9_]+)'",source)}
        normal['missing']=sorted(expected-normal['checks'].keys());normal['extra']=sorted(normal['checks'].keys()-expected)
        receipt['status']='PASS' if normal['exitCode']==0 and normal['complete'] and normal['checks'] and not normal['failed'] and not normal['missing'] and not normal['extra'] else 'FAIL'
        if receipt['status']=='PASS' and not args.no_controls and (args.correction_only or args.chooser_only or args.reading_only or args.tool_only):
            mutations=[c for c in CORRECTION_CONTROLS if args.correction_only or args.reading_only and c[5]=='NewReading' or args.tool_only and c[5]=='ToolAcquisition']
            for name,file,old,new,target,group,scope in mutations:
                variant=dict(captured);before=variant[file];variant[file]=metal.replace_contract(before,old,new,scope)
                result=execute(out/('control-'+name),variant,classes,'__runWindow'+group+'()')
                result.update(name=name,target=target,mutationMatches=1,landed=before!=variant[file],sourcePreimageSha256=__import__('hashlib').sha256(before.encode()).hexdigest(),sourceMutantSha256=__import__('hashlib').sha256(variant[file].encode()).hexdigest())
                result['detected']=result['exitCode']==0 and result['complete'] and result['checks'].get(target)=='false';receipt['controls'].append(result);print('CONTROL',name,result['detected'],flush=True)
            if args.correction_only or args.chooser_only:
                source=(ROOT/'java/src/com/sao/engine/SAOMovement.java').read_text(encoding='utf-8-sig')
                old='IsoObject hoppable = current.getWindowTo(next) == null ? current.getHoppableTo(next) : null;';new='IsoObject hoppable = current.getHoppableTo(next);'
                mutant=metal.replace_contract(source,old,new)
                mutant=metal.replace_contract(mutant,'if (hoppable == null && current.getWindowTo(next) == null) {','if (hoppable == null) {')
                directory=out/'control-native-glazing-before-hoppable';directory.mkdir();path=directory/'SAOMovement.java';path.write_text(mutant,encoding='utf-8');override=directory/'classes';override.mkdir()
                command=[str(JDK/'javac.exe'),'-cp',str(classes)+os.pathsep+cp,'-d',str(override),str(path)];built=subprocess.run(command,capture_output=True,text=True,timeout=90);(directory/'compile.log').write_text(built.stdout+built.stderr,encoding='utf-8')
                result=execute(directory/'native',captured,classes,'__runWindowChooser()',override) if built.returncode==0 else {'exitCode':-1,'complete':False,'checks':{}}
                result.update(name='native-glazing-before-hoppable',target='chooser_N_closed_glazing_chooses_window_opening',compileExit=built.returncode,compileCommand=command,mutationMatches=2,landed=source!=mutant,sourcePreimageSha256=__import__('hashlib').sha256(source.encode()).hexdigest(),sourceMutantSha256=metal.digest(path))
                result['detected']=built.returncode==0 and result['exitCode']==0 and result['complete'] and result['checks'].get(result['target'])=='false';receipt['controls'].append(result);print('CONTROL native-glazing-before-hoppable',result['detected'],flush=True)
            if not receipt['controls'] or not all(c['landed'] and c['detected'] for c in receipt['controls']):receipt['status']='FAIL'
        if receipt['status']=='PASS' and not args.no_controls and not (args.correction_only or args.chooser_only or args.reading_only or args.tool_only):
            for name,file,old,new,target,group,scope in CONTROLS:
                if args.guards_only and group!='Guards':continue
                variant=dict(captured);before=variant[file];variant[file]=metal.replace_contract(before,old,new,scope)
                result=execute(out/('control-'+name),variant,classes,'__runWindow'+group+'()')
                result.update(name=name,target=target,mutationMatches=1,landed=before!=variant[file],sourcePreimageSha256=__import__('hashlib').sha256(before.encode()).hexdigest(),sourceMutantSha256=__import__('hashlib').sha256(variant[file].encode()).hexdigest())
                result['detected']=result['exitCode']==0 and result['complete'] and result['checks'].get(target)=='false'
                receipt['controls'].append(result);print('CONTROL',name,result['detected'],flush=True)
                (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
            if not receipt['controls'] or not all(c['landed'] and c['detected'] for c in receipt['controls']):receipt['status']='FAIL'
    receipt['sourcePreserved']=all(metal.digest(Path(p))==sha for p,sha in pins.items())
    if not receipt['sourcePreserved']:receipt['status']='FAIL'
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print(receipt['status'],out/'receipt.json');return 0 if receipt['status']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
