#!/usr/bin/env python3
"""Installed musical item, native queue/world-sound and exact audio-handle ownership."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT / 'tools/instrument_checks'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--baseline-only', action='store_true')
    parser.add_argument('--control', action='append', default=[], help='Run only named restored-defect controls after the baseline')
    args = parser.parse_args()
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    game = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    sources = [ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',
               ROOT/'tools/cognition_checks/CognitionUseProbe.java', HERE/'InstrumentProbe.java']
    jars = [game/'projectzomboid.jar',game/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    native = [game/'media/lua/shared/ISBaseObject.lua',game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
              game/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
    runtime = {name:ROOT/'mod/42.20/media/lua/client'/('SAO_'+name+'.lua') for name in ('Needs','Gesture','PopulationRepresentation')}
    inputs = sources+jars+native+list(runtime.values())+[HERE/'prelude.lua',HERE/'setup.lua',HERE/'cases.lua',Path(__file__),
        game/'media/scripts/generated/items/normal.txt',game/'media/scripts/generated/items/weapon.txt',
        game/'media/scripts/generated/sounds/player/sounds_player_survival.txt']
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, game, jdk, "instrument")
    if preflight is not None:
        raise SystemExit(preflight)
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    receipt = dict(status='INCOMPLETE', inputsBefore={str(p):sha(p) for p in inputs}, commands=[], controls=[],
        boundary='Actual installed items/native carried inventory, shell authority, Lua queue and WorldSoundManager. Audio hardware is a controlled BaseCharacterSoundEmitter receiver; no rendered/audible acceptance or social/mastery claim.')
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def command(label,args,cwd):
        result=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,timeout=90)
        log=out/(label+'.log');log.write_bytes(result.stdout+result.stderr)
        receipt['commands'].append(dict(label=label,command=list(map(str,args)),cwd=str(cwd),exitCode=result.returncode,log=str(log),logSha256=sha(log)))
        save();return result,log.read_text(encoding='utf-8',errors='replace')
    expected=set(re.findall(r'check\("([a-z0-9_]+)"',(HERE/'cases.lua').read_text()))
    try:
        with tempfile.TemporaryDirectory(prefix='sao-instrument-') as temporary:
            work=Path(temporary);shutil.copyfile(game/'stdlib.lua',work/'stdlib.lua')
            cp=os.pathsep.join(map(str,jars))
            result,log=command('compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*sources],work)
            if result.returncode: raise AssertionError('native fixture compile failed: '+log[-2000:])
            texts={name:p.read_text(encoding='utf-8-sig') for name,p in runtime.items()}
            def execute(label,changes=()):
                modified=dict(texts)
                for key,before,after in changes:
                    if modified[key].count(before)!=1: raise AssertionError('nonunique control '+label)
                    modified[key]=modified[key].replace(before,after)
                paths={}
                for key,text in modified.items():
                    paths[key]=out/(label+'-'+key+'.lua');paths[key].write_text(text,encoding='utf-8')
                result,log=command(label,[jdk/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'InstrumentProbe',game,
                    HERE/'prelude.lua',*native,HERE/'setup.lua',paths['Needs'],paths['Gesture'],HERE/'cases.lua'],work)
                rows=re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',log,re.M)
                if result.returncode or 'INSTRUMENT_NATIVE_DONE' not in log or len(rows)!=len(expected) or {r[0] for r in rows}!=expected:
                    raise AssertionError(label+' incomplete native execution: '+log[-5000:])
                return {name for name,value in rows if value=='false'},log
            failed,log=execute('baseline')
            if failed: raise AssertionError('baseline failed '+str(sorted(failed))+': '+log[-5000:])
            receipt['checks']=len(expected)
            controls=[
                ('old-weapon-category',[('Needs','item:getDisplayCategory() ~= "Instrument"','item:getDisplayCategory() ~= "InstrumentWeapon"')],'native_metadata_includes_harmonica_not_weapon_or_whistle'),
                ('omit-native-audio',[('Gesture','state.sound = action.character:playSound(state.capability.sound)','state.sound = 0')],'actual_native_sound_and_world_stimulus_once'),
                ('omit-world-stimulus',[('Gesture','state.worldSound = getWorldSoundManager():addSound(body,','state.worldSound = false and getWorldSoundManager():addSound(body,')],'actual_native_sound_and_world_stimulus_once'),
                ('animation-completed',[('Gesture','if not work.instrument.ended or not self:isValid() then self:stop(); return end','if not self:isValid() then self:stop(); return end')],'animation_or_early_perform_never_completes_sound'),
                ('omit-owned-sound-stop',[('Gesture','state.emitter:stopSound(state.sound)','local ignored = state.sound')],'interruption_stops_exact_sound_retains_unrelated_sound'),
                ('ignore-exact-item',[('Needs','if items:get(i) == item then return candidate end','if true then return candidate end'),
                    ('Gesture','if items:get(i) == self.requiredItem then return true end','if true then return true end')],'item_loss_after_admission_prevents_completion'),
                ('omit-reload-cleanup',[('Gesture','if G.resetInstruments then G.resetInstruments() end','')],'module_reload_cancels_sound_and_preserves_detached_outcome'),
                ('invent-listener-reward',[('Gesture','local other = accepted and not (work and work.instrument) and self.planReceipt.rewardWith or nil','local other = accepted and self.planReceipt.rewardWith or nil')],'native_sound_end_owns_narrow_completion_no_social_reward'),
                ('skip-purpose-binding',[('Gesture','if instrument and purposeId then','if false then')],'prepared_purpose_precedes_inline_native_failure'),
                ('ignore-purpose-refusal',[('Gesture','if not planner or not planner.admitInstrument or not planner.admitInstrument(id, purposeId, work.instrument.workId) then','if false then')],'refused_purpose_never_reaches_native_sound'),
                ('ignore-native-query-nil',[('Gesture','if not ok or type(playing) ~= "boolean" then finishInstrument(action, work, "interrupted"); action:forceStop(); return end','if not ok then finishInstrument(action, work, "interrupted"); action:forceStop(); return end')],'playback_query_exception_stops_exact_sound'),
                ('ignore-failed-cleanup',[('Gesture','ok = ok and stopped == true','ok = true')],'failed_cleanup_is_interrupted_and_retries_only_owned_handle'),
                ('keep-detached-cleanup',[('Gesture','if not currentOwner(owner.id, owner.body, owner.rec, owner.token) then soundCleanup[state] = nil','if false then soundCleanup[state] = nil')],'pending_cleanup_retires_after_detach_without_touching_successor'),
                ('omit-exact-sequence',[('Gesture','identity == nil or candidate.sequence == identity','true or candidate.sequence == identity')],'exact_terminal_lookup_keeps_distinct_repeated_attempts'),
            ]
            if set(args.control)-{row[0] for row in controls}: raise AssertionError('unknown selected control')
            if not args.baseline_only:
                for name,changes,marker in controls:
                    if args.control and name not in args.control: continue
                    failed,log=execute(name,changes)
                    if marker not in failed: raise AssertionError(name+' missed exact defect '+marker)
                    receipt['controls'].append(dict(name=name,expectedFailure=marker,failures=sorted(failed)))
            receipt['inputsAfter']={str(p):sha(p) for p in inputs}
            if receipt['inputsAfter']!=receipt['inputsBefore']: raise AssertionError('source inputs changed during proof')
            receipt['status']='PASS'
    except Exception as error:
        receipt['failure']=str(error);save();print('FAIL instrument:',error);return 1
    save();print('PASS instrument',receipt['checks'],'checks',len(receipt['controls']),'controls');return 0


if __name__=='__main__':
    raise SystemExit(main())
