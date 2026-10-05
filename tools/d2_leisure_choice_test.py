#!/usr/bin/env python3
"""Actual Controller dispatch from private learned expectations and installed item eligibility."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,tempfile
from native_proof_preflight import installed_presence
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
CASES=ROOT/'tools/d2_leisure_choice/cases.lua'
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LUA=ROOT/'mod/42.20/media/lua'
RUNTIME={key:LUA/directory/('SAO_'+name+'.lua') for key,directory,name in [
    ('controller','client','Controller'),('needs','client','Needs'),('study','client','Study'),
    ('plan','shared','ProceduralPlanning'),('models','shared','CognitiveModels'),('cognition','shared','Cognition')]}
CONTROLS=[
    ('ignore-learned-selection','local chosen = views and offered[views.selected]',
     'local chosen = views and offered[candidates[1].id]','negative_native_evidence_changes_actual_receiver'),
    ('omit-sound-consequence','sourceId = "native:sound:BlowHarmonica", itemType = material:getFullType(), value = 1',
     'sourceId = "native:sound:BlowHarmonica", itemType = material:getFullType(), value = 0','negative_native_evidence_changes_actual_receiver'),
    ('ignore-instrument-cooldown','if material and capability and tick >= (agent.nextTuneAt or 0) then',
     'if material and capability then','instrument_cooldown_precedes_learned_preference'),
    ('ignore-reading-cooldown','if offeredReading and not body:tooDarkToRead() and tick >= (agent.nextPageAt or 0) then',
     'if offeredReading and not body:tooDarkToRead() then','reading_cooldown_removes_unavailable_alternative'),
    ('omit-purpose-continuity','continuity = retained and 1 or 0, novelty = retained and 0 or 1,',
     'continuity = 0, novelty = 1,','maintained_exact_reading_purpose_supplies_continuity'),
    ('borrow-other-item-purpose','purpose and purpose.leisure and purpose.leisure.itemKey == itemKey',
     'purpose and purpose.leisure','another_item_purpose_cannot_supply_continuity'),
    ('refusal-held-past-retry','if not agent.pressure or agent.pressure.phase == "refused"\n        or tick - (agent.pressure.at or 0) > 600 then',
     'if not agent.pressure or tick - (agent.pressure.at or 0) > 600 then','refused_instrument_allows_next_call_reading_during_retry_window'),
]
RESUMPTION_CASES=ROOT/'tools/d2_leisure_choice/resumption_cases.lua'
RESUMPTION_CONTROLS=[
    ('omit-queued-resumption','resumedPurpose = planning.resumeQueuedPurpose(id, queued.id)',
     'resumedPurpose = nil','ordinary_choice_revives_exact_obligation'),
    ('omit-current-agent','and Ctl.agents[id] == agent and agent.rec == SAO.Identity.get(id)',
     'and agent.rec ~= nil','detached_agent_cannot_restore_canonical_queue'),
    ('ignore-native-work','and SAO.Needs.workAvailable(body)\n        and not (route and not route.done)',
     'and true\n        and not (route and not route.done)','sleeping_body_cannot_resume'),
    ('ignore-private-threat','or SAO.Perception.believedThreatCount(id, tick, 10, body:getX(), body:getY()) > 0',
     'or false','private_current_threat_preserves_queue'),
    ('ignore-conflict-priority','and not (conflict and conflict.gesturePriority and conflict.gesturePriority(id, body))',
     'and true','owned_conflict_hold_preserves_queue'),
    ('ignore-retry-boundary','and agent.queuedPurposeResumeTick ~= tick and not studying',
     'and not studying','same_tick_retry_cannot_rotate_queue'),
]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--baseline-only',action='store_true')
    parser.add_argument('--control',action='append',default=[])
    parser.add_argument('--resumption',action='store_true',help='Only the queued-purpose ordinary consumer contract.')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
    java=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',
          ROOT/'tools/cognition_checks/CognitionUseProbe.java']
    jars=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
            GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',GAME/'media/lua/shared/TimedActions/ISReadABook.lua']
    perception=LUA/'shared/SAO_Perception.lua'
    inputs=[perception,Path(__file__),CASES,*([RESUMPTION_CASES] if args.resumption else []),probe,*java,*jars,*native,*RUNTIME.values(),GAME/'stdlib.lua',
            *[GAME/'media/scripts/generated/items'/name for name in ('normal.txt','weapon.txt','literature.txt')]]
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, GAME, JDK, "d2 leisure choice")
    if preflight is not None:
        raise SystemExit(preflight)
    pins={str(p):sha(p) for p in inputs}
    receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],
        'boundary':'Installed native shell, exact carried Harmonica/Book/IDcard objects and actual Needs/Study eligibility. Production C/M/P and extracted unmodified Controller rest dispatcher. Prior canonical Gesture receipts and physical admission receivers controlled; no rendered or audible world claim.'}
    if args.resumption:receipt['boundary']='Installed native body and serialization; production C/M/P/Needs and extracted unmodified Controller ordinary chooser. Authored outcome admission and conflict appraisal/queue are actual owners; private threat/trait/route availability and Labor stock observation are controlled inputs. No game, native material completion, or rendered claim.'
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(label,command,cwd):
        result=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=90)
        log=out/(label+'.log');log.write_bytes(result.stdout+result.stderr)
        receipt['runs'].append({'name':label,'command':list(map(str,command)),'cwd':str(cwd),
            'exitCode':result.returncode,'log':str(log),'logSha256':sha(log)});save()
        return result.returncode,log.read_text(encoding='utf-8',errors='replace')
    try:
        with tempfile.TemporaryDirectory(prefix='sao-leisure-choice-') as temporary:
            work=Path(temporary);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua')
            text=probe.read_text().replace('public final class InstrumentProbe','public final class D2LeisureChoiceProbe')
            before='{"weapon.txt","GuitarAcoustic","__guitar"}'
            assert text.count(before)==1
            text=text.replace(before,before+',{ "literature.txt","Book","__book"},{"literature.txt","IDcard_Male","__idcard"}')
            text=text.replace('InventoryItem.class,zombie.inventory.ItemContainer.class',
                'InventoryItem.class,zombie.inventory.types.Literature.class,zombie.scripting.objects.CharacterTrait.class,zombie.inventory.ItemContainer.class')
            generated=out/'D2LeisureChoiceProbe.java';generated.write_text(text,encoding='utf-8')
            cp=os.pathsep.join(map(str,jars))
            code,log=invoke('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*java,generated],work)
            assert code==0,log
            prelude,cases=CASES.read_text().split('-- CASES',1)
            if args.resumption:cases=RESUMPTION_CASES.read_text()
            owner=perception.read_text(encoding='utf-8-sig')
            sorter=owner.split('local function sortSightEvidence(',1)[1].split('local function zombieReports(',1)[0]
            prelude+='\nSAO.Perception=SAO.Perception or {}\nlocal P=SAO.Perception\nlocal function sortSightEvidence('+sorter
            (out/'prelude.lua').write_text(prelude,encoding='utf-8');(out/'cases.lua').write_text(cases,encoding='utf-8')
            runtime={key:p.read_text(encoding='utf-8-sig') for key,p in RUNTIME.items()}
            for key in ('needs','study','plan','models','cognition'):(out/(key+'.lua')).write_text(runtime[key],encoding='utf-8')
            expected=len(re.findall(r"check\('[a-z0-9_]+",cases))
            controls=RESUMPTION_CONTROLS if args.resumption else CONTROLS
            variants=[('production',None,None,None)]
            if not args.baseline_only:variants += [row for row in controls if not args.control or row[0] in args.control]
            assert set(args.control)<={x[0] for x in controls}
            receipt['checks']=expected;receipt['controls']=[]
            for name,before,after,marker in variants:
                source=runtime['controller']
                if before:
                    assert source.count(before)==1,name
                    source=source.replace(before,after,1)
                if args.resumption:
                    reconciliation='function Ctl.reconcileLeisureCommitment('+source.split('function Ctl.reconcileLeisureCommitment(',1)[1].split('function Ctl.advanceLeisureParticipation(',1)[0]
                    source='function Ctl.chooseOrdinaryPurpose('+source.split('function Ctl.chooseOrdinaryPurpose(',1)[1].split('function Ctl.beginConceptInquiry(',1)[0]
                    source='local Ctl=SAO.Controller\nlocal function policy()return {desperation=.7}end\nlocal function resolvedHomeAddress()return nil end\nlocal function mayEnterBelieved()return false end\nlocal function rememberedRecoveryInquiry()return false end\n'+reconciliation+source
                else:
                    assert source.count('local function decideRestActivity(')==1
                    invitation = 'function Ctl.proposeLeisureParticipation(' + source.split('function Ctl.proposeLeisureParticipation(',1)[1].split('local function decideRestActivity(',1)[0]
                    source=source.split('local function decideRestActivity(',1)[1].split('local function decideLocalResources(',1)[0]
                    source='local Ctl=SAO.Controller\n'+invitation+'\nfunction __restActivity('+source
                controller=out/(name+'-controller.lua');controller.write_text(source,encoding='utf-8')
                code,log=invoke(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'D2LeisureChoiceProbe',GAME,
                    out/'prelude.lua',*native,out/'needs.lua',out/'plan.lua',out/'study.lua',out/'models.lua',out/'cognition.lua',
                    controller,out/'cases.lua'],work)
                if marker:
                    assert code!=0 and ('D2_RESUMPTION:' if args.resumption else 'D2_LEISURE_CHOICE:')+marker in log,(name,log[-3000:])
                    receipt['controls'].append({'name':name,'expectedFailure':marker})
                else: assert code==0 and ('PASS D2 resumption ' if args.resumption else 'PASS D2 leisure choice ')+str(expected) in log,log[-5000:]
            receipt['inputsAfter']={str(p):sha(p) for p in inputs}
            assert pins==receipt['inputsAfter'],'source inputs changed'
            receipt['status']='PASS'
    except Exception as error:
        receipt['failure']=str(error);save();print('FAIL',error);return 1
    save();print('PASS leisure choice',receipt['checks'],'checks',len(receipt['controls']),'controls');return 0

if __name__=='__main__':raise SystemExit(main())
