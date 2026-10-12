#!/usr/bin/env python3
"""Owned pane startup/factory/supply and changed action consumers, installed VM.

No shipping build: compile only owned registration/probe classes into evidence.
Historical fixtures remain immutable; generated adaptation binds them to the
new actual producer and labels the changed pre-wrapper missing-pane behavior.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
sys.dont_write_bytecode = True
import window_repair_test as legacy
import d3_window_preparation_test as preparation

ROOT=Path(__file__).resolve().parent.parent
GAME=legacy.GAME
JDK=legacy.JDK
WORKSHOP=legacy.WORKSHOP
LUA=ROOT/'mod/42.20/media/lua'
ACTION=LUA/'shared/SAO_WindowPaneAction.lua'
MENU=LUA/'client/SAO_WindowPaneMenu.lua'
SOURCES=LUA/'shared/SAO_WindowPaneSources.lua'
DEFINITIONS=ROOT/'java/src/com/sao/engine/SAOWindowPaneDefinitions.java'
WEAVE=ROOT/'java/src/com/sao/agent/SAOWindowPaneDefinitionWeave.java'
PROBE=ROOT/'tools/window_pane_checks/WindowPaneNativeProbe.java'
AGENT=ROOT/'tools/window_pane_checks/WindowPaneStartupAgent.java'
EFFECT_PROBE=ROOT/'tools/window_pane_checks/WindowPaneEffectProbe.java'
EFFECT_CASES=ROOT/'tools/window_pane_checks/native_effect_cases.lua'
HUMAN_CASES=ROOT/'tools/window_pane_checks/human_menu_cases.lua'
MOVEMENT_PROBE=ROOT/'tools/luacheck/MovementCrossingProbe.java'
JAR=ROOT/'mod/42.20/media/java/SAO.jar'
def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def run(command,cwd,log):
    command=[str(p) for p in command]
    if 'WindowPaneNativeProbe' in command or 'WindowPaneEffectProbe' in command:
        command.insert(1,'-Dsao.paneFixtureCache='+str(log.parent/'native-cache'/log.stem))
    start=time.monotonic()
    done=subprocess.run(command,cwd=cwd,capture_output=True,text=True,timeout=120)
    log.write_text(done.stdout+done.stderr,encoding='utf-8')
    return {'command':[str(p) for p in command],'cwd':str(cwd),'exitCode':done.returncode,
            'elapsedSeconds':round(time.monotonic()-start,3),'log':str(log),'logSha256':digest(log)}
def lua_execute(out,parts,classes,expected):
    out.mkdir();paths=[]
    (out/'stdlib.lua').write_bytes((GAME/'stdlib.lua').read_bytes())
    for name,text in parts.items():
        path=out/name;path.write_text(text,encoding='utf-8');paths.append(path)
    result=run([JDK/'java.exe','-cp',f'{classes};{GAME / "projectzomboid.jar"}',
                'WindowRepairNativeProbe',*paths],out,out/'output.log')
    checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',(out/'output.log').read_text()))
    result.update(checks=checks,failed=sorted(k for k,v in checks.items() if v!='true'),missing=sorted(expected-checks.keys()),extra=sorted(checks.keys()-expected))
    return result
def adapt(text):
    return text.replace('RepairableWindowsAddWindowAction','SAOWindowPaneAction').replace('AddWindowAction.complete','SAO.WindowPaneAction.complete')
def fixture():
    value=adapt(legacy.FIXTURE.read_text(encoding='utf-8-sig'))
    value=value.replace("if name=='RepairableWindows/AddWindowAction' then return SAOWindowPaneAction end",
        "if name=='SAO_WindowPaneAction' then return SAO.WindowPaneAction end\n    if name=='RepairableWindows/AddWindowAction' then error('optional mod absent') end")
    value=value.replace('function w:getSquare() return self.sq end','function w:getSquare() return self.sq end\n    function w:isBarricaded() return self.barricaded==true end')
    old="check('installed_missing_pane_completes_before_material',original:complete()==true\n        and not old.window.smashed and old.window.synced==1)"
    new="check('owned_missing_pane_refuses_before_effect',original:complete()==false\n        and old.window.smashed and old.window.synced==nil)"
    if value.count(old)!=1:raise ValueError('historical pre-wrapper case boundary changed')
    value=value.replace(old,new)
    # Earlier human callback fixtures did not enqueue their explicit completion.
    # The new owner requires its actual current native queue before payment.
    value=re.sub(r'\b([A-Za-z_][A-Za-z_0-9]*):complete\(\)',r'__nativeWindowComplete(\1)',value)
    helper='''function __nativeWindowComplete(action)
    local q=ISTimedActionQueue.getTimedActionQueue(action.character)
    if q.current==nil and #q.queue==0 and action._SAOWindowRepairBinding~=false then ISTimedActionQueue.add(action) end
    return action:complete()
end
'''
    return value.replace('function __runWindowCases()',helper+'function __runWindowCases()')
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path);parser.add_argument('--required',action='store_true');args=parser.parse_args()
    native=[p for p in legacy.NATIVE if p!=legacy.ACTION]
    inputs=[Path(__file__),Path(legacy.__file__),Path(preparation.__file__),ACTION,MENU,SOURCES,DEFINITIONS,WEAVE,PROBE,AGENT,EFFECT_PROBE,EFFECT_CASES,HUMAN_CASES,MOVEMENT_PROBE,JAR,
        ROOT/'java/src/com/sao/agent/SAOAgent.java',legacy.W,legacy.P,legacy.C,legacy.I,legacy.COGNITION,legacy.MODELS,
        legacy.FIXTURE,legacy.LEARNING,legacy.DISPOSAL,legacy.STOP,legacy.PROBE,preparation.CASES,*native,
        *preparation.NATIVE[4:6],GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',GAME/'stdlib.lua',
        GAME/'media/lua/client/TimedActions/WalkToTimedAction.lua',legacy.ACTION,WORKSHOP/'media/lua/client/RepairableWindows/ContextMenu.lua',
        GAME/'media/scripts/generated/items/normal.txt',GAME/'media/scripts/generated/items/drainable.txt',GAME/'media/scripts/generated/timedactions.txt',
        WORKSHOP/'mod.info',WORKSHOP/'media/scripts/RepairableWindows/items.txt',WORKSHOP/'media/scripts/RepairableWindows/recipes.txt',
        JDK/'java.exe',JDK/'javac.exe',JDK/'jar.exe',LUA/'shared/Translate/EN/ItemName.json',LUA/'shared/Translate/EN/ContextMenu.json',LUA/'shared/Translate/EN/Recipes.json']
    missing=[str(p) for p in inputs if not p.is_file()]
    if missing:
        owned_missing=[p for p in inputs if p.is_relative_to(ROOT) and not p.is_file()]
        print(('FAIL' if owned_missing or args.required else 'UNOBSERVABLE')+' owned pane exact inputs absent: '+', '.join(missing))
        return 1 if owned_missing or args.required else 0
    temporary=tempfile.TemporaryDirectory(prefix='sao-owned-window-pane-') if args.out is None else None
    out=Path(temporary.name)/'proof' if temporary else args.out.resolve()
    if out.exists():raise ValueError('refuse replacing prior evidence')
    out.mkdir(parents=True);classes=out/'classes';classes.mkdir()
    pins={str(p):digest(p) for p in inputs};cp=f'{GAME / "projectzomboid.jar"};{GAME / "ZombieBuddy.jar"};{JAR}'
    compiled=run([JDK/'javac.exe','-cp',cp,'-d',classes,DEFINITIONS,WEAVE,PROBE,AGENT,legacy.PROBE,EFFECT_PROBE,MOVEMENT_PROBE],ROOT,out/'compile.log')
    if compiled['exitCode']:print((out/'compile.log').read_text());return 1
    manifest=out/'manifest.txt';manifest.write_text('Manifest-Version: 1.0\nPremain-Class: WindowPaneStartupAgent\nCan-Retransform-Classes: true\nCan-Redefine-Classes: true\n\n')
    agentjar=out/'startup-probe.jar';pack=run([JDK/'jar.exe','--create','--file',agentjar,'--manifest',manifest,'-C',classes,'WindowPaneStartupAgent.class','-C',classes,'com/sao'],ROOT,out/'package-probe.log')
    if pack['exitCode']:return 1
    registrations=[]
    for mode in ['absent','inactive','equal','conflict','optional']:
        result=run([JDK/'java.exe','--enable-native-access=ALL-UNNAMED',f'-javaagent:{agentjar}','-cp',f'{classes};{cp}',
            'WindowPaneNativeProbe',GAME,mode,WORKSHOP,ROOT/'mod/42.20'],GAME,out/f'registration-{mode}.log')
        result['mode']=mode;result['checks']=dict(re.findall(r'CHECK ([a-z0-9_]+)=(true|false)',(out/f'registration-{mode}.log').read_text()));registrations.append(result)
    expected=legacy.EXPECTED-{'installed_missing_pane_completes_before_material'}|{'owned_missing_pane_refuses_before_effect'}
    parts={'fixture.lua':fixture()}
    parts.update({f'native-{i}.lua':p.read_text(encoding='utf-8-sig') for i,p in enumerate(native)})
    parts['owned-sources.lua']=SOURCES.read_text(encoding='utf-8-sig')
    parts['owned-action.lua']=ACTION.read_text(encoding='utf-8-sig')
    parts.update({'models.lua':legacy.MODELS.read_text(encoding='utf-8-sig'),'cognition.lua':legacy.COGNITION.read_text(encoding='utf-8-sig'),
        'planner.lua':legacy.P.read_text(encoding='utf-8-sig'),'repair.lua':legacy.W.read_text(encoding='utf-8-sig'),
        'controller.lua':legacy.controller(legacy.C.read_text(encoding='utf-8-sig')),
        'learning.lua':adapt(legacy.LEARNING.read_text(encoding='utf-8-sig')),'disposal.lua':adapt(legacy.DISPOSAL.read_text(encoding='utf-8-sig')),
        'stop.lua':adapt(legacy.STOP.read_text(encoding='utf-8-sig')),
        'run.lua':'__runWindowCases()\n__runWindowLifecycle()\n__runWindowLearning()\n__setupWindowDisposal()\n__observeWindowDisposal()\n__finishWindowDisposal()\n__runWindowStopCustody()'})
    action=lua_execute(out/'action',parts,classes,expected)
    prep=adapt(preparation.CASES.read_text(encoding='utf-8-sig'));prep_expected=set(re.findall(r"check\('([a-z0-9_]+)',",prep))|{f'prep_{kind}_{phase}' for kind in ('death','transfer','world') for phase in ('queue_absence_is_not_ack','late_ack_retires')}
    prep_parts={'base.lua':fixture().split('function __runWindowCases()',1)[0],'cases.lua':prep}
    prep_native=native+preparation.NATIVE[4:6]
    prep_parts.update({f'native-{i}.lua':p.read_text(encoding='utf-8-sig') for i,p in enumerate(prep_native)})
    prep_parts.update({'owned-sources.lua':SOURCES.read_text(encoding='utf-8-sig'),'owned-action.lua':ACTION.read_text(encoding='utf-8-sig'),'planner.lua':legacy.P.read_text(encoding='utf-8-sig'),
        'repair.lua':legacy.W.read_text(encoding='utf-8-sig'),'run.lua':'__runWindowPreparationCases()\n__setupWindowRecoveryCases()',
        'fresh-owned-action.lua':ACTION.read_text(encoding='utf-8-sig'),'fresh-repair.lua':legacy.W.read_text(encoding='utf-8-sig'),'recovery-run.lua':'__runWindowRecoveryCases()'})
    prepared=lua_execute(out/'preparation',prep_parts,classes,prep_expected)
    controls=[]
    for name,file,old,new,verdict in [
        ('material-owner','repair.lua','if not b or b.preparing or self.character ~= b.body or self.window ~= b.window or b.spent or b.cancelled or not bound(b, true, false) or not self.window:isSmashed() then','if not b then','changed_body_cannot_mutate'),
        ('native-payment','owned-action.lua','inventory:Remove(material)','do end','native_complete_measured'),
        ('native-effect','owned-action.lua','self.window:setSmashed(false)','do end','native_complete_measured'),
        ('private-owner','cognition.lua','or receipt.nativeOwner ~= "SAO.WindowPaneAction.complete" and receipt.nativeOwner ~= "AddWindowAction.complete"','or true','window_completion_private_join')]:
        altered=dict(parts)
        if old not in altered[file]:raise ValueError('control seam missing '+name)
        altered[file]=altered[file].replace(old,new)
        result=lua_execute(out/f'control-{name}',altered,classes,expected);result.update(name=name,verdict=verdict,detected=result['checks'].get(verdict)=='false');controls.append(result)
    menus=[]
    for optional in [False,True]:
        menu_parts={'base.lua':fixture().split('function __runWindowCases()',1)[0],'human-cases.lua':HUMAN_CASES.read_text()}
        menu_parts.update({f'native-{i}.lua':p.read_text(encoding='utf-8-sig') for i,p in enumerate(native+preparation.NATIVE[4:6]+[GAME/'media/lua/client/TimedActions/WalkToTimedAction.lua'])})
        if optional:menu_parts.update({'optional-action.lua':legacy.ACTION.read_text(encoding='utf-8-sig'),'capture-optional.lua':'__optional=RepairableWindowsAddWindowAction'})
        menu_parts.update({'owned-sources.lua':SOURCES.read_text(),'owned-action.lua':ACTION.read_text(),'repair.lua':legacy.W.read_text(),
            'human-menu.lua':MENU.read_text()})
        if optional:menu_parts['optional-context.lua']=(WORKSHOP/'media/lua/client/RepairableWindows/ContextMenu.lua').read_text()
        menu_parts.update({'run.lua':'__runPaneMenu()','reload-menu.lua':MENU.read_text(),'reload-check.lua':'__paneMenuReloadReceipt()'})
        prefix='optional' if optional else 'standalone'
        wanted={prefix+'_'+suffix for suffix in ['normal_one_repair_entry','normal_native_walk_and_owned_repair','normal_guarded_repair_start','normal_native_completion','normal_queue_terminal','replaced_queue_complete_refuses','barricaded_entry_disabled','barricaded_queue_refuses','missing_material_no_entry']}|{'owned_menu_reload_has_one_callback'}
        if optional:wanted|={'optional_original_removal_entry_retained','optional_original_removal_owner_retained','optional_new_and_global_use_owned_producer'}
        result=lua_execute(out/f'menu-{prefix}',menu_parts,classes,wanted);result['mode']=prefix;menus.append(result)
        if not optional:
            altered=dict(menu_parts);old='if ISTimedActionQueue.getTimedActionQueue(b.body) ~= b.queue\n            or b.queue.current ~= self or b.queue:indexOf(self) ~= 1 then';altered['repair.lua']=altered['repair.lua'].replace(old,'if false then')
            control=lua_execute(out/'control-current-queue',altered,classes,wanted);control.update(name='current-queue',verdict='standalone_replaced_queue_complete_refuses',detected=control['checks'].get('standalone_replaced_queue_complete_refuses')=='false');controls.append(control)
    effect=run([JDK/'java.exe','--enable-native-access=ALL-UNNAMED',f'-javaagent:{agentjar}','-cp',f'{classes};{cp}',
        'WindowPaneEffectProbe',GAME,WORKSHOP,ROOT/'mod/42.20',ROOT,ACTION],GAME,out/'native-effect.log')
    effect['checks']=dict(re.findall(r'CHECK ([a-z0-9_]+)=(true|false)',(out/'native-effect.log').read_text()))
    for name,old,new,verdict in [('native-glass-order','self.window:setGlassRemoved(false)\n    self.window:setSmashed(false)','self.window:setSmashed(false)\n    self.window:setGlassRemoved(false)','native_closed_navigation_refresh'),
        ('native-one-payment','inventory:Remove(material)','inventory:Remove(material)\n    inventory:Remove(inventory:getFirstType(PANE))','native_closed_exact_one_payment')]:
        altered=out/(name+'.lua');text=ACTION.read_text()
        if text.count(old)!=1:raise ValueError('native effect control boundary changed: '+name)
        altered.write_text(text.replace(old,new))
        control=run([JDK/'java.exe','--enable-native-access=ALL-UNNAMED',f'-javaagent:{agentjar}','-cp',f'{classes};{cp}',
            'WindowPaneEffectProbe',GAME,WORKSHOP,ROOT/'mod/42.20',ROOT,altered],GAME,out/(name+'.log'))
        control['checks']=dict(re.findall(r'CHECK ([a-z0-9_]+)=(true|false)',(out/(name+'.log')).read_text()));control.update(name=name,verdict=verdict,detected=control['checks'].get(verdict)=='false');controls.append(control)
    after={str(p):digest(p) for p in inputs}
    receipt={'status':'PASS' if all(r['exitCode']==0 and r['checks'] and all(v=='true' for v in r['checks'].values()) for r in registrations)
        and not action['failed'] and not action['missing'] and action['exitCode']==0 and not prepared['failed'] and not prepared['missing'] and prepared['exitCode']==0
        and all(m['exitCode']==0 and not m['failed'] and not m['missing'] for m in menus) and effect['exitCode']==0 and len(effect['checks'])>=40 and all(v=='true' for v in effect['checks'].values())
        and all(c['detected'] for c in controls) and pins==after else 'FAIL',
        'sourcePins':pins,'inputStable':pins==after,'compile':compiled,'scratchAgentPackage':pack,'registrations':registrations,'action':action,'preparation':prepared,'menus':menus,'nativeEffect':effect,'controls':controls,
        'boundary':'Production startup weave and native loaders/factory/item serialization; installed action/queue and full existing owner functions over controlled actor/map/time/native dispatch. Loaded multiplayer/rendering/human clicks unobserved. Shipping JAR untouched.'}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(receipt['status']+' owned pane: registration='+str(sum(len(r['checks']) for r in registrations))+' action='+str(len(action['checks']))+' prep='+str(len(prepared['checks']))+' controls='+str(sum(c['detected'] for c in controls)))
    for label,r in [('action',action),('preparation',prepared)]:
        if r['failed'] or r['missing']:print(label+' failed='+str(r['failed'])+' missing='+str(r['missing']))
    return 0 if receipt['status']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())
