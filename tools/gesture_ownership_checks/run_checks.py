"""Border109 native Gesture/Exchange admission regression; all compilation is private."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent


def run(root, output=None, gesture=None, baseline_only=False):
    root = Path(root).resolve()
    game = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    if not all(p.is_file() for p in [game/'projectzomboid.jar', jdk/'javac.exe', jdk/'java.exe']):
        print('  109) native ownership SKIPPED -- installed game and JDK required')
        return 0
    gesture = Path(gesture or root/'mod/42.20/media/lua/client/SAO_Gesture.lua').resolve()
    cooking = root/'mod/42.20/media/lua/client/SAO_Cooking.lua'
    exchange = root/'mod/42.20/media/lua/client/SAO_Exchange.lua'
    native_lua = [game/'media/lua/shared/ISBaseObject.lua',
        game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
        game/'media/lua/client/TimedActions/ISTimedActionQueue.lua',
        game/'media/lua/shared/TimedActions/ISToggleStoveAction.lua']
    sources = [root/'java/src/com/sao/engine/SAOCooking.java',
        root/'tools/luacheck/MovementCrossingProbe.java',
        root/'tools/luacheck/ResourceApproachProbe.java',
        root/'tools/cognition_checks/CognitionUseProbe.java',
        HERE.parent/'luacheck/GestureOwnershipProbe.java']
    jars = [game/'projectzomboid.jar', game/'ZombieBuddy.jar', root/'mod/42.20/media/java/SAO.jar']
    source_text = {'gesture': gesture.read_text(encoding='utf-8-sig'),
        'cooking': cooking.read_text(encoding='utf-8-sig')}
    expected = set(re.findall(r'check\("([a-z0-9_]+)"', (HERE/'cases.lua').read_text()))
    receipt = {'status': 'running', 'boundary':
        'Actual installed native shells, item, appliance, LuaTimedActionNew and timed-action queue; real full Gesture, Exchange and Cooking modules. Unrelated social policy and SourceUse transfer admission are controlled. No rendered animation or native transfer completion claim.',
        'inputs': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in
            sources+jars+native_lua+[gesture, cooking, exchange, HERE/'prelude.lua', HERE/'cases.lua', Path(__file__)]},
        'runs': [], 'controls': []}
    with tempfile.TemporaryDirectory(prefix='sao-gesture-ownership-') as temporary:
        work = Path(temporary)
        out = Path(output).resolve() if output else work/'receipt'
        out.mkdir(parents=True, exist_ok=True)
        def save():
            (out/'gesture-ownership.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
        def command(label, args):
            done = subprocess.run(list(map(str,args)), cwd=work, capture_output=True,
                text=True, encoding='utf-8', errors='replace', timeout=60)
            receipt['runs'].append({'name':label,'exit':done.returncode,
                'stdout':done.stdout,'stderr':done.stderr})
            save()
            return done
        try:
            shutil.copy2(game/'stdlib.lua', work/'stdlib.lua')
            cp = os.pathsep.join(map(str,jars))
            done = command('compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*sources])
            if done.returncode:
                raise RuntimeError('Native helper compile: '+done.stderr[-6000:])
            def execute(label, changes=()):
                texts = dict(source_text)
                for key, before, after in changes:
                    if texts[key].count(before) != 1:
                        raise RuntimeError(label+': mutation anchor must match once: '+key)
                    texts[key] = texts[key].replace(before,after,1)
                paths = {}
                for key, value in texts.items():
                    paths[key] = work/(label+'-'+key+'.lua')
                    paths[key].write_text(value, encoding='utf-8')
                done = command(label,[jdk/'java.exe','-Duser.home='+str(work),
                    '-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                    '-cp',str(work)+os.pathsep+cp,'GestureOwnershipProbe',game,
                    HERE/'prelude.lua',*native_lua,paths['cooking'],paths['gesture'],exchange,HERE/'cases.lua'])
                rows = re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',done.stdout,re.M)
                checks = dict(rows)
                if done.returncode or 'GESTURE_NATIVE_DONE' not in done.stdout or len(rows)!=len(expected) or set(checks)!=expected:
                    raise RuntimeError(label+': incomplete native execution: '+done.stdout[-9000:]+' '+done.stderr[-3000:])
                errors = dict(re.findall(r'^ERROR ([a-z0-9_]+): (.*)$', done.stdout,re.M))
                return checks, errors, texts
            checks, errors, _ = execute('baseline')
            failed = [name for name, value in checks.items() if value!='true']
            if failed:
                raise RuntimeError('Baseline failed '+str(failed)+'; '+str(errors))
            receipt['cases'] = len(checks)
            print('Gesture native baseline PASS: '+str(len(checks))+' cases',flush=True)
            if not baseline_only:
                for label, changes, target in controls(source_text):
                    checks, errors, texts = execute(label,changes)
                    if checks[target]!='false' or target in errors:
                        raise RuntimeError(label+': did not reject named behavioral defect: '+target+' '+str(errors))
                    receipt['controls'].append({'name':label,'target':target,'verdict':'false',
                        'source_sha256':{key:hashlib.sha256(texts[key].encode()).hexdigest() for key,_,_ in changes}})
                    print('Rejected '+label+' at '+target,flush=True)
            receipt['status']='passed'
        except Exception as error:
            receipt['status']='failed'; receipt['error']=str(error)
        save()
        print(json.dumps({key:receipt.get(key) for key in ['status','cases','error']}),flush=True)
        return 0 if receipt['status']=='passed' else 1


def controls(texts):
    guard = texts['gesture'][texts['gesture'].index('        -- A physical work owner'):texts['gesture'].index('        return false\n    end)', texts['gesture'].index('        -- A physical work owner'))]
    return [
        ('old-native-busy-only', [('gesture', guard, '')], 'idle_cooking_resists_other_person_meeting'),
        ('ignore-cooking-owner', [('gesture', 'rec.cookingWork ~= nil or rec.worldSourceReservation ~= nil', 'rec.worldSourceReservation ~= nil')], 'idle_cooking_resists_other_person_meeting'),
        ('ignore-source-owner', [('gesture', 'rec.cookingWork ~= nil or rec.worldSourceReservation ~= nil', 'rec.cookingWork ~= nil')], 'source_owner_gap_rejects_social_gesture'),
        ('ignore-external-record', [('gesture', 'rec.bodyOwner ~= nil or rec.zaoTransferPending ~= nil', 'rec.zaoTransferPending ~= nil')], 'external_owner_rejects_unsolicited_gesture'),
        ('ignore-external-native-mark', [('gesture', 'if data and (data.SAOExternalOwner ~= nil or data.ZAOOwned == true) then return true end', '')], 'external_native_mark_rejects_gesture'),
        ('ignore-zao-handoff', [('gesture', 'rec.bodyOwner ~= nil or rec.zaoTransferPending ~= nil', 'rec.bodyOwner ~= nil')], 'pending_handoff_rejects_gesture'),
        ('ignore-crossed-handoff', [('gesture', '\n                or rec.crossedTransferPending ~= nil', '')], 'pending_crossed_handoff_rejects_gesture'),
        ('ignore-lua-pending-queue', [('gesture', 'if queue and type(queue.queue) == "table" and #queue.queue > 0 then return true end', '')], 'lua_queued_action_gap_rejects_gesture'),
        ('block-all-nonidle-work', [('gesture', 'if rec then\n', 'if rec then\n            if SAO.Controller.agents[id].state ~= "IDLE" then return true end\n')], 'instrument_rest_gesture_still_admitted'),
        ('block-required-standup-cleanup', [('gesture', 'function G.standUp(body)\n', 'function G.standUp(body)\n    if not free(body) then return false end\n')], 'standup_cleanup_survives_work_owner'),
        ('allow-real-foreign-action', [('cooking', 'if SAO.Needs.busy(body) and not (rt.toggle and queued(body, rt.toggle)) then', 'if false then')], 'real_foreign_action_still_interrupts_cooking'),
    ]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',nargs='?',type=Path,default=HERE.parent.parent)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--gesture',type=Path)
    parser.add_argument('--baseline-only',action='store_true')
    args=parser.parse_args()
    return run(args.root,args.output,args.gesture,args.baseline_only)

if __name__=='__main__':
    raise SystemExit(main())
