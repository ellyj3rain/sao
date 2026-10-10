#!/usr/bin/env python3
"""D3.5 installed collector recipes/build actions/factory and exact SAO ownership.

Private VM outputs; actor/map/dispatch/UI receivers are controlled. Actual Java
weather/supplier geometry is qualified by the material owner's companion proof.
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

ROOT=Path(__file__).resolve().parent.parent
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA=ROOT/'mod/42.20/media/lua'
PROBE=ROOT/'tools/resource_production_checks/RainCollectorNativeProbe.java'
CASES=ROOT/'tools/resource_production_checks/rain_collector_cases.lua'
BASE=ROOT/'tools/luacheck/window_repair_cases.lua'
BOARD=ROOT/'tools/luacheck/d3_native_boarding_cases.lua'
PLUMB=ROOT/'tools/resource_production_checks/plumbing_cases.lua'
LEAVES={k:LUA/f'{area}/SAO_{name}.lua' for k,area,name in [
    ('sources','shared','WorldSources'),('perception','shared','Perception'),
    ('models','shared','CognitiveModels'),('cognition','shared','Cognition'),('labor','shared','Labor'),
    ('planner','shared','ProceduralPlanning'),('production','client','ResourceProduction'),
    ('experience','client','CapabilityExperience')]}
NATIVE=[GAME/p for p in [
    'media/lua/shared/ISBaseObject.lua','media/lua/shared/TimedActions/ISBaseTimedAction.lua',
    'media/lua/client/TimedActions/ISTimedActionQueue.lua','media/lua/shared/TimedActions/ISEquipWeaponAction.lua',
    'media/lua/client/TimedActions/ISInventoryTransferAction.lua','media/lua/shared/TimedActions/ISPlumbItem.lua',
    'media/lua/shared/TimedActions/ISTakeWaterAction.lua','media/lua/server/BuildingObjects/ISBuildingObject.lua',
    'media/lua/server/BuildingObjects/ISBuildIsoEntity.lua','media/lua/client/BuildingObjects/TimedActions/ISBuildAction.lua']]
SCRIPTS=[GAME/p for p in ['media/scripts/generated/entities/outdoors/entity_raincollector.txt',
    'media/scripts/generated/entities/outdoors/entity_raincollector_tarp.txt',
    'media/scripts/generated/items/normal.txt','media/scripts/generated/items/container.txt',
    'media/scripts/generated/items/weapon.txt','media/scripts/generated/timedactions.txt']]

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def sources():
    chunks={'base.lua':BASE.read_text(encoding='utf-8-sig').split('function __runWindowCases()',1)[0],
        'boarding-fixture.lua':BOARD.read_text(encoding='utf-8-sig')+
        '\n__boardingFixture=fixture;__boardingItem=item;__boardingInventory=inventory\n'}
    chunks.update({f'native-{i}.lua':p.read_text(encoding='utf-8-sig') for i,p in enumerate(NATIVE)})
    chunks['plumbing-fixture.lua']=PLUMB.read_text(encoding='utf-8-sig').split('function __runPlumbingControl',1)[0]+'\n__plumbingFixture=fixture\n'
    chunks['rain-fixture.lua']=CASES.read_text(encoding='utf-8-sig')
    chunks.update({name+'.lua':p.read_text(encoding='utf-8-sig') for name,p in LEAVES.items()})
    return chunks

def execute(out,chunks,classes,expected):
    out.mkdir()
    shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua')
    paths=[]
    for name,source in chunks.items():
        p=out/name;p.write_text(source,encoding='utf-8');paths.append(str(p))
    command=[str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),
        '-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar'),'RainCollectorNativeProbe',str(GAME),*paths]
    done=subprocess.run(command,cwd=out,text=True,capture_output=True,timeout=90)
    log=out/'output.log';log.write_text(done.stdout+done.stderr,encoding='utf-8')
    checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',done.stdout))
    return {'exitCode':done.returncode,'checks':checks,'failed':sorted(k for k,v in checks.items() if v!='true'),
        'missing':sorted(expected-checks.keys()),'extra':sorted(checks.keys()-expected),'logSha256':digest(log)}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path);parser.add_argument('--required',action='store_true')
    parser.add_argument('--native-preflight',action='store_true')
    args=parser.parse_args()
    owned=[Path(__file__),PROBE,CASES,BASE,BOARD,PLUMB,*LEAVES.values(),ROOT/'tools/luacheck/LuaSyntax.java']
    missing=[str(p) for p in owned if not p.is_file()]
    if missing:print('FAIL mandatory owned collector inputs absent: '+', '.join(missing));return 1
    installed=[*NATIVE,*SCRIPTS,GAME/'projectzomboid.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe']
    missing=[str(p) for p in installed if not p.is_file()]
    if missing:
        print(('FAIL required' if args.required else 'UNCHECKED')+' installed collector runtime absent: '+', '.join(missing))
        return 1 if args.required else 0
    temporary=tempfile.TemporaryDirectory(prefix='sao-native-collector-') if args.out is None else None
    out=Path(temporary.name)/'proof' if temporary else args.out.resolve()
    if out.exists():raise ValueError('refuse replacing previous native proof')
    out.mkdir(parents=True)
    inputs=owned+installed;before={str(p):digest(p) for p in inputs}
    classes=out/'classes';classes.mkdir()
    compiled=subprocess.run([str(JDK/'javac.exe'),'-cp',str(GAME/'projectzomboid.jar'),'-d',str(classes),
        str(PROBE),str(ROOT/'tools/luacheck/LuaSyntax.java')],text=True,capture_output=True,timeout=60)
    (out/'compile.log').write_text(compiled.stdout+compiled.stderr,encoding='utf-8')
    if compiled.returncode:print(compiled.stderr);return 1
    syntax=subprocess.run([str(JDK/'java.exe'),'-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar'),
        'LuaSyntax',str(CASES),str(LEAVES['production'])],text=True,capture_output=True,timeout=60)
    (out/'syntax.log').write_text(syntax.stdout+syntax.stderr,encoding='utf-8')
    shutil.copy2(GAME/'stdlib.lua',out/'stdlib.lua')
    bootstrap=subprocess.run([str(JDK/'java.exe'),'--enable-native-access=ALL-UNNAMED','-Duser.home='+str(out),
        '-cp',str(classes)+os.pathsep+str(GAME/'projectzomboid.jar'),'RainCollectorNativeProbe',str(GAME)],
        cwd=out,text=True,capture_output=True,timeout=60)
    (out/'bootstrap.log').write_text(bootstrap.stdout+bootstrap.stderr,encoding='utf-8')
    bootstrap_ok=bootstrap.returncode==0 and len(re.findall(r'^ENTITY Base\.[^ ]+ recipe=Base\.[^ ]+ nativeEligible=true$',bootstrap.stdout,re.M))==4 and bootstrap.stdout.count('PAYMENT true')==4 and bootstrap.stdout.count('amount=0.0')==4
    if args.native_preflight:
        print(bootstrap.stdout);print(bootstrap.stderr)
        return 0 if bootstrap_ok and syntax.returncode==0 else 1
    chunks=sources();chunks['run.lua']='__runRainCollectorCases();__runAdditionalCollectorCases()'
    fixture=CASES.read_text(encoding='utf-8-sig')
    expected={name for name in re.findall(r"check\('([a-z0-9_]+)'",fixture.split('function __runRainCollectorCases()',1)[1]) if not name.endswith('_')}
    for prefix in ['registered_variant','admission_no_construction','native_variant_payment_placement','native_variant_private_fact','empty_collector_retains_hydration']:
        for i in range(1,5):expected.add(f'{prefix}_{i}')
    expected.update(re.findall(r"'([a-z0-9_]+)'",fixture.split('function __runAdditionalCollectorCases()',1)[1].split('function __runRainCollectorControl',1)[0]))
    normal=execute(out/'normal',chunks,classes,expected)
    mutations=[
        ('copy-envelope','production.lua','(depth or 0)==0 and 96 or 32','32','full_envelope_canonical_delivery'),
        ('native-cache-preparation','production.lua','if rt.logic:getPossibleCraftCount(true)<1 then',
         'if false then','native_manual_preparation'),
        ('direct-create-authority','production.lua','if not c or not c.performing or not plumbCurrent(c) or not collector.bound(rt,true)',
         'if not c or false or not plumbCurrent(c) or not collector.bound(rt,true)','direct_native_create_refuses_payment'),
        ('metadata-whitelist','models.lua','siteKey=true,','', 'canonical_constructor_both_models'),
        ('generic-fact-gate','cognition.lua','supplied.kind=="collector-construction" or ','false or ','generic_constructor_fact_denied'),
        ('private-observation-time','production.lua','known.observedAtHours>=site.observedAtHours','known.observedAtHours==site.observedAtHours',
         'offfloor_return_refreshes_admitted_site'),
        ('pending-native-ack','production.lua',
         'if not plumbRetired(rt) or rec~=rt.record or rec.resourceProductionWork~=w or not collector.identity(rt.id,w)',
         'if false or rec~=rt.record or rec.resourceProductionWork~=w or not collector.identity(rt.id,w)','pending_constructor_ack_retained'),
    ]
    controls=[]
    for name,file,old,new,detector in mutations:
        variant=dict(chunks);count=variant[file].count(old)
        if count!=1:controls.append({'name':name,'detected':False,'mutationMatches':count});continue
        variant[file]=variant[file].replace(old,new,1);variant['run.lua']=f"__runRainCollectorControl('{detector}')"
        if name=='native-cache-preparation':
            preparation='if not logic:canPerformCurrentRecipe() then return false end'
            extra=variant[file].count(preparation)
            if extra!=1:controls.append({'name':name,'detected':False,'additionalMutationMatches':extra});continue
            variant[file]=variant[file].replace(preparation,'if false then return false end',1)
        result=execute(out/name,variant,classes,{detector})
        if name=='native-cache-preparation':result['omissionScope']='Both native selection preparation sites: canPerformCurrentRecipe and getPossibleCraftCount.'
        result.update(name=name,detector=detector,detected=result['exitCode']==0 and result['checks'].get(detector)=='false')
        controls.append(result)
    after={str(p):digest(p) for p in inputs}
    passed=bootstrap_ok and syntax.returncode==0 and normal['exitCode']==0 and not normal['failed'] and not normal['missing'] and not normal['extra'] and before==after and all(c['detected'] for c in controls)
    receipt={'schema':'sao-d35-native-rain-collector-proof/1','status':'PASS' if passed else 'FAIL',
        'sourcePins':before,'sourcePreserved':before==after,'normal':normal,'controls':controls,
        'bootstrap':{'verified':bootstrap_ok,'exitCode':bootstrap.returncode,'logSha256':digest(out/'bootstrap.log')},
        'syntax':{'exitCode':syntax.returncode,'logSha256':digest(out/'syntax.log')},
        'boundary':'Installed four entity definitions/CraftRecipes/BuildLogic/CraftRecipeData payment and kept hammer wear, GameEntityFactory native empty FluidContainer components; installed Lua building object/entity/build action/queue/equip/transfer; actual SAO owner/Planner/Labor/private WorldSources/Perception/Cognition/Models/CapabilityExperience and native Kahlua persistence. Actor, map, native dispatch, UI/sounds/network and Lua wrappers around exact Java items/recipe interfaces are controlled receivers. Entity UIConfig omitted only for unrelated skin registry bootstrap and managed sprite names come from installed entity rows without texture rendering. Java supplier/rain/fluid/native loaded-cell placement evidence belongs to the material companion proof. No attached game, deployment, shared compilation or repository/index mutation.'}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    print(f"D3.5 native collector {'PASS' if passed else 'FAIL'}: {len(normal['checks'])}/{len(expected)} cases; {sum(c['detected'] for c in controls)}/{len(controls)} controls")
    if not passed:
        print(normal);print([(c['name'],c.get('detected'),c.get('mutationMatches')) for c in controls]);print((out/'normal/output.log').read_text(encoding='utf-8')[-4000:])
    print('receipt '+str(out/'receipt.json'))
    if temporary:temporary.cleanup()
    return 0 if passed else 1

if __name__=='__main__':raise SystemExit(main())
