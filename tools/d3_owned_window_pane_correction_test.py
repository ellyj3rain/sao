#!/usr/bin/env python3
"""Bounded eligible-root-pane repair and genuine historical owner replay.

Historical receipt is emitted by committed WindowRepair with the installed
foreign action, serialized, then consumed by current owners. No old-owner
literal substitution is used. New producer/unchanged native physical proof
remains the qualification04 packet; only affected owner contracts run here.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys,tempfile
sys.dont_write_bytecode=True
import d3_owned_window_pane_test as pane
ROOT=pane.ROOT
OWNER=ROOT/'tools/window_pane_checks/owner_correction_cases.lua'
LEGACY=ROOT/'tools/window_pane_checks/legacy_replay_cases.lua'
HISTORICAL_REPAIR_COMMIT='a5f801125e7c685158841bc7cf1ebbbadb867dd2'
HISTORICAL_REPAIR_PATH='mod/42.20/media/lua/client/SAO_WindowRepair.lua'
HISTORICAL_REPAIR_SHA256='44612f4c0d3d3fa85d72166fa425d9e1d7c6750c9dcf7631e78ac00d53473fad'
def read(path):return path.read_text(encoding='utf-8-sig')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def named(source):
    import re
    return set(re.findall(r"check\('([a-z0-9_]+)'",source))
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path);parser.add_argument('--required',action='store_true');args=parser.parse_args()
    legacy=pane.legacy
    native=[p for p in legacy.NATIVE if p!=legacy.ACTION]
    owned=[Path(__file__),Path(pane.__file__),Path(legacy.__file__),OWNER,LEGACY,pane.ACTION,pane.SOURCES,legacy.W,legacy.P,legacy.COGNITION,legacy.MODELS,legacy.FIXTURE,legacy.PROBE]
    installed=[*native,legacy.ACTION,pane.GAME/'projectzomboid.jar',pane.GAME/'stdlib.lua',pane.JDK/'java.exe',pane.JDK/'javac.exe']
    missing=[str(p) for p in owned+installed if not p.is_file()]
    if missing:
        strict=args.required or any(not p.is_file() for p in owned)
        print(('FAIL' if strict else 'UNOBSERVABLE')+' pane correction inputs absent '+', '.join(missing));return 1 if strict else 0
    historical_command=['git','--no-optional-locks','show',HISTORICAL_REPAIR_COMMIT+':'+HISTORICAL_REPAIR_PATH]
    captured=subprocess.run(historical_command,cwd=ROOT,capture_output=True)
    if captured.returncode:
        print(('FAIL' if args.required else 'UNOBSERVABLE')+' pane correction historical source unavailable '+HISTORICAL_REPAIR_COMMIT)
        return 1 if args.required else 0
    historical=captured.stdout.decode('utf-8-sig').replace('\r\n','\n')
    if hashlib.sha256(historical.encode()).hexdigest()!=HISTORICAL_REPAIR_SHA256:
        print('FAIL pane correction historical source hash differs');return 1
    temporary=tempfile.TemporaryDirectory(prefix='sao-pane-correction-') if args.out is None else None
    out=Path(temporary.name)/'proof' if temporary else args.out.resolve()
    if out.exists():raise ValueError('refuse replacing original proof')
    out.mkdir(parents=True);classes=out/'classes';classes.mkdir()
    pins={str(p):digest(p) for p in owned+installed}
    compiled=pane.run([pane.JDK/'javac.exe','-cp',pane.GAME/'projectzomboid.jar','-d',classes,legacy.PROBE],ROOT,out/'compile.log')
    if compiled['exitCode']:print((out/'compile.log').read_text());return 1
    common={'base.lua':pane.fixture().split('function __runWindowCases()',1)[0]}
    common.update({f'native-{i}.lua':read(p) for i,p in enumerate(native)})
    common.update({'sources.lua':read(pane.SOURCES),'action.lua':read(pane.ACTION),'models.lua':read(legacy.MODELS),
        'cognition.lua':read(legacy.COGNITION),'planner.lua':read(legacy.P),'repair.lua':read(legacy.W),
        'correction-cases.lua':read(OWNER),'run.lua':'__runPaneOwnerCorrections()'})
    expected=named(read(OWNER))
    owner=pane.lua_execute(out/'owner',common,classes,expected)
    old_lookup='b.inventory:getFirstTypeEval(PANE, availablePane) ~= b.pane'
    assert common['repair.lua'].count(old_lookup)==1
    altered=dict(common);altered['repair.lua']=altered['repair.lua'].replace(old_lookup,'b.inventory:getFirstType(PANE) ~= b.pane')
    restored=pane.lua_execute(out/'restored-old-binding',altered,classes,expected)
    restored.update(name='restored-old-root-binding',verdict='human_root_reserved_first_free_second_admits',detected=restored['checks'].get('human_root_reserved_first_free_second_admits')=='false' and restored['checks'].get('npc_root_reserved_first_free_second_admits')=='false')
    original_base=read(legacy.FIXTURE).split('function __runWindowCases()',1)[0]
    original_base=original_base.replace("function require(name)","function require(name)\n    if name=='SAO_WindowPaneAction' then return SAO.WindowPaneAction end")
    authentic={'historical-base.lua':original_base}
    authentic.update({f'native-{i}.lua':read(p) for i,p in enumerate(native+[legacy.ACTION])})
    authentic.update({'models.lua':read(legacy.MODELS),'cognition.lua':read(legacy.COGNITION),'planner.lua':read(legacy.P),
        'legacy-cases.lua':read(LEGACY),'historical-repair.lua':historical,'produce-legacy.lua':'__produceAuthenticLegacyPaneOutcome()',
        'current-sources.lua':read(pane.SOURCES),'current-action.lua':read(pane.ACTION),'current-repair.lua':read(legacy.W),
        'replay-legacy.lua':'__replayAuthenticLegacyPaneOutcome()'})
    legacy_expected=named(read(LEGACY))
    replay=pane.lua_execute(out/'genuine-legacy-replay',authentic,classes,legacy_expected)
    controls=[restored]
    for name,file,old,new,verdict in [
        ('legacy-reader-owner','current-repair.lua','row.nativeOwner ~= OWNED_OWNER and row.nativeOwner ~= LEGACY_OWNER','row.nativeOwner ~= OWNED_OWNER','legacy_current_reader_accepts_saved_owner'),
        ('legacy-private-receiver','cognition.lua','receipt.nativeOwner ~= "SAO.WindowPaneAction.complete" and receipt.nativeOwner ~= "AddWindowAction.complete"','receipt.nativeOwner ~= "SAO.WindowPaneAction.complete"','legacy_current_learning_delivers_once')]:
        parts=dict(authentic)
        if old not in parts[file]:raise ValueError('legacy control boundary absent '+name)
        parts[file]=parts[file].replace(old,new)
        result=pane.lua_execute(out/name,parts,classes,legacy_expected);result.update(name=name,verdict=verdict,detected=result['checks'].get(verdict)=='false');controls.append(result)
    stable=all(digest(Path(p))==value for p,value in pins.items())
    passed=stable and all(r['exitCode']==0 and not r['failed'] and not r['missing'] for r in [owner,replay]) and all(c['detected'] for c in controls)
    receipt={'status':'PASS' if passed else 'FAIL','sourcePins':pins,'inputStable':stable,'compile':compiled,
        'historicalSource':{'head':HISTORICAL_REPAIR_COMMIT,'path':HISTORICAL_REPAIR_PATH,'capturedTextSha256':hashlib.sha256(historical.encode()).hexdigest(),'captureCommand':historical_command},
        'rootOwner':owner,'genuineLegacyReplay':replay,'controls':controls,
        'boundary':'Installed native VM/action/queue and real native legacy effect receivers; controlled root inventories/body/map/clock for eligible shadow cases. Legacy owner actually emitted by committed historical adapter/installed action, native table save/reload, current owner/private receivers. No global legacy-owner substitution, source/JAR/build/game/save/index mutation.'}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(receipt['status']+' pane correction owner='+str(len(owner['checks']))+' genuineLegacy='+str(len(replay['checks']))+' controls='+str(sum(c['detected'] for c in controls)))
    if not passed:
        for label,result in [('owner',owner),('legacy',replay)]:print(label,result['failed'],result['missing'])
    return 0 if passed else 1
if __name__=='__main__':raise SystemExit(main())
