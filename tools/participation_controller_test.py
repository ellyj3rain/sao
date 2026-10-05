#!/usr/bin/env python3
"""Full Controller dispatch through actual social owners and native instrument/hearing."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from native_proof_preflight import installed_presence

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT / 'tools/participation_controller_checks'
CONTROLS = [
    ('missing-capability-item-type',
     'local started = SAO.Gesture.playInstrument(id, body, capability.verb, offer.itemType, item, purpose.id)',
     'local started = SAO.Gesture.playInstrument(id, body, capability.verb, capability.itemType, item, purpose.id)',
     'ordinary_commitment_dispatch_queues_fresh_exact_native_work'),
    ('omit-ordinary-participation-dispatch',
     'return Ctl.advanceLeisureParticipation(id, agent, body, commitment.id)',
     'return false, "restored-missing-participation-dispatch"',
     'ordinary_commitment_dispatch_queues_fresh_exact_native_work'),
    ('claim-queue-without-native-admission',
     'local started = SAO.Gesture.playInstrument(id, body, capability.verb, offer.itemType, item, purpose.id)',
     'local started = true',
     'ordinary_commitment_dispatch_queues_fresh_exact_native_work'),
    ('monopolize-listener-wait', 'return heard, reason', 'return true, reason',
     'listener_wait_yields_ordinary_dispatch_without_hearing'),
    ('invent-observed-listening', 'phase = heard and "observed" or "intended", owner = "SAO.Coordination", at = at',
     'phase = "observed", owner = "SAO.Coordination", at = at',
     'listener_wait_yields_ordinary_dispatch_without_hearing'),
    ('invent-private-contact', 'local contacts = coordination.knownContacts(id)',
     'local contacts = { { id = "listener" } }',
     'nearby_unobserved_person_is_not_an_invitation_candidate'),
    ('ignore-private-hostility', 'contact.id ~= id and not contact.hostile and SAO.Communication.canConverse(id, contact.id)',
     'contact.id ~= id and SAO.Communication.canConverse(id, contact.id)',
     'privately_hostile_contact_is_not_invited'),
    ('omit-refusal-retry', 'or tick < (agent.nextParticipationAt or 0) then return false end',
     'then return false end',
     'refusal_yields_and_retry_suppresses_only_until_existing_deadline'),
]
SELECTION_CONTROLS = [
    ('restore-food-preflight',
     'function Ctl.coordinationStudyReady(id, body, commitment, plan, step)\n    if commitment.matter == "leisure-participation" then',
     'function Ctl.coordinationStudyReady(id, body, commitment, plan, step)\n    if false then',
     'actual_chooser_selects_music_without_food_and_dispatches_exact_native_work'),
    ('retain-ended-leisure-flag',
     'if not offer or not work or work.workId ~= offer.workId then\n        agent.coordinationCommitment = nil',
     'if not offer or not work or work.workId ~= offer.workId then\n        agent.coordinationCommitment = agent.coordinationCommitment',
     'interrupted_performance_flag_clears_without_completing_sharing'),
    ('omit-ordinary-flag-reconciliation',
     'function Ctl.chooseOrdinaryPurpose(id, agent, body, tick, needs, excluded)\n    Ctl.reconcileLeisureCommitment(id, agent)',
     'function Ctl.chooseOrdinaryPurpose(id, agent, body, tick, needs, excluded)',
     'completed_performance_flag_clears_before_ordinary_recovery_comparison'),
    ('invent-music-delivery',
     'condition=commitment.matter ~= "leisure-participation"',
     'condition=commitment.matter == "leisure-participation" and "deliver" or commitment.matter ~= "leisure-participation"',
     'music_candidate_does_not_predict_material_delivery'),
    ('listener-ready-without-private-hearing',
     'return offer.workId ~= nil and SAO.Perception\n                and SAO.Perception.instrumentHearing(id, offer.performerId, offer.workId) ~= nil',
     'return offer.workId ~= nil',
     'pending_listener_yields_actual_ordinary_choice_without_acquiring_hearing'),
    ('clear-foreign-leisure-flag',
     'if not commitment or commitment.actorId ~= tostring(id)\n        or commitment.matter ~= "leisure-participation" then return end',
     'if not commitment or commitment.matter ~= "leisure-participation" then return end',
     'foreign_actor_commitment_flag_is_not_cleared'),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--baseline-only', action='store_true')
    parser.add_argument('--control', action='append', default=[])
    parser.add_argument('--selection-only', action='store_true', help='Only actual ordinary-choice/lifecycle cases and their controls.')
    args = parser.parse_args()
    controls = SELECTION_CONTROLS if args.selection_only else CONTROLS + SELECTION_CONTROLS
    assert set(args.control) <= {row[0] for row in controls}
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    game = Path(os.environ.get('PZ_DIR', r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk = Path(os.environ.get('JDK_BIN', r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    jars = [game/'projectzomboid.jar', game/'ZombieBuddy.jar', ROOT/'mod/42.20/media/java/SAO.jar']
    # Same installed producer/scanner and fixture as participation_integration_test;
    # compile into this run's private directory, with those classes first on the path.
    java = [ROOT/p for p in [
        'java/src/com/sao/engine/SAOWorldSoundPulses.java', 'java/src/com/sao/bridge/SAOBridge.java',
        'java/src/com/sao/engine/SAOPerceptionScanner.java', 'java/src/com/sao/engine/SAOSenses.java',
        'java/src/com/sao/agent/SAOOrientationWeave.java', 'tools/luacheck/MovementCrossingProbe.java',
        'tools/luacheck/ResourceApproachProbe.java', 'tools/cognition_checks/CognitionUseProbe.java',
        'tools/instrument_checks/InstrumentProbe.java', 'tools/orienting_checks/OrientationProbeAgent.java',
        'tools/participation_pulse_checks/PulseParticipationProbe.java']]
    runtime = {name: ROOT/'mod/42.20/media/lua'/area/('SAO_'+name+'.lua') for name, area in [
        ('Needs','client'), ('Gesture','client'), ('Perception','shared'), ('ProceduralPlanning','shared'),
        ('Organization','shared'), ('Communication','shared'), ('Coordination','shared'), ('Controller','client')]}
    native = [game/'media/lua/shared/ISBaseObject.lua', game/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
              game/'media/lua/client/TimedActions/ISTimedActionQueue.lua']
    prelude = ROOT/'tools/instrument_checks/prelude.lua'
    instrument_setup = ROOT/'tools/instrument_checks/setup.lua'
    social_setup = ROOT/'tools/participation_integration_checks/setup.lua'
    inputs = [Path(__file__), HERE/'setup.lua', HERE/'cases.lua', HERE/'selection_cases.lua', *java, *jars, *native,
              prelude, instrument_setup, social_setup, *runtime.values(), game/'stdlib.lua',
              game/'media/scripts/generated/items/normal.txt', game/'media/scripts/generated/items/weapon.txt']
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, game, jdk, "participation controller")
    if preflight is not None:
        raise SystemExit(preflight)
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    receipt = dict(status='INCOMPLETE', inputsBefore={str(p):sha(p) for p in inputs}, commands=[], controls=[],
        boundary='Complete production Controller module and actual Planning/Organization/Coordination/Communication/Needs/Gesture/Perception. Installed native instrument, action queue, sound occurrence/scanner/visibility. The shared comparison receiver selects the first actual offered candidate, private contacts/relationships/traits/threats and callback scheduling/audio hardware are controlled; unrelated study cancellation is a disclosed controlled receiver. No rendered participation, learned selection, pleasure, trust or mastery claim.')
    def save(): (out/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    def invoke(label, argv, cwd):
        done = subprocess.run(list(map(str, argv)), cwd=cwd, capture_output=True, timeout=100)
        log = out/(label+'.log'); log.write_bytes(done.stdout+done.stderr)
        receipt['commands'].append(dict(label=label, command=list(map(str, argv)), exitCode=done.returncode,
                                        log=str(log), logSha256=sha(log)))
        save(); return done.returncode, log.read_text(encoding='utf-8', errors='replace')
    try:
        with tempfile.TemporaryDirectory(prefix='sao-participation-controller-') as tmp:
            work=Path(tmp); classes=work/'classes'; classes.mkdir(); shutil.copyfile(game/'stdlib.lua',work/'stdlib.lua')
            cp=os.pathsep.join(map(str,jars))
            code, log=invoke('compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',classes,*java],work)
            assert code==0, log[-4000:]
            manifest=work/'MANIFEST.MF'
            manifest.write_text('Manifest-Version: 1.0\nPremain-Class: OrientationProbeAgent\nCan-Retransform-Classes: true\n\n')
            agent=work/'probe-agent.jar'
            code, log=invoke('agent',[jdk/'jar.exe','cfm',agent,manifest,'-C',classes,'.'],work)
            assert code==0, log
            cases=(HERE/'cases.lua').read_text(encoding='utf-8')
            cases=cases.split('check("',1)[0] if args.selection_only else cases.replace('print("PARTICIPATION_CONTROLLER_DONE")','')
            cases+='\n'+(HERE/'selection_cases.lua').read_text(encoding='utf-8')+'\nprint("PARTICIPATION_CONTROLLER_DONE")\n'
            assembled=out/'cases.lua';assembled.write_text(cases,encoding='utf-8')
            expected=set(re.findall(r'check\("([a-z0-9_]+)"',cases))
            text=runtime['Controller'].read_text(encoding='utf-8-sig')
            variants=[('baseline',None,None,None)]
            if not args.baseline_only:
                variants += [row for row in controls if not args.control or row[0] in args.control]
            for label,before,after,marker in variants:
                source=text
                if before:
                    assert source.count(before)==1, 'nonunique control '+label
                    source=source.replace(before,after,1)
                controller=out/(label+'-Controller.lua'); controller.write_text(source,encoding='utf-8')
                code, log=invoke(label,[jdk/'java.exe','-Duser.home='+str(work),'-Djava.library.path='+str(game),
                    '-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-javaagent:'+str(agent),
                    '-cp',str(classes)+os.pathsep+cp,'PulseParticipationProbe',game,prelude,*native,instrument_setup,
                    runtime['Needs'],runtime['Gesture'],runtime['Perception'],social_setup,
                    runtime['ProceduralPlanning'],runtime['Organization'],runtime['Communication'],runtime['Coordination'],
                    HERE/'setup.lua',controller,assembled],work)
                rows=re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',log,re.M)
                assert code==0 and 'PARTICIPATION_CONTROLLER_DONE' in log and len(rows)==len(expected) and {r[0]for r in rows}==expected, (label,log[-5000:])
                failed=sorted(name for name,value in rows if value=='false')
                if marker:
                    assert marker in failed, (label,'missing exact defect',failed)
                    receipt['controls'].append(dict(name=label,expectedFailure=marker,failures=failed))
                else: assert not failed, failed
            receipt['checks']=len(expected)
            receipt['inputsAfter']={str(p):sha(p) for p in inputs}
            assert receipt['inputsBefore']==receipt['inputsAfter'], 'input drift'
            receipt['status']='PASS'
    except Exception as error:
        receipt['failure']=str(error); save(); print('FAIL participation Controller:',error); return 1
    save(); print('PASS participation Controller',receipt['checks'],'checks',len(receipt['controls']),'controls'); return 0


if __name__=='__main__':
    raise SystemExit(main())
