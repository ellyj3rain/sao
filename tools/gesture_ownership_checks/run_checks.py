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


def run(root, output=None, gesture=None, baseline_only=False, conflict=False):
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
    case_paths = [HERE/'cases.lua']
    response = root/'mod/42.20/media/lua/client/SAO_ConflictResponse.lua'
    if conflict:
        source_text['response'] = response.read_text(encoding='utf-8-sig')
        # Read-only fixture access to the private live registry, after loading
        # the unmodified production statements. No gameplay caller gets this.
        if source_text['gesture'].count('\nreturn G') != 1:
            raise RuntimeError('private registry fixture anchor differs')
        source_text['gesture'] = source_text['gesture'].replace('\nreturn G',
            '\n__gestureFixtureRegistry = optional\nreturn G')
        case_paths.append(HERE/'conflict_cases.lua')
    expected = set(re.findall(r'check\("([a-z0-9_]+)"', '\n'.join(p.read_text() for p in case_paths)))
    receipt = {'status': 'running', 'boundary':
        'Actual installed native shells, item, appliance, LuaTimedActionNew and timed-action queue; real full Gesture, Exchange and Cooking modules. Unrelated social policy and SourceUse transfer admission are controlled. No rendered animation or native transfer completion claim.',
        'inputs': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in
            sources+jars+native_lua+[gesture, cooking, exchange, HERE/'prelude.lua', *case_paths, Path(__file__)]
            +([response] if conflict else [])},
        'runs': [], 'controls': []}
    with tempfile.TemporaryDirectory(prefix='sao-gesture-ownership-') as temporary:
        work = Path(temporary)
        out = Path(output).resolve() if output else work/'receipt'
        out.mkdir(parents=True, exist_ok=True)
        def save():
            (out/'gesture-ownership.json').write_bytes((json.dumps(receipt, indent=2)+'\n').encode('utf-8'))
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
                    encoded = value.encode('utf-8')
                    paths[key].write_bytes(encoded)
                    # Retain the exact LF source executed by the installed VM,
                    # including restored defects, after temporary files retire.
                    performed = out/'performed-sources'/(label+'-'+key+'.lua')
                    performed.parent.mkdir(parents=True, exist_ok=True)
                    performed.write_bytes(encoded)
                done = command(label,[jdk/'java.exe','-Duser.home='+str(work),
                    '-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                    '-cp',str(work)+os.pathsep+cp,'GestureOwnershipProbe',game,
                    HERE/'prelude.lua',*native_lua,paths['cooking'],paths['gesture'],exchange,
                    *([paths['response']] if conflict else []),*case_paths])
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
                for control in (conflict_controls() if conflict else controls(source_text)):
                    label, changes, target = control[:3]
                    # A single removed defense must still refuse when the other
                    # independent owner guard remains. Full defect controls
                    # remove both defenses and must flip the same witness.
                    verdict = control[3] if len(control) == 4 else 'false'
                    checks, errors, texts = execute(label,changes)
                    if checks[target]!=verdict or target in errors:
                        raise RuntimeError(label+': named behavioral witness must be '+verdict+': '+target+' '+str(errors))
                    receipt['controls'].append({'name':label,'target':target,'verdict':verdict,
                        'source_sha256':{key:hashlib.sha256(texts[key].encode()).hexdigest() for key,_,_ in changes}})
                    print(('Rejected ' if verdict == 'false' else 'Remaining owner guard preserved ')
                        +label+' at '+target,flush=True)
            receipt['changedInputs']=[path for path,sha in receipt['inputs'].items()
                if hashlib.sha256(Path(path).read_bytes()).hexdigest()!=sha]
            if receipt['changedInputs']: raise RuntimeError('proof inputs changed during execution')
            receipt['status']='passed'
        except Exception as error:
            receipt['status']='failed'; receipt['error']=str(error)
        save()
        print(json.dumps({key:receipt.get(key) for key in ['status','cases','error']}),flush=True)
        return 0 if receipt['status']=='passed' else 1


def controls(texts):
    guard = texts['gesture'][texts['gesture'].index('        -- A physical work owner'):texts['gesture'].index('        return false\n    end)', texts['gesture'].index('        -- A physical work owner'))]
    record_guard = ('gesture', 'rec.bodyOwner ~= nil or rec.zaoTransferPending ~= nil', 'rec.zaoTransferPending ~= nil')
    native_guard = ('gesture', 'if data and (data.SAOExternalOwner ~= nil or data.ZAOOwned == true) then return true end', '')
    zao_guard = ('gesture', 'rec.bodyOwner ~= nil or rec.zaoTransferPending ~= nil', 'rec.bodyOwner ~= nil')
    crossed_guard = ('gesture', '\n                or rec.crossedTransferPending ~= nil', '')
    return [
        ('old-native-busy-only', [('gesture', guard, '')], 'idle_cooking_resists_other_person_meeting'),
        ('ignore-cooking-owner', [('gesture', 'rec.cookingWork ~= nil or rec.worldSourceReservation ~= nil', 'rec.worldSourceReservation ~= nil')], 'idle_cooking_resists_other_person_meeting'),
        ('ignore-source-owner', [('gesture', 'rec.cookingWork ~= nil or rec.worldSourceReservation ~= nil', 'rec.cookingWork ~= nil')], 'source_owner_gap_rejects_social_gesture'),
        ('remove-first-external-record-defense', [record_guard], 'external_owner_rejects_unsolicited_gesture', 'true'),
        ('ignore-external-record', [record_guard,
            ('gesture', 'or current.bodyOwner\n', '\n')], 'external_owner_rejects_unsolicited_gesture'),
        ('remove-first-external-native-defense', [native_guard], 'external_native_mark_rejects_gesture', 'true'),
        ('ignore-external-native-mark', [native_guard,
            ('gesture', 'and data.SAOExternalOwner == nil\n        and data.ZAOOwned ~= true', '')], 'external_native_mark_rejects_gesture'),
        ('remove-first-zao-handoff-defense', [zao_guard], 'pending_handoff_rejects_gesture', 'true'),
        ('ignore-zao-handoff', [zao_guard,
            ('gesture', 'or current.zaoTransferPending or current.crossedTransferPending',
                'or current.crossedTransferPending')], 'pending_handoff_rejects_gesture'),
        ('remove-first-crossed-handoff-defense', [crossed_guard], 'pending_crossed_handoff_rejects_gesture', 'true'),
        ('ignore-crossed-handoff', [crossed_guard,
            ('gesture', 'or current.zaoTransferPending or current.crossedTransferPending',
                'or current.zaoTransferPending')], 'pending_crossed_handoff_rejects_gesture'),
        ('ignore-lua-pending-queue', [('gesture', 'if queue and type(queue.queue) == "table" and #queue.queue > 0 then return true end', '')], 'lua_queued_action_gap_rejects_gesture'),
        ('block-all-nonidle-work', [('gesture', 'if rec then\n', 'if rec then\n            if SAO.Controller.agents[id].state ~= "IDLE" then return true end\n')], 'instrument_rest_gesture_still_admitted'),
        ('block-required-standup-cleanup', [('gesture', 'function G.standUp(body)\n', 'function G.standUp(body)\n    if not free(body) then return false end\n')], 'standup_cleanup_survives_work_owner'),
        ('allow-real-foreign-action', [('cooking', 'if SAO.Needs.busy(body) and not (rt.toggle and queued(body, rt.toggle)) then', 'if false then')], 'real_foreign_action_still_interrupts_cooking'),
    ]


def conflict_controls():
    return [
        ('omit-selected-handoff', [('response', 'and not SAO.Gesture.yieldToConflict(id,body,decision)',
            'and false')], 'optional_gesture_yields_only_after_native_release'),
        ('ignore-native-release', [('gesture', 'if queued or native then return false end',
            'if queued then return false end')], 'optional_gesture_yields_only_after_native_release'),
        ('allow-conversation-requeue', [('gesture', 'and SAO.ConflictResponse.gesturePriority(tostring(id), body) then return true end',
            'and false then return true end')], 'conversation_cannot_requeue_during_pending_or_maintained_response'),
        ('clear-shared-queue', [('gesture', 'if queue.current == self then queue:onCompleted(self)',
            'if queue.current == self then queue:resetQueue()')], 'later_unrelated_action_survives_exact_gesture_stop'),
        ('ignore-current-decision', [('response', 'if not view or view.purposeId~=hold.purposeId or view.selected~=hold.selected\n        or view.frameId~=hold.frameId then return false end',
            'if not view then return false end')], 'foreign_or_stale_decision_cannot_yield'),
        ('completion-race-credited', [('gesture', 'if work and work.cancelled then self:stop(); return end',
            'if false then self:stop(); return end')], 'completion_race_after_yield_remains_interrupted'),
        ('watch-never-expires', [('response', 'return tick>=hold.at and tick<=hold.untilTick',
            'return tick>=hold.at')], 'watch_hold_expires_and_no_threat_releases'),
        ('ignore-action-generation', [('gesture', 'and data.ZAOOwned ~= true and data.SAOExternalToken == token\n        and current.bodyOwnerToken == token',
            'and data.ZAOOwned ~= true')], 'changed_generation_cannot_retire_old_gesture'),
        ('inherit-prior-generation-hold', [('response', 'or hold.bodyToken~=agent.rec.bodyOwnerToken',
            'or false')], 'new_generation_does_not_inherit_watch_suppression'),
        ('ignore-unrouted-native-state', [('gesture', 'if body:isClimbing() or state == "ClimbOverFenceState" or state == "ClimbThroughWindowState"\n        or state == "SmashWindowState" or tostring(state):find("OpenWindowState",1,true) then return false end',
            'if false then return false end')], 'native_open_smash_climb_without_job_remain_owned'),
        ('retain-settled-handoff', [('gesture', 'if work and ISTimedActionQueue.hasAction(work.action) ~= true\n        and not (work.action.action and body:getCharacterActions():contains(work.action.action)) then',
            'if false then')], 'settled_old_handoff_does_not_hide_a_new_optional_action'),
        ('ignore-replaced-native-stack', [('gesture', 'if not native:isEmpty() and not (action.action and native:contains(action.action)) then return false end',
            'if false then return false end')], 'replaced_native_owner_keeps_its_stack_and_queued_successor'),
        ('retain-detached-handback', [('response', 'if SAO.Gesture and SAO.Gesture.releaseConflict then SAO.Gesture.releaseConflict(id,body) end',
            '')], 'detach_releases_pending_handback_without_touching_native_action'),
        ('retain-ended-owner-handback', [('gesture', 'Events.OnTick.Add(retireHandbacks)',
            '')], 'dead_or_transferred_owner_retires_without_further_decision'),
        ('retain-settled-handback-without-decisions', [('gesture', 'if not action or not optionalOwner(action, work)\n            or ISTimedActionQueue.hasAction(action) ~= true\n                and not (action.action and work.body:getCharacterActions():contains(action.action)) then',
            'if not action or not optionalOwner(action, work) then')], 'settled_handback_retires_without_further_decision'),
        ('retain-completed-optional-registry', [('gesture', 'if work then optional[self] = nil;work.retired = true;work.action = nil end',
            'if work then work.retired = true;work.action = nil end')], 'terminal_optional_actions_leave_live_registry'),
        ('retain-stopped-optional-registry', [('gesture', 'optional[self] = nil\n        work.retired = true',
            'work.retired = true')], 'terminal_optional_actions_leave_live_registry'),
        ('retain-lost-optional-registry', [('gesture', 'optional[action] = nil\n            work.retired = true',
            'work.retired = true')], 'lost_owner_optional_actions_retire_without_callbacks'),
        ('discard-late-callback-tombstone', [('gesture', 'action.stop = function(self) if self == action then stopGesture(self, work) end end',
            'action.stop = function(self) if self == action then stopGesture(self, nil) end end')],
            'late_retired_callback_preserves_new_action'),
    ]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',nargs='?',type=Path,default=HERE.parent.parent)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--gesture',type=Path)
    parser.add_argument('--baseline-only',action='store_true')
    parser.add_argument('--conflict',action='store_true')
    args=parser.parse_args()
    return run(args.root,args.output,args.gesture,args.baseline_only,args.conflict)

if __name__=='__main__':
    raise SystemExit(main())
