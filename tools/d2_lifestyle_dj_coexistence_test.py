"""Pinned Lifestyle DJ menu coexistence in native Kahlua with controlled actors.

The original DJ menu callback is a controlled stand-in. This qualifies the
SAO lease boundary and selected source fingerprint, not loaded-game UI behavior.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile

import d2_leisure_lifestyle_test as base


ROOT = base.ROOT
OWNER = base.OWNER
FIX = base.FIX
GAME = base.GAME
JDK = base.JDK
MOD = ROOT / 'mod/42.20'
CASES = FIX / 'dj-coexistence-cases.lua'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--baseline-only', action='store_true')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    names = re.findall(r'\["([^\"]+\.lua)"\]=\{', OWNER.read_text(encoding='utf8'))
    vault = MOD / 'media/SAOSources/LifestyleHobbies/media/lua'
    original = base.LS / 'client/DJBoothContextMenu.lua'
    native = [GAME / 'media/lua/shared/ISBaseObject.lua',
              GAME / 'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    jars = [GAME / 'projectzomboid.jar', *sorted((GAME / 'jars').glob('*.jar'))]
    inputs = [Path(__file__), OWNER, CASES, FIX / 'prelude.lua',
              base.BASE / 'prelude.lua', base.BASE / 'MusicProbe.java',
              *native, *jars, GAME / 'stdlib.lua', original,
              *[vault / name for name in names]]
    before = {str(path): sha(path) for path in inputs}
    receipt = {'schema': 'sao-d2-dj-coexistence/1', 'status': 'INCOMPLETE',
               'boundary': __doc__, 'inputsBefore': before, 'runs': []}

    def save():
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')

    controls = [
        ('offer-busy', 'and not originalDJBusy()and not playerDJQueued(object)and not djOwned(object)and djGuardReady()then',
         'then', 'original_active_blocks_offer'),
        ('player-queue', 'if not object then return false end\n if DJBoothMenu',
         'if true then return false end\n if DJBoothMenu',
         'owned_player_queue_blocks_npc_offer'),
        ('lease', 'if djOwned(object)then return true end',
         'if false then return true end', 'sao_action_has_exact_object_lease'),
        ('lease-until-cleanup', '-- menu cannot take the booth in that intervening frame.\n   return true',
         '-- menu cannot take the booth in that intervening frame.\n   return admitted(a)',
         'retiring_admission_keeps_lease_until_action_cleanup'),
        ('menu', 'if djGuard.active and L.physicalSourceOwner(object)then',
         'if false then', 'original_cannot_start_same_station'),
        ('takeover', 'if a.offer.activity=="perform-dj"and(originalDJBusy()or playerDJQueued(object)or djOwned(object,a)or not djGuardReady())then return false end',
         'if false then return false end', 'unexpected_original_takeover_interrupts_private_dj'),
        ('queued-takeover', 'or playerDJQueued(object)or djOwned(object,a)',
         'or djOwned(object,a)', 'queued_external_player_interrupts_same_booth_npc'),
        ('missing-menu', 'return djGuard.qualified==true and djGuard.menu==DJBoothMenu',
         'return not DJBoothMenu or djGuard.qualified==true and djGuard.menu==DJBoothMenu',
         'missing_menu_refuses_new_npc_offer'),
        ('changed-callback', 'and DJBoothMenu.onPlay==djGuard.menuWrapper and djGuard.queue==ISTimedActionQueue',
         'and type(DJBoothMenu.onPlay)=="function"and djGuard.queue==ISTimedActionQueue',
         'changed_callback_refuses_npc_offer'),
        ('captured-callback', 'local wrapper=function(action,...)\n   if djGuard.active and blockedOriginalDJAction(action)then return false end\n   return original(action,...)\n  end\n  djGuard.queue=queue',
         'local wrapper=function(action,...)\n   if false then return false end\n   return original(action,...)\n  end\n  djGuard.queue=queue',
         'captured_original_cannot_queue_same_station'),
        ('queued-action-validity', 'local wrapper=function(action,...)\n   if djGuard.active and blockedOriginalDJAction(action)then return false end\n   return original(action,...)\n  end\n  djGuard.actionClass',
         'local wrapper=function(action,...)\n   if false then return false end\n   return original(action,...)\n  end\n  djGuard.actionClass',
         'captured_original_action_invalid_on_lease'),
        ('source-rebind', 'if menu.onPlay==djGuard.originalMenu then',
         'if menu.onPlay==djGuard.originalMenu and not djGuard.menuWrapper then',
         'source_callback_rebound_guard_restored'),
        ('class-rebind', 'if class~=djGuard.actionClass then releaseGuardedDJClass()end',
         'if false then releaseGuardedDJClass()end',
         'recreated_class_restores_previous_wrapper'),
        ('paired-menu-rebind', 'if menu~=djGuard.menu then releaseGuardedDJMenu()end',
         'if menu~=djGuard.menu and menu==nil then releaseGuardedDJMenu()end',
         'paired_recreated_menu_restores_previous_wrapper'),
        ('retired-class-override',
         'if djGuard.actionClass and djGuard.actionClass.isValid==djGuard.validWrapper then',
         'if djGuard.actionClass then',
         'rebind_preserves_external_override_on_retired_class'),
        ('retired-menu-override',
         'if djGuard.menu and djGuard.menu.onPlay==djGuard.menuWrapper then',
         'if djGuard.menu then',
         'rebind_preserves_external_override_on_retired_menu'),
        ('current-class-reload',
         'if djGuard.queue and djGuard.queue.add==djGuard.queueWrapper then djGuard.queue.add=djGuard.originalAdd end\n releaseGuardedDJClass()',
         'if djGuard.queue and djGuard.queue.add==djGuard.queueWrapper then djGuard.queue.add=djGuard.originalAdd end\n do end',
         'module_reload_restores_current_class'),
        ('retired-hook-reload', 'if not djGuard.active then return false end',
         'if false then return false end',
         'module_reload_ignores_stale_hooks'),
        ('retired-menu-wrapper', 'if djGuard.active and L.physicalSourceOwner(object)then',
         'if L.physicalSourceOwner(object)then',
         'retired_captured_menu_delegates_to_current_lease_guard'),
        ('current-menu-reload',
         'djGuard.active=false\n releaseGuardedDJMenu()',
         'djGuard.active=false\n do end',
         'module_reload_restores_other_callbacks'),
        ('cleanup-menu',
         'if djGuard.menu and djGuard.menu.onPlay==djGuard.menuWrapper then\n  djGuard.menu.onPlay=djGuard.originalMenu\n end',
         'if false then\n  djGuard.menu.onPlay=djGuard.originalMenu\n end',
         'missing_menu_releases_previous_wrapper'),
    ]
    try:
        assert original in inputs
        assert sha(original) == '8894fd69dcf5326dfd740d36b26c4fc95f2b1f7c01fdd6dd3e2b54e45256fa93'
        assert sha(vault / 'client/DJBoothContextMenu.lua') == sha(original)
        with tempfile.TemporaryDirectory(prefix='sao-dj-coexistence-') as tmp:
            work = Path(tmp)
            shutil.copyfile(GAME / 'stdlib.lua', work / 'stdlib.lua')
            cp = os.pathsep.join(map(str, jars))
            selected = original.read_text(encoding='utf8')
            begin = selected.index('DJBoothMenu.onPlay = function(')
            end = selected.index('Events.OnFillWorldObjectContextMenu.Add(', begin)
            original_callback = out / 'selected-original-onplay.lua'
            original_callback.write_text('DJBoothMenu={}\n' + selected[begin:end]
                                         + '\n__originalDJOnPlay=DJBoothMenu.onPlay\n', encoding='utf8')
            receipt['selectedOriginalOnPlaySha256'] = sha(original_callback)
            compile_run = subprocess.run([str(JDK / 'javac.exe'), '-encoding', 'UTF-8',
                                          '-cp', cp, '-d', str(work),
                                          str(base.BASE / 'MusicProbe.java')], capture_output=True)
            (out / 'compile.log').write_bytes(compile_run.stdout + compile_run.stderr)
            assert compile_run.returncode == 0
            for name, old, new, marker in [('baseline', None, None, None), *([] if args.baseline_only else controls)]:
                source = OWNER.read_text(encoding='utf8')
                for lhs, rhs in (old if isinstance(old, list) else [(old, new)] if old else []):
                    assert source.count(lhs) == 1, (name, source.count(lhs))
                    source = source.replace(lhs, rhs, 1)
                variant = out / (name + '-owner.lua')
                variant.write_text(source, encoding='utf8')
                manifest = out / (name + '-sources.tsv')
                manifest.write_text(''.join('LifestyleHobbies:' + n + '\t' + str(vault / n) + '\n'
                                            for n in names), encoding='utf8')
                command = [str(JDK / 'java.exe'), '--enable-native-access=ALL-UNNAMED',
                           '-Djava.awt.headless=true', '-cp', str(work) + os.pathsep + cp,
                           'MusicProbe', str(manifest), str(base.BASE / 'prelude.lua'),
                           *map(str, native), str(vault / 'shared/LSUtil.lua'),
                           str(FIX / 'prelude.lua'), str(original_callback),
                           str(variant), str(CASES)]
                run = subprocess.run(command, cwd=work, capture_output=True, timeout=90)
                log = out / (name + '.log')
                log.write_bytes(run.stdout + run.stderr)
                output = log.read_text(encoding='utf8', errors='replace')
                receipt['runs'].append({'name': name, 'exitCode': run.returncode,
                                        'logSha256': sha(log), 'failure': marker})
                save()
                if marker:
                    assert run.returncode != 0 and 'D2_DJ_COEXISTENCE:' + marker in output, (name, output[-6000:])
                else:
                    assert run.returncode == 0 and 'PASS D2 DJ coexistence ' in output, output[-8000:]
                    receipt['checks'] = int(re.search(r'PASS D2 DJ coexistence (\d+)', output)[1])
        receipt['inputsAfter'] = {str(path): sha(path) for path in inputs}
        assert receipt['inputsAfter'] == before, 'input changed during qualification'
        receipt['status'] = 'PASS'
        save()
        print('PASS D2 DJ coexistence', receipt['checks'], len(controls))
    except Exception as error:
        receipt['status'] = 'FAIL'
        receipt['error'] = str(error)
        save()
        raise


if __name__ == '__main__':
    main()
