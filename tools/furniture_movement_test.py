#!/usr/bin/env python3
"""Installed FPP/SAO Lua in installed Kahlua with controlled map, body, inventory,
geometry and pickup/placement receivers. Executes complete installed core/action/
client modules; does not establish native relocation, graphics, multiplayer,
loaded-world acceptance or NPC planning/learning. Missing installed inputs remain
explicitly unchecked; missing owned proof inputs fail.
"""
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
HERE = ROOT / 'tools/luacheck'
OWNER = ROOT / 'mod/42.20/media/lua/client/SAO_FurnitureMovement.lua'
GAME = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
MOD = Path(os.environ.get('SAO_FURNITURE_DIR', r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3781319724\mods\FurniturePushPull\42'))
PROBE = HERE / 'FurnitureMovementProbe.java'
FIXTURES = [HERE / ('furniture_movement_' + p + '.lua') for p in ('prelude','geometry','cases')]
INSTALLED = [MOD / 'media/lua' / p for p in (
    'shared/FurniturePushPull/FurniturePushPull_Core.lua',
    'shared/FurniturePushPull/FurniturePushPull_Actions.lua',
    'client/FurniturePushPull/FurniturePushPull_Client.lua')]
BATH = Path(os.environ.get('SAO_BATH_DIR', r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3592172476\mods\Take A Bath And Shower New\42.20'))
WP = Path(os.environ.get('SAO_WATER_PIPES_DIR', r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3546314080\mods\WaterPipes\42.20'))
BATH_MODULES = [(name, BATH / 'media/lua/shared' / (name+'.lua')) for name in (
    'TABAS_Sprites', 'TubFluidContainer/TABAS_TubFluidContainerSystemUtils', 'TABAS_Iso')]
WP_COMMANDS = WP / 'media/lua/server/WPServerCommands.lua'
WP_ISO = WP / 'media/lua/shared/WPIso.lua'
CONTROLS = [
    ('premature-delay', 'b.due = b.queuedAt + fpp.PUSH_MOVE_DELAY_MS', 'b.due = b.queuedAt', 'delay_preserved'),
    ('accept-replaced-source', 'or not contains(m.square, m.object)', 'or false', 'same_sprite_replacement_refused'),
    ('accept-substituted-content', 'if not contentsMatch(m, m.object) then', 'if false then', 'same_id_content_substitution_refused'),
    ('false-content-completion', 'or not contentsMatch(m, found)', 'or false', 'incomplete_content_restore_not_completed'),
    ('ignore-wet-bath', 'if bathIso.isBathObject(object) and bathFluid.hasTfcData(square) then', 'if false then', 'wet_bath_refused_before_effect'),
    ('ignore-virtual-water', 'old.w ~= 0', 'false', 'virtual_water_refused_before_effect'),
    ('ignore-nested-content', 'if entry.nested and not inventoryMatches(entry.nested, entry.item:getInventory(), true) then', 'if false then', 'nested_content_substitution_refused'),
    ('overwrite-midmove-registry', 'or not sameScalars(data.Barrels[water.destinationKey], water.destinationOld)', 'or false', 'midmove_registry_change_preserved'),
    ('ignore-reentrant-reset', 'elseif binding and now >= binding.due then', 'elseif now >= binding.due then', 'reset_during_native_callback_is_bounded'),
    ('retain-nonscalar-reason', 'reason=type(reason) == "string" and string.sub(reason, 1, 160) or "unspecified",', 'reason=reason,', 'reset_non_scalar_reason_sanitized'),
    ('ignore-expiry', 'now > binding.expires', 'false', 'expired_push_no_native_effect'),
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--required',action='store_true')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    helper=ROOT/'tools/native_proof_preflight.py'
    if not helper.is_file():
        print('FAILED furniture movement proof: owned proof inputs absent: '+str(helper)); return 1
    from native_proof_preflight import presence, causal_controls
    owned=[Path(__file__).resolve(),ROOT/'tools/native_proof_preflight.py',OWNER,PROBE,*FIXTURES]
    installed=[*INSTALLED,*[p for _,p in BATH_MODULES],WP_COMMANDS,WP_ISO,MOD/'mod.info',GAME/'projectzomboid.jar',GAME/'stdlib.lua',JDK/'java.exe',JDK/'javac.exe']
    ready=presence(owned,installed,args.required,'furniture movement proof')
    if ready is not None: return ready
    with tempfile.TemporaryDirectory(prefix='sao-furniture-proof-') as directory:
        work=Path(directory)
        out=(args.output or work/'receipt').resolve(); out.mkdir(parents=True,exist_ok=True)
        inputs=owned+installed
        receipt={'boundary':__doc__,'inputs_before':{str(p):digest(p) for p in inputs},'runs':[],'controls':[]}
        def save(): (out/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        def command(label,argv):
            done=subprocess.run(list(map(str,argv)),cwd=work,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
            log=out/(label+'.log'); log.write_text(done.stdout+done.stderr,encoding='utf-8')
            receipt['runs'].append({'name':label,'command':list(map(str,argv)),'exitCode':done.returncode,'log':str(log),'logSha256':digest(log)})
            save(); return done
        def execute(label,owner):
            return command(label,[JDK/'java.exe','-cp',str(work)+os.pathsep+str(GAME/'projectzomboid.jar'),'FurnitureMovementProbe',FIXTURES[0],*INSTALLED,*bath_wrappers,WP_ISO,WP_COMMANDS,FIXTURES[1],owner,FIXTURES[2]])
        try:
            receipt['preflight']=causal_controls(ROOT,Path(__file__).resolve(),owned,env_updates={'SAO_FURNITURE_DIR':'{absent-extension}'},missing_owned=OWNER)
            shutil.copy2(GAME/'stdlib.lua',work/'stdlib.lua')
            bath_wrappers=[]
            for n,(module,path) in enumerate(BATH_MODULES):
                wrapped=work/('bath-module-'+str(n)+'.lua')
                wrapped.write_text('__modules['+json.dumps(module)+']=(function()\n'+path.read_text(encoding='utf-8-sig')+'\nend)()\n',encoding='utf-8')
                bath_wrappers.append(wrapped)
            compiled=command('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',GAME/'projectzomboid.jar','-d',work,PROBE])
            if compiled.returncode: raise RuntimeError(compiled.stdout+compiled.stderr)
            candidate=execute('candidate',OWNER)
            expected=set(re.findall(r'check\("([a-z0-9_]+)"',FIXTURES[2].read_text()))
            checks=dict(re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',candidate.stdout,re.M))
            if candidate.returncode or set(checks)!=expected or any(x!='true' for x in checks.values()) or 'FURNITURE_MOVEMENT_INSTALLED_VM_OK' not in candidate.stdout or 'INSTALLED_RECEIVER_API_OK' not in candidate.stdout:
                raise RuntimeError('candidate failed/missing checks '+str(sorted(expected-set(checks)))+'\n'+candidate.stdout[-5000:]+candidate.stderr[-2000:])
            receipt['cases']=len(checks)
            source=OWNER.read_text(encoding='utf-8-sig')
            for name,before,after,target in CONTROLS:
                if source.count(before)!=1: raise RuntimeError(name+': mutation anchor not unique')
                changed=source.replace(before,after,1); path=work/(name+'.lua');path.write_text(changed,encoding='utf-8')
                result=execute(name,path)
                if result.returncode==0 or 'CHECK '+target+'=false' not in result.stdout:
                    raise RuntimeError(name+': expected named failure '+target+'\n'+result.stdout[-2500:]+result.stderr[-1000:])
                receipt['controls'].append({'name':name,'target':target,'sourceSha256':digest(path),'verdict':'expected failure'})
            receipt['inputs_after']={str(p):digest(p) for p in inputs}
            if receipt['inputs_before']!=receipt['inputs_after']: raise RuntimeError('proof inputs changed during validation')
            receipt['result']='PASS';save()
            print(f"PASS furniture movement: {len(checks)} installed-VM checks, {len(CONTROLS)} defect controls; native map relocation and loaded gameplay unverified")
            return 0
        except Exception as exc:
            receipt['result']='FAILED';receipt['error']=str(exc);save()
            print('FAILED furniture movement: '+str(exc));return 1

if __name__=='__main__': raise SystemExit(main())
