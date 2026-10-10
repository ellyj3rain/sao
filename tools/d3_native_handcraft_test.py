#!/usr/bin/env python3
"""Installed SawLogs recipe/effects and guarded SAO native action lifecycle.

Uses real installed Java recipe/material plumbing, Lua action/queue/transfer,
Kahlua serialization and SAO planning/cognitive leaves. Actor/map/dispatch and
sound/UI receivers are controlled; no attached game or installation changes.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA = ROOT / 'mod/42.20/media/lua'
PRODUCTION = LUA / 'client/SAO_ResourceProduction.lua'
PLANNER = LUA / 'shared/SAO_ProceduralPlanning.lua'
COGNITION = LUA / 'shared/SAO_Cognition.lua'
MODELS = LUA / 'shared/SAO_CognitiveModels.lua'
EXPERIENCE = LUA / 'client/SAO_CapabilityExperience.lua'
BASE = ROOT / 'tools/luacheck/window_repair_cases.lua'
BOARD = ROOT / 'tools/luacheck/d3_native_boarding_cases.lua'
CASES = ROOT / 'tools/luacheck/d3_native_handcraft_cases.lua'
PROBE = ROOT / 'tools/luacheck/HandcraftNativeProbe.java'
NATIVE = [GAME / 'media/lua/shared/ISBaseObject.lua',
          GAME / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
          GAME / 'media/lua/client/TimedActions/ISTimedActionQueue.lua',
          GAME / 'media/lua/shared/TimedActions/ISEquipWeaponAction.lua',
          GAME / 'media/lua/client/TimedActions/ISInventoryTransferAction.lua',
          GAME / 'media/lua/shared/Entity/TimedActions/ISHandcraftAction.lua']
SCRIPTS = [GAME / 'media/scripts/generated/recipes/recipes_carpentry.txt',
           GAME / 'media/scripts/generated/timedactions.txt',
           GAME / 'media/scripts/generated/items/normal.txt',
           GAME / 'media/scripts/generated/items/weapon.txt']

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def execute(out: Path, sources: dict[str, str], classes: Path, expected: set[str]) -> dict:
    out.mkdir()
    shutil.copy2(GAME / 'stdlib.lua', out / 'stdlib.lua')
    paths=[]
    for name, source in sources.items():
        path=out / name;path.write_text(source, encoding='utf-8');paths.append(str(path))
    command=[str(JDK / 'java.exe'),'--enable-native-access=ALL-UNNAMED',f'-Duser.home={out}',
             '-cp',f"{GAME / 'projectzomboid.jar'};{classes}",'HandcraftNativeProbe',str(GAME),*paths]
    done=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=90)
    output=done.stdout+done.stderr;(out / 'output.log').write_text(output,encoding='utf-8')
    checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',output))
    return {'exitCode':done.returncode,'checks':checks,'failed':sorted(k for k,v in checks.items() if v!='true'),
            'missing':sorted(expected-checks.keys()),'extra':sorted(checks.keys()-expected),
            'logSha256':digest(out / 'output.log')}

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path);parser.add_argument('--required',action='store_true')
    args=parser.parse_args()
    owned=[Path(__file__),PRODUCTION,PLANNER,COGNITION,MODELS,EXPERIENCE,BASE,BOARD,CASES,PROBE]
    installed=[*NATIVE,*SCRIPTS,GAME / 'projectzomboid.jar',GAME / 'stdlib.lua',JDK / 'java.exe',JDK / 'javac.exe',JDK / 'javap.exe']
    missing_owned=[str(p) for p in owned if not p.is_file()]
    if missing_owned:print('FAIL missing owned inputs: '+', '.join(missing_owned));return 1
    missing_native=[str(p) for p in installed if not p.is_file()]
    if missing_native:
        print(('FAIL' if args.required else 'UNOBSERVABLE')+' installed handcraft inputs absent: '+', '.join(missing_native))
        return 1 if args.required else 0
    temp=tempfile.TemporaryDirectory(prefix='sao-native-handcraft-') if args.out is None else None
    out=Path(temp.name) / 'proof' if temp else args.out.resolve()
    if out.exists():raise ValueError('refuse replacing previous proof')
    out.mkdir(parents=True)
    inputs=owned+installed;before={str(p):digest(p) for p in inputs}
    api=subprocess.run([str(JDK / 'javap.exe'),'-classpath',str(GAME / 'projectzomboid.jar'),
         'zombie.entity.components.crafting.recipe.CraftRecipeManager','zombie.entity.components.crafting.recipe.CraftRecipeData',
         'zombie.entity.components.crafting.BaseCraftingLogic','zombie.entity.components.crafting.recipe.HandcraftLogic'],
         capture_output=True,text=True,timeout=90)
    (out / 'native-api.txt').write_text(api.stdout+api.stderr,encoding='utf-8')
    native_api=api.returncode==0 and all(s in api.stdout for s in (
         'hasPlayerLearnedRecipe','hasPlayerRequiredSkill','setManualInputsFor','setManualSelectInputs',
         'getAllRecordedConsumedItems','getAllCreatedItems','performCurrentRecipe'))
    classes=out / 'classes';classes.mkdir()
    compiled=subprocess.run([str(JDK / 'javac.exe'),'-cp',str(GAME / 'projectzomboid.jar'),'-d',str(classes),str(PROBE)],
                            capture_output=True,text=True,timeout=90)
    (out / 'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    if compiled.returncode:print(compiled.stdout+compiled.stderr);return 1
    cases=CASES.read_text(encoding='utf-8-sig');expected=set(re.findall(r"check\('([a-z0-9_]+)'",cases))
    sources={'base.lua':BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()',1)[0]}
    sources['boarding-fixture.lua']=BOARD.read_text(encoding='utf-8-sig')+'\n__boardingFixture=fixture;__boardingItem=item;__boardingInventory=inventory\n'
    sources.update({f'native-{i}.lua':p.read_text(encoding='utf-8-sig') for i,p in enumerate(NATIVE[:5])})
    sources['native-4.lua']+='\nlocal capturedTransfer=ISInventoryTransferAction.perform;function ISInventoryTransferAction:perform() local ok,value=pcall(capturedTransfer,self);if not ok then print("native transfer error "..tostring(value));error(value) end;return value end\n'
    sources['cases.lua']=cases;sources['native-handcraft.lua']=NATIVE[-1].read_text(encoding='utf-8-sig')
    sources['native-handcraft.lua']+='\nfor _,key in ipairs({"start","perform","performRecipe"}) do local captured=ISHandcraftAction[key]; ISHandcraftAction[key]=function(self) local ok,value=pcall(captured,self);if not ok then print("native "..key.." error "..tostring(value));error(value) end;return value end end\n'
    sources.update({'models.lua':MODELS.read_text(encoding='utf-8-sig'),'cognition.lua':COGNITION.read_text(encoding='utf-8-sig'),
                    'planner.lua':PLANNER.read_text(encoding='utf-8-sig'),'production.lua':PRODUCTION.read_text(encoding='utf-8-sig'),
                    'experience.lua':EXPERIENCE.read_text(encoding='utf-8-sig'),'run.lua':'__runHandcraftCases()'})
    normal=execute(out / 'normal',sources,classes,expected)
    controls=[]
    mutations=[
        ('post-craft-output-custody-bound','production.lua',
         'craftCarried(rt.body,id,"Base.Plank",514)',
         'craftCarried(rt.body,id,"Base.Plank",512)',
         'native_512_inputs_complete_514_held'),
        ('craft-fact-authority','cognition.lua','supplied.kind=="material-crafting" or ',
         '', 'generic_craft_fact_requires_native_owner'),
        ('window-fact-authority','cognition.lua','supplied.kind=="window-repair" or ',
         '', 'generic_window_fact_requires_native_owner'),
        ('native-end','production.lua','return ok and ended==true','return true','perform_before_native_end_refuses'),
        ('callback-ownership','production.lua','or not c.performing or not craftCurrent(c)','or false or not craftCurrent(c)','direct_recipe_callback_refuses'),
        ('material-binding','production.lua','if materials then','if false then','same_id_replacement_and_floor_refuse'),
        ('native-ack','production.lua','or c.action.action and not c.ack','or false','queue_absence_is_not_native_ack'),
        ('synchronous-stop-ack','production.lua',
         'return rt.closed==true or craftClose(rt,"interrupted",rt.cancelReason)',
         'return craftClose(rt,"interrupted",rt.cancelReason)',
         'synchronous_native_stop_returns_acknowledged'),
        ('premature-stop-ack','production.lua',
         'return rt.closed==true or craftClose(rt,"interrupted",rt.cancelReason)',
         'return true',
         'pending_native_stop_remains_unacknowledged'),
        ('saved-admission','production.lua','or a.correlationId~=work.id','or false','stale_saved_admission_refuses'),
        ('raw-saved-record','production.lua',
         'local rec=SAO.Identity.get(id)\n    local work=rec and rec.resourceProductionWork\n    if not work then return true end',
         'local rec=owner(id,body)\n    local work=rec and rec.resourceProductionWork\n    if not work then return true end',
         'saved_pending_transfer_waits_ack'),
        ('transfer-cosmetic-cleanup','production.lua','pcall(function() self:stopLoopingSound() end)',
         'pcall(function() return true end)','native_transfer_cleanup_before_ack'),
        ('replacement-cosmetic-ownership','production.lua','if owned and craftCurrent(c) then','if true then','replacement_queue_cosmetics_preserved'),
        ('native-payment-measurement','production.lua','rt.paymentMeasured=consumed:contains(rt.log)',
         'rt.paymentMeasured=true','missing_exact_native_consumption_no_credit'),
        ('saved-geometry-binding','production.lua',
         'or work.entryKey~=rt.entryKey or work.x~=rt.square:getX() or work.y~=rt.square:getY() or work.z~=rt.square:getZ()',
         'or work.entryKey~=rt.entryKey or false','changed_saved_geometry_refuses'),
    ]
    for name,filename,old,new,detector in mutations:
        variant=dict(sources);count=variant[filename].count(old)
        if count!=1:controls.append({'name':name,'detected':False,'mutationMatches':count});continue
        variant[filename]=variant[filename].replace(old,new,1)
        result=execute(out / name,variant,classes,expected)
        result.update(name=name,detector=detector,detected=result['exitCode']==0 and result['checks'].get(detector)=='false')
        controls.append(result)
    after={str(p):digest(p) for p in inputs}
    passed=native_api and normal['exitCode']==0 and not normal['failed'] and not normal['missing'] and not normal['extra'] and before==after and all(c['detected'] for c in controls)
    receipt={'schema':'sao-d3-native-handcraft-proof/1','status':'PASS' if passed else 'FAIL','sourcePins':before,
             'sourcePreserved':before==after,'normal':normal,'controls':controls,
             'nativeApi':{'verified':native_api,'exitCode':api.returncode,'outputSha256':digest(out / 'native-api.txt')},
             'boundary':'Installed native recipe/input/output definitions, CraftRecipe/HandcraftLogic/CraftRecipeData/ItemUser material effects, Lua native action/queue/transfers, Kahlua persistence and actual SAO planner/cognitive leaves; controlled unattached actor, map, action dispatch, XP receiver, sound/UI/network. Input script ResearchableRecipes removed only for unrelated UI registry bootstrap; translation display names controlled. No loaded game.'}
    (out / 'receipt.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    print(f"D3 native handcraft {'PASS' if passed else 'FAIL'}: {len(normal['checks'])}/{len(expected)} cases; {sum(c['detected'] for c in controls)}/{len(controls)} controls")
    if not passed:
        print(normal);print([(c['name'],c.get('detected'),c.get('mutationMatches')) for c in controls])
        print((out / 'normal/output.log').read_text(encoding='utf-8')[-7000:])
    print(f'receipt {out / "receipt.json"}')
    if temp:temp.cleanup()
    return 0 if passed else 1

if __name__=='__main__':raise SystemExit(main())
