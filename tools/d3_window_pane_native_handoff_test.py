#!/usr/bin/env python3
"""Normal Main self-attach and installed perform-before-complete handoff.

No special pane javaagent. Compile changed startup/probe classes only into
scratch. Actual native dispatch uses a real initialized player receiver;
private owner actor/geometry/time remain explicitly controlled.
"""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,tempfile
sys.dont_write_bytecode=True
import d3_owned_window_pane_test as pane
ROOT=pane.ROOT
MAIN=ROOT/'java/src/com/sao/Main.java'
PROBE=ROOT/'tools/window_pane_checks/WindowPaneLifecycleProbe.java'
CASES=ROOT/'tools/window_pane_checks/native_lifecycle_cases.lua'
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return p.read_text(encoding='utf-8-sig')
def execute_lua(out,parts,classes,expected):
    out.mkdir();paths=[]
    for name,text in parts.items():
        path=out/name;path.write_text(text,encoding='utf-8');paths.append(path)
    result=pane.run([pane.JDK/'java.exe','--enable-native-access=ALL-UNNAMED',f'-Duser.home={out / "home"}',f'-Dsao.paneFixtureCache={out / "cache"}','-cp',f'{classes};{pane.JAR};{pane.GAME / "projectzomboid.jar"}',
        'WindowPaneLifecycleProbe',*paths],pane.GAME,out/'output.log')
    checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',(out/'output.log').read_text()))
    result.update(checks=checks,failed=sorted(k for k,v in checks.items() if v!='true'),missing=sorted(expected-checks.keys()));return result
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path);parser.add_argument('--required',action='store_true');args=parser.parse_args()
    legacy=pane.legacy;native=[p for p in legacy.NATIVE if p!=legacy.ACTION]
    owned=[Path(__file__),Path(pane.__file__),Path(legacy.__file__),MAIN,pane.WEAVE,pane.DEFINITIONS,pane.PROBE,PROBE,CASES,pane.MOVEMENT_PROBE,pane.JAR,
        pane.ACTION,pane.SOURCES,legacy.W,legacy.P,legacy.COGNITION,legacy.MODELS,legacy.FIXTURE]
    installed=[*native,pane.GAME/'projectzomboid.jar',pane.GAME/'ZombieBuddy.jar',pane.GAME/'stdlib.lua',
        pane.GAME/'media/scripts/generated/items/normal.txt',pane.GAME/'media/scripts/generated/items/drainable.txt',pane.GAME/'media/scripts/generated/timedactions.txt',
        pane.WORKSHOP/'media/scripts/RepairableWindows/items.txt',pane.WORKSHOP/'media/scripts/RepairableWindows/recipes.txt',pane.JDK/'java.exe',pane.JDK/'javac.exe']
    if any(not p.is_file() for p in owned+installed):
        strict=args.required or any(not p.is_file() for p in owned);print('FAIL' if strict else 'UNOBSERVABLE');return 1 if strict else 0
    temp=tempfile.TemporaryDirectory(prefix='sao-pane-handoff-') if args.out is None else None
    out=Path(temp.name)/'proof' if temp else args.out.resolve()
    if out.exists():raise ValueError('refuse replacing earlier receipt')
    out.mkdir(parents=True);classes=out/'classes';classes.mkdir();pins={str(p):digest(p) for p in owned+installed}
    cp=f'{pane.JAR};{pane.GAME / "projectzomboid.jar"};{pane.GAME / "ZombieBuddy.jar"}'
    compiled=pane.run([pane.JDK/'javac.exe','-cp',cp,'-d',classes,MAIN,pane.WEAVE,pane.DEFINITIONS,pane.PROBE,PROBE,pane.MOVEMENT_PROBE],ROOT,out/'compile.log')
    if compiled['exitCode']:print((out/'compile.log').read_text());return 1
    mains=[]
    for mode in ['absent','inactive']:
        result=pane.run([pane.JDK/'java.exe','--enable-native-access=ALL-UNNAMED',f'-Duser.home={out / (mode+"-home")}',
            '-Dsao.paneNormalMain=true','-cp',f'{classes};{cp}','WindowPaneNativeProbe',pane.GAME,mode,pane.WORKSHOP,ROOT/'mod/42.20'],pane.GAME,out/(mode+'-Main.log'))
        result['mode']=mode;result['checks']=dict(re.findall(r'CHECK ([a-z0-9_]+)=(true|false)',(out/(mode+'-Main.log')).read_text()));mains.append(result)
    base=pane.fixture().split('function __runWindowCases()',1)[0]
    parts={'base.lua':base};parts.update({f'native-{i}.lua':read(p) for i,p in enumerate(native)})
    parts.update({'sources.lua':read(pane.SOURCES),'action.lua':read(pane.ACTION),'models.lua':read(legacy.MODELS),'cognition.lua':read(legacy.COGNITION),'planner.lua':read(legacy.P),'repair.lua':read(legacy.W),
        'settings.lua':"local data={}\nModData={get=function(k)return data[k]end,getOrCreate=function(k)data[k]=data[k] or {};return data[k]end}\nSAO.Identity.all=function()return __records end\nSAO.Cognition.configure(.5,12,3)",
        'cases.lua':read(CASES),'run.lua':'__runNativePaneLifecycle()'})
    expected={name for name in re.findall(r"check\('([a-z0-9_]+)'",read(CASES)) if not name.endswith('_')}
    expected|={kind+'_'+suffix for kind in ['human','npc'] for suffix in ['native_perform_retires_before_effect','native_perform_retains_binding','native_complete_exact_payment','native_complete_retires_capsule','native_late_replay_inert','native_legitimate_successor_started','native_successor_preserved_after_effect','native_late_callbacks_preserve_successor']}
    expected|={'native_after_perform_'+kind+'_refuses_effect' for kind in ['queue','material','body','death','transfer','cancel']}
    lifecycle=execute_lua(out/'lifecycle',parts,classes,expected)
    controls=[]
    for name,file,old,new,verdict in [
        ('early-human-release','repair.lua','b.retirementCurrent, b.retirementFirst, b.retirementLength = b.queue.current, b.queue.queue[1], #b.queue.queue',
         'if not b.work then releaseBinding(self, b) end\n        b.retirementCurrent, b.retirementFirst, b.retirementLength = b.queue.current, b.queue.queue[1], #b.queue.queue','human_native_complete_exact_payment'),
        ('old-current-completion','repair.lua','b.queue:indexOf(self) ~= -1 or b.queue.current ~= b.retirementCurrent','b.queue:indexOf(self) ~= 1 or b.queue.current ~= self','npc_native_complete_exact_payment'),
        ('retained-queue-custody','repair.lua','or b.performFailed or ISTimedActionQueue.getTimedActionQueue(b.body) ~= b.queue','or b.performFailed or false','native_after_perform_queue_refuses_effect'),
        ('native-end','repair.lua','not nativeEnded(self) or not bound(b, true, false)','false or not bound(b, true, false)','native_early_perform_refuses'),
        ('successor-flags','action.lua','self.character:setIsFarming(false)\n    ISTimedActionQueue.getTimedActionQueue(self.character):onCompleted(self)',
         'ISTimedActionQueue.getTimedActionQueue(self.character):onCompleted(self)\n    self.character:setIsFarming(false)','human_native_legitimate_successor_started')]:
        altered=dict(parts)
        if altered[file].count(old)!=1:raise ValueError('landed control boundary changed '+name)
        altered[file]=altered[file].replace(old,new)
        result=execute_lua(out/name,altered,classes,expected);result.update(name=name,verdict=verdict,detected=result['checks'].get(verdict)=='false');controls.append(result)
    main_control=out/'omitted-Main-install';main_control.mkdir();control_classes=main_control/'classes';control_classes.mkdir()
    omitted=main_control/'Main.java';original=read(MAIN);line='        com.sao.agent.SAOWindowPaneDefinitionWeave.install();\n'
    if original.count(line)!=1:raise ValueError('Main omission boundary changed')
    omitted.write_text(original.replace(line,''),encoding='utf-8')
    cc=pane.run([pane.JDK/'javac.exe','-cp',f'{classes};{cp}','-d',control_classes,omitted],ROOT,main_control/'compile.log')
    if cc['exitCode']:raise ValueError('Main control compilation failed')
    result=pane.run([pane.JDK/'java.exe','--enable-native-access=ALL-UNNAMED',f'-Duser.home={main_control / "home"}',
        '-Dsao.paneNormalMain=true','-cp',f'{control_classes};{classes};{cp}','WindowPaneNativeProbe',pane.GAME,'absent',pane.WORKSHOP,ROOT/'mod/42.20'],pane.GAME,main_control/'output.log')
    result['checks']=dict(re.findall(r'CHECK ([a-z0-9_]+)=(true|false)',(main_control/'output.log').read_text()));result.update(name='omitted-normal-Main-install',verdict='owned_or_preserved_pane',detected=result['checks'].get('owned_or_preserved_pane')=='false');controls.append(result)
    stable=all(digest(p)==h for p,h in pins.items())
    receipt={'status':'PASS' if stable and all(m['exitCode']==0 and all(v=='true' for v in m['checks'].values()) for m in mains) and lifecycle['exitCode']==0 and not lifecycle['failed'] and not lifecycle['missing'] and all(c['detected'] for c in controls) else 'FAIL',
        'sourcePins':pins,'inputStable':stable,'compile':compiled,'normalMain':mains,'nativeLifecycle':lifecycle,'controls':controls,
        'boundary':'Actual Main invoked reflectively without special pane agent, normal self-attach, isolated user.home/cache and existing dedicated renderer branch. Actual native LuaTimedActionNew dispatch/native receiver; owning actor/map/perception/time controlled. No game/UI/save/ship build.'}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(receipt['status']+' Main '+str(sum(len(m['checks']) for m in mains))+' lifecycle '+str(len(lifecycle['checks'])))
    if receipt['status']!='PASS':print(lifecycle['failed'],lifecycle['missing']);print((out/'lifecycle/output.log').read_text()[-2000:])
    return 0 if receipt['status']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
