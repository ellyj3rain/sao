#!/usr/bin/env python3
"""Installed emission/scanner/queue and exact private attributable-hearing custody."""
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
HERE = ROOT / 'tools/participation_pulse_checks'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--baseline-only', action='store_true')
    parser.add_argument('--orientation-baseline', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    game = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    jars = [game/'projectzomboid.jar',game/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    sources = [ROOT/'java/src/com/sao/engine/SAOWorldSoundPulses.java',ROOT/'java/src/com/sao/bridge/SAOBridge.java',
        ROOT/'java/src/com/sao/engine/SAOPerceptionScanner.java',ROOT/'java/src/com/sao/engine/SAOSenses.java',
        ROOT/'java/src/com/sao/agent/SAOOrientationWeave.java',
        ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',
        ROOT/'tools/cognition_checks/CognitionUseProbe.java',ROOT/'tools/instrument_checks/InstrumentProbe.java',
        ROOT/'tools/orienting_checks/OrientationProbeAgent.java',HERE/'PulseParticipationProbe.java']
    if args.orientation_baseline: sources.append(ROOT/'tools/orienting_checks/OrientationProbe.java')
    runtime = {name:ROOT/'mod/42.20/media/lua'/area/('SAO_'+name+'.lua') for name,area in
        [('Needs','client'),('Gesture','client'),('Perception','shared')]}
    native = [game/'media/lua/shared/ISBaseObject.lua',game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
        game/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
    fixture = [ROOT/'tools/instrument_checks/prelude.lua',ROOT/'tools/instrument_checks/setup.lua',HERE/'cases.lua']
    inputs = list(dict.fromkeys(sources+jars+native+fixture+list(runtime.values())+[Path(__file__),
        ROOT/'java/src/com/sao/engine/SAOPerceptionScanner.java',ROOT/'java/src/com/sao/engine/SAOSenses.java',
        ROOT/'java/src/com/sao/agent/SAOOrientationWeave.java',game/'media/scripts/generated/items/normal.txt',
        game/'media/scripts/generated/items/weapon.txt',game/'stdlib.lua']))
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, game, jdk, "participation pulse")
    if preflight is not None:
        raise SystemExit(preflight)
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    receipt = dict(status='INCOMPLETE',inputsBefore={str(p):sha(p) for p in inputs},commands=[],controls=[],
        boundary='Actual installed item/queue/WorldSound initialization hook/scanner and native visibility on controlled loaded geometry; controlled audio hardware receiver. No rendered or audible human acceptance, assent, shared completion or pleasure claim.')
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def command(label,argv,cwd):
        result=subprocess.run(list(map(str,argv)),cwd=cwd,capture_output=True,timeout=100)
        log=out/(label+'.log');log.write_bytes(result.stdout+result.stderr)
        receipt['commands'].append(dict(label=label,command=list(map(str,argv)),exitCode=result.returncode,log=str(log),logSha256=sha(log)))
        save();return result,log.read_text(encoding='utf-8',errors='replace')
    try:
        with tempfile.TemporaryDirectory(prefix='sao-participation-pulse-') as temporary:
            work=Path(temporary);classes=work/'classes';classes.mkdir();shutil.copyfile(game/'stdlib.lua',work/'stdlib.lua')
            cp=os.pathsep.join(map(str,jars))
            result,log=command('compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',classes,*sources],work)
            if result.returncode: raise AssertionError('native compile: '+log[-4000:])
            manifest=work/'MANIFEST.MF';manifest.write_text('Manifest-Version: 1.0\nPremain-Class: OrientationProbeAgent\nCan-Retransform-Classes: true\n\n')
            agent=work/'probe-agent.jar'
            result,log=command('agent',[jdk/'jar.exe','cfm',agent,manifest,'-C',classes,'.'],work)
            if result.returncode: raise AssertionError('agent packaging: '+log)
            expected=set(re.findall(r'check\("([a-z0-9_]+)"',(HERE/'cases.lua').read_text()))
            texts={name:path.read_text(encoding='utf-8-sig') for name,path in runtime.items()}
            native_text=sources[0].read_text()
            def execute(label,changes=(),native_change=None):
                paths={};modified=dict(texts);leading=[]
                for change in changes:
                    key,before,after=change[:3];count=change[3] if len(change)>3 else 1
                    if modified[key].count(before)!=count:raise AssertionError('nonunique control '+label)
                    modified[key]=modified[key].replace(before,after)
                for key,value in modified.items():
                    paths[key]=out/(label+'-'+key+'.lua');paths[key].write_text(value,encoding='utf-8')
                if native_change:
                    changed=native_text
                    for before,after in native_change:
                        if changed.count(before)!=1:raise AssertionError('nonunique native control '+label)
                        changed=changed.replace(before,after)
                    directory=work/label;directory.mkdir()
                    retained=out/'controls'/label;retained.mkdir(parents=True)
                    source=retained/'SAOWorldSoundPulses.java';source.write_text(changed)
                    result,log=command('compile-'+label,[jdk/'javac.exe','-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,'-d',directory,source],work)
                    if result.returncode:raise AssertionError('control compile '+label+log[-2000:])
                    leading=[directory]
                run_cp=os.pathsep.join(map(str,[*leading,classes,*jars]))
                argv=[jdk/'java.exe','-Duser.home='+str(work),'-Djava.library.path='+str(game),'-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-javaagent:'+str(agent),'-cp',run_cp,'PulseParticipationProbe',game,
                    fixture[0],*native,fixture[1],paths['Needs'],paths['Gesture'],paths['Perception'],fixture[2]]
                result,log=command(label,argv,work)
                rows=re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',log,re.M)
                if result.returncode or 'PULSE_PARTICIPATION_DONE' not in log or len(rows)!=len(expected) or {r[0] for r in rows}!=expected:
                    raise AssertionError(label+' incomplete: '+log[-5000:])
                return {name for name,value in rows if value=='false'}
            failed=execute('baseline')
            if failed:raise AssertionError('baseline failed '+str(sorted(failed)))
            receipt['checks']=len(expected)
            if args.orientation_baseline:
                argv=[jdk/'java.exe','-Duser.home='+str(work),'-Djava.library.path='+str(game),
                    '--enable-native-access=ALL-UNNAMED','-javaagent:'+str(agent),'-cp',str(classes)+os.pathsep+cp,
                    'OrientationProbe',ROOT,game]
                result,log=command('orientation-baseline',argv,game)
                rows=re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',log,re.M)
                if result.returncode or len(rows)!=93 or len({x[0] for x in rows})!=93 or any(x[1]!='true' for x in rows):
                    raise AssertionError('affected orientation baseline: '+log[-4000:])
                receipt['orientationBaseline']=len(rows)
            controls=[
                ('omit-emission-binding',[('Gesture','state.occurrence = occurrence','state.occurrence = nil')],None,'actual_owned_native_emission_has_detached_occurrence'),
                ('omit-listener-owner',[('Perception','not needs.ownsRecoveryBody(id, body) or not needs.ownsRecoveryBody(performerId, performer)','false',2)],None,'current_body_and_token_custody_required'),
                ('omit-private-replay',[],[('heard.claimed.contains(pulseId)','false'),('emission.claims().containsKey(observer)','false')],'scanner_hearing_and_visible_emitter_create_once_private_receipt'),
                ('omit-emission-replay',[],[('emission.claims().containsKey(observer)','false')],'receipt_replay_refuses_after_native_heard_cache_eviction'),
                ('omit-current-visibility',[],[('|| !SAOPerceptionScanner.canSeePersonNow(observer, body, 16)','')],'current_visibility_loss_refuses_attribution'),
                ('invent-emitter-witness',[],[('SAOPerceptionScanner.canSeePersonNow(observer, emitter, 16)','true')],'seeing_later_does_not_relabel_past_anonymous_acquisition'),
                ('omit-performer-generation',[],[('!Objects.equals(emission.bodyToken(), body.getModData().rawget("SAOExternalToken"))','false')],'performer_generation_change_refuses_native_claim'),
                ('omit-listener-generation',[],[('heard == null || !heard.owns(observer) || heard.claimed.contains(pulseId)','heard == null || heard.claimed.contains(pulseId)')],'listener_generation_cannot_consume_old_acquisition'),
                ('omit-hearing-expiry',[],[('private static final double CLAIM_HORIZON_HOURS = 0.05;','private static final double CLAIM_HORIZON_HOURS = 100;')],'native_clock_reversal_and_expiry_refuse'),
                ('omit-exact-work',[],[('!emission.workId().equals(workId)','false')],'unacquired_wrong_work_or_performer_refused'),
                ('omit-pooled-reuse',[],[('EMISSIONS.remove(sound); // A pooled object\'s new init is another occurrence.',''),('PULSES.get(entry.getKey()) != acquired','false')],'native_pool_reuse_invalidates_old_occurrence'),
                ('accept-future-wire',[('Perception','or row.atHours > nativeNow','')],None,'malformed_or_future_receipt_cannot_become_private_evidence'),
            ]
            if not args.baseline_only:
                for name,changes,native_change,marker in controls:
                    failed=execute(name,changes,native_change)
                    if marker not in failed:raise AssertionError(name+' missed exact '+marker)
                    receipt['controls'].append(dict(name=name,expectedFailure=marker,failures=sorted(failed)))
            receipt['inputsAfter']={str(p):sha(p) for p in inputs}
            if receipt['inputsAfter']!=receipt['inputsBefore']:raise AssertionError('input drift')
            receipt['status']='PASS'
    except Exception as error:
        receipt['failure']=str(error);save();print('FAIL participation pulse:',error);return 1
    save();print('PASS participation pulse',receipt['checks'],'checks',len(receipt['controls']),'controls');return 0


if __name__=='__main__':
    raise SystemExit(main())
