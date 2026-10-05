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
HERE = ROOT / 'tools/participation_integration_checks'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--baseline-only', action='store_true')
    parser.add_argument('--controls', nargs='+')
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
        ROOT/'tools/orienting_checks/OrientationProbeAgent.java',ROOT/'tools/participation_pulse_checks/PulseParticipationProbe.java']
    if args.orientation_baseline: sources.append(ROOT/'tools/orienting_checks/OrientationProbe.java')
    runtime = {name:ROOT/'mod/42.20/media/lua'/area/('SAO_'+name+'.lua') for name,area in
        [('Needs','client'),('Gesture','client'),('Perception','shared'),('ProceduralPlanning','shared'),('Organization','shared'),('Communication','shared'),('Coordination','shared')]}
    native = [game/'media/lua/shared/ISBaseObject.lua',game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
        game/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
    fixture = [ROOT/'tools/instrument_checks/prelude.lua',ROOT/'tools/instrument_checks/setup.lua',HERE/'setup.lua',HERE/'cases.lua']
    inputs = list(dict.fromkeys(sources+jars+native+fixture+list(runtime.values())+[Path(__file__),
        ROOT/'java/src/com/sao/engine/SAOPerceptionScanner.java',ROOT/'java/src/com/sao/engine/SAOSenses.java',
        ROOT/'java/src/com/sao/agent/SAOOrientationWeave.java',game/'media/scripts/generated/items/normal.txt',
        game/'media/scripts/generated/items/weapon.txt',game/'stdlib.lua']))
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, game, jdk, "participation integration")
    if preflight is not None:
        raise SystemExit(preflight)
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    receipt = dict(status='INCOMPLETE',inputsBefore={str(p):sha(p) for p in inputs},commands=[],controls=[],
        boundary='Actual coordination, communication, organization, planning and installed native instrument/scanner owners. Controlled private interests and loaded geometry/audio hardware. No rendered gameplay, pleasure/trust/mastery claim.')
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
                    fixture[0],*native,fixture[1],paths['Needs'],paths['Gesture'],paths['Perception'],fixture[2],paths['ProceduralPlanning'],paths['Organization'],paths['Communication'],paths['Coordination'],fixture[3]]
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
                ('omit-returned-assent',[('Organization', 'if not response or response.response ~= "accept" or not response.delivered\n        or not finite(response.deliveredAt) or response.deliveredAt > nowHours()\n        or not participationCommitment(process, terms.listenerId) then return nil end','')],None,'response_must_return_before_performance'),
                ('invent-acknowledgement',[('Organization','local a, p = own and own.acknowledgement, own and own.performance','local a, p = own and (own.acknowledgement or {workId=own.workId, deliveredAt=nowHours()}), own and own.performance')],None,'heard_without_return_does_not_complete_performer'),
                ('omit-ack-transport',[('Organization','if not process or not participationTransport(processId, fromId, toId, kind) then return false end','if not process then return false end')],None,'heard_without_return_does_not_complete_performer'),
                ('omit-private-appraisal',[('Organization','if process and process.kind == "leisure-participation" and not (SAO.Coordination\n        and SAO.Coordination.participationAuthority\n        and SAO.Coordination.participationAuthority("appraisal", personId, processId)) then return nil end','')],None,'generic_result_and_caller_authored_assent_refused'),
                ('omit-native-admission-authority',[('Organization','if process and process.kind == "leisure-participation" and authority ~= PARTICIPATION then return false end','',2)],None,'generic_result_and_caller_authored_assent_refused'),
                ('ignore-personal-interest',[('Coordination','elseif interests.related or wantsCompany then','elseif true then')],None,'recipient_independently_declines_or_defers'),
                ('ignore-own-intention',[('Coordination','elseif not available or obligations or interests.competing then','elseif not available or obligations then')],None,'own_unfinished_material_need_defers_same_invitation'),
                ('ignore-existing-obligation',[('Coordination','elseif not available or obligations or interests.competing then','elseif not available or interests.competing then')],None,'other_accepted_obligation_defers_same_invitation'),
                ('omit-current-prequeue-readiness',[('Organization','if offer and not SAO.Coordination.participationOffer(id, SAO.Body.get(id), c.id) then return false end','')],None,'stale_body_or_current_danger_prevents_prequeue_performance'),
                ('omit-current-revision',[('Organization','binding.revision ~= process.revision','false')],None,'current_item_and_revision_required_at_native_admission'),
                ('omit-current-transport-owner',[('Communication','return needs and needs.ownsRecoveryBody and bodies and bodies.get\n        and needs.ownsRecoveryBody(fromId, bodies.get(fromId))\n        and needs.ownsRecoveryBody(toId, bodies.get(toId)) or false','return true')],None,'current_generation_required_for_returned_assent'),
                ('omit-lost-owner-handback',[('ProceduralPlanning','SAO.Organization.reconcileParticipation(purpose.participation.processId, id, purpose.id)','')],None,'lost_runtime_reconciles_to_unobservable_not_completion'),
                ('discard-suspended-sharing',[('ProceduralPlanning','or s.suspendedLeisure and s.suspendedLeisure.purposes[purposeId]','')],None,'suspended_sharing_receives_exact_result_without_active_capacity'),
                ('omit-expiry',[('Organization','or terms.expiresAtHours < nowHours()','')],None,'expired_proposal_cannot_execute_but_intention_can_be_reoffered'),
                ('retain-transport-capability',[('Communication','admitted, evidence or {})\n        participationTransport = nil','admitted, evidence or {})')],None,'transport_exception_retires_transient_delivery_authority'),
                ('omit-real-learning-intention',[('ProceduralPlanning','or p.domain == "learning" then out.competing = true end','or p.study then out.competing = true end')],None,'actual_unfinished_study_intention_enters_private_comparison'),
            ]
            if not args.baseline_only:
                for name,changes,native_change,marker in controls:
                    if args.controls and name not in args.controls: continue
                    failed=execute(name,changes,native_change)
                    if marker not in failed:raise AssertionError(name+' missed exact '+marker)
                    receipt['controls'].append(dict(name=name,expectedFailure=marker,failures=sorted(failed)))
            receipt['inputsAfter']={str(p):sha(p) for p in inputs}
            if receipt['inputsAfter']!=receipt['inputsBefore']:raise AssertionError('input drift')
            receipt['status']='PASS'
    except Exception as error:
        receipt['failure']=str(error);save();print('FAIL participation integration:',error);return 1
    save();print('PASS participation integration',receipt['checks'],'checks',len(receipt['controls']),'controls');return 0


if __name__=='__main__':
    raise SystemExit(main())
