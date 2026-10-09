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
PERSONAL_CASES=ROOT/'tools/d2_leisure_choice/personal_cases.lua'
PAIRED_CASES=ROOT/'tools/d2_leisure_choice/paired_order_cases.lua'
HOBBY_CASES=ROOT/'tools/d2_leisure_choice/hobby_cases.lua'
GAME_INPUT_CASES=ROOT/'tools/d2_leisure_choice/game_input_cases.lua'
GAME_INPUT_CONTROLS=[
 ('ignore-native-game-body','cognition','or not SAO.Needs.ownsRecoveryBody(id,body) or not P or not P.hobbyAdmission','or not P or not P.hobbyAdmission','foreign_body_cannot_submit'),
 ('borrow-game-frame','cognition','if not scene or scene.actorId~=id or scene.status','if not scene or scene.status','foreign_source_frame_cannot_submit'),
 ('ignore-current-presentation','cognition','or scene.atHours~=now','','old_source_presentation_cannot_submit'),
 ('ignore-game-purpose','plan','if not terminal and (purpose.status~="maintained" or not step or step.id~="perform-activity"','if not terminal and (not step or step.id~="perform-activity"','retired_purpose_cannot_submit'),
 ('ignore-personal-curiosity','cognition','local value=SAO.Disposition and SAO.Disposition.curiosity and SAO.Disposition.curiosity(id)','local value={effective=.5}','personal_curiosity_changes_source_selected_input'),
 ('ignore-presented-instruction','cognition','+instruction,','+0,','presented_instruction_changes_selected_control'),
]

HOBBY_CONTROLS=[
    ('generic-hobby-authority','cognition',' or HOBBY_KINDS[supplied.kind]','','generic_caller_cannot_publish_hobby'),
    ('forget-hobby-learning','models','elseif HOBBY_KINDS[e.kind] then retain("hobby", "leisure", e.succeeded,e.actionKind)','elseif HOBBY_KINDS[e.kind] then -- forgotten native attempt','interruption_changes_later_prediction'),
    ('manufacture-hobby-success','cognition','receipt.activity,receipt.status=="completed"','receipt.activity,true','interruption_changes_later_prediction'),
    ('retired-purpose-result','plan','if not alreadyConsumed and (purpose.status~="maintained" or purpose.admission~=admission) then return false end','-- allow retired result','retired_purpose_cannot_be_revived'),
    ('unconsumed-terminal-authority','plan','if not consumed then return nil end','-- unconsumed terminal admitted','unconsumed_outcome_cannot_teach'),
    ('omit-urgent-interruption','controller','if urgent then Ctl.interruptLeisure(id,agent,body,"urgent need or owned conflict");return false end','-- urgent need ignored','native_need_interrupts_current_hobby'),
    ('reuse-completed-hobby','plan','not (purpose.hobby and (purpose.status=="completed" or purpose.status=="abandoned"))','true','repeat_session_gets_new_purpose'),
]
PERSONAL_CONTROLS=[
    ('omit-normal-cognition-start','cognition','C.ensureGameDefaults()\n        C.rebindWorld()','C.rebindWorld()','normal_start_initializes_existing_cognitive_budget'),
    ('overwrite-saved-cognition-setting','cognition','if data and data.settings~=nil then return true,"saved-settings" end','if false then return true,"saved-settings" end','saved_disabled_setting_survives_normal_reload'),
    ('truncate-source-pool','local purpose=planning and planning.pending and planning.pending(id,"recreate",activity)',
     'if #candidates>=130 then return end;local purpose=planning and planning.pending and planning.pending(id,"recreate",activity)','all_providers_reach_personal_comparison_pool'),
    ('omit-model-budget','candidates,comparison=Ctl.limitPurposeComparison(id,candidates,comparisonContext)',
     'comparison={offered=#candidates,compared=#candidates,omitted={}}','overfull_pool_still_selects_through_actual_models'),
    ('ignore-native-boredom','out.boredom=boredom/100','out.boredom=0','native_boredom_changes_ordinary_comparison'),
    ('ignore-private-valence','out.interest=total/count','out.interest=0','dated_valence_changes_actual_selected_receiver'),
    ('borrow-foreign-recall','episode.actorId==id and episode.ownerId==id','true','foreign_episode_cannot_supply_interest'),
    ('ignore-read-cooldown','if reading and not body:tooDarkToRead() and tick >= (agent.nextPageAt or 0) then','if reading and not body:tooDarkToRead() then','cooldown_removes_reading_before_comparison'),
    ('dispatch-first-leisure','receiver=type(offered)=="table" and offered.payload','receiver=type(offered)=="table" and {kind="instrument",item=__harmonica,capability=SAO.Needs.instrumentCapability(__harmonica)}','dated_valence_changes_actual_selected_receiver'),
    ('generic-duet-partner','controller','condition="duet:"..invitation.recipientId','condition="duet:anyone"','two_conversable_contacts_have_separate_real_invitation_candidates'),
    ('forget-completed-duet','models','retain("hobby","leisure",true,"duet:"..e.partnerId)','-- no exact partner evidence','normal_start_source_duet_reaches_private_future_choice'),
    ('generic-dance-partner','controller','condition="dance:"..invitation.recipientId','condition="dance:anyone"','two_contacts_have_separate_native_dance_invitations'),
    ('forget-completed-dance','models','retain("hobby","leisure",true,"dance:"..e.partnerId)','-- no exact dance partner evidence','completed_source_dance_informs_exact_partner_choice'),
]
PAIRED_CONTROLS=[
    ('use-source-order-as-delivery','cognition','local position=cursors and cursors[producer] or 0',
     'local position=receipt.sequence-1','duet_out_of_order_both_exact_partners_learn'),
    ('lose-source-work-order','cognition','x.sourceWorkSequence=receipt.sequence',
     'x.sourceWorkSequence=position','duet_out_of_order_keeps_source_and_delivery_positions'),
    ('forget-paired-claims','cognition','local prior=claims[key]',
     'local prior=nil','evicted_duet_replay_does_not_relearn_after_reload'),
    ('allow-conflicting-receipt','cognition','or prior.workId~=receipt.workId',
     'or false','same_process_revision_conflict_does_not_relearn'),
    ('discard-live-source-claims','cognition','if processes[row.processId] then held[#held+1]=claimKey',
     'if false then held[#held+1]=claimKey','live_source_process_claims_hold_capacity'),
    ('retain-retired-source-claims','cognition','if processes[row.processId] then held[#held+1]=claimKey',
     'if true then held[#held+1]=claimKey','retired_source_process_reclaims_one_claim_slot'),
]
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
    parser.add_argument('--personal',action='store_true',help='Native mood, dated private recall and ordinary leisure dispatch.')
    parser.add_argument('--paired-order',action='store_true',help='Out-of-order duet/dance results, replay, and source-owned claim bounds.')
    parser.add_argument('--game-input',action='store_true',help='Source presented scene to private curiosity and actual valid input dispatch.')
    parser.add_argument('--hobby',action='store_true',help='Typed owner/planner/cognition join and current native body lifecycle.')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    probe=ROOT/'tools/instrument_checks/InstrumentProbe.java'
    java=[ROOT/'tools/luacheck/MovementCrossingProbe.java',ROOT/'tools/luacheck/ResourceApproachProbe.java',
          ROOT/'tools/cognition_checks/CognitionUseProbe.java']
    jars=[GAME/'projectzomboid.jar',GAME/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua',
            GAME/'media/lua/client/TimedActions/ISInventoryTransferAction.lua',GAME/'media/lua/shared/TimedActions/ISReadABook.lua']
    perception=LUA/'shared/SAO_Perception.lua'
    assert sum((args.personal,args.paired_order,args.resumption,args.hobby,args.game_input))<=1,'select one instrument'
    inputs=[perception,Path(__file__),CASES,*([RESUMPTION_CASES] if args.resumption else []),*([PERSONAL_CASES] if args.personal else []),*([PAIRED_CASES] if args.paired_order else []),probe,*java,*jars,*native,*RUNTIME.values(),GAME/'stdlib.lua',
            *[GAME/'media/scripts/generated/items'/name for name in ('normal.txt','weapon.txt','literature.txt')]]
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    if args.hobby:inputs.append(HOBBY_CASES)
    if args.game_input:
        inputs.extend([GAME_INPUT_CASES,LUA/'shared/SAO_Disposition.lua'])
    preflight = installed_presence(inputs, GAME, JDK, "d2 leisure choice")
    if preflight is not None:
        raise SystemExit(preflight)
    pins={str(p):sha(p) for p in inputs}
    receipt={'status':'INCOMPLETE','inputsBefore':pins,'runs':[],
        'boundary':'Installed native shell, exact carried Harmonica/Book/IDcard objects and actual Needs/Study eligibility. Production C/M/P and extracted unmodified Controller rest dispatcher. Prior canonical Gesture receipts and physical admission receivers controlled; no rendered or audible world claim.'}
    if args.resumption:receipt['boundary']='Installed native body and serialization; production C/M/P/Needs and extracted unmodified Controller ordinary chooser. Authored outcome admission and conflict appraisal/queue are actual owners; private threat/trait/route availability and Labor stock observation are controlled inputs. No game, native material completion, or rendered claim.'
    if args.personal:receipt['boundary']='Installed native owned bodies, native Stats and exact carried objects; production C/M/P/Needs/Study and extracted unmodified Controller ordinary chooser and leisure dispatch. Dated personal recall and physical admission are controlled inputs. This verifies their influence on actual comparison and receiver dispatch, with no rendered participation claim.'
    if args.paired_order:receipt['boundary']='Production Cognition and CognitiveModels with installed native-shell runtime. Organization exact duet/dance participation receipts and process retention are controlled. Both source work order and private delivery order, serialized replay after bounded event eviction, conflict refusal, and retained/reclaimed claim capacity are verified; loaded game participation and visual behavior are not observed.'
    if args.game_input:receipt['boundary']='Installed native body and actual Planner/Cognition/Models/Disposition choose and dispatch canonical valid source controls; scene and activity source receiver are controlled. Curiosity provenance, private trial memory, current frame, purpose/body custody and no outcome/XP credit are tested; source-engine and rendered gameplay are separately qualified.'
    if args.hobby:receipt['boundary']='Installed native owned bodies/Stats and production Planner/Cognition/Models/Needs/Study, plus extracted unmodified Controller leisure lifecycle. Canonical activity owner work/results and source retirement are controlled; source native participation and skill are independently proved by each producer. No rendered or source-action completion claim from this join.'
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
            if args.personal:cases=PERSONAL_CASES.read_text(encoding='utf-8')
            if args.paired_order:cases=PAIRED_CASES.read_text(encoding='utf-8')
            if args.hobby:cases=HOBBY_CASES.read_text(encoding='utf-8')
            if args.game_input:cases=GAME_INPUT_CASES.read_text(encoding='utf-8')
            owner=perception.read_text(encoding='utf-8-sig')
            sorter=owner.split('local function sortSightEvidence(',1)[1].split('local function zombieReports(',1)[0]
            prelude+='\nSAO.Perception=SAO.Perception or {}\nlocal P=SAO.Perception\nlocal function sortSightEvidence('+sorter
            (out/'prelude.lua').write_text(prelude,encoding='utf-8');(out/'cases.lua').write_text(cases,encoding='utf-8')
            runtime={key:p.read_text(encoding='utf-8-sig') for key,p in RUNTIME.items()}
            for key in ('needs','study','plan','models','cognition'):(out/(key+'.lua')).write_text(runtime[key],encoding='utf-8')
            expected=len(re.findall(r"check\('[a-z0-9_]+",cases))
            if args.hobby:expected=78 # Seven independent providers, with typed experience and lifecycle joins.
            if args.paired_order:expected=272 # Two pairs, 258 retained source outcomes, replay, conflict and capacity.
            controls=GAME_INPUT_CONTROLS if args.game_input else HOBBY_CONTROLS if args.hobby else PAIRED_CONTROLS if args.paired_order else PERSONAL_CONTROLS if args.personal else RESUMPTION_CONTROLS if args.resumption else CONTROLS
            variants=[('production',None,None,None)]
            if not args.baseline_only:variants += [row for row in controls if not args.control or row[0] in args.control]
            assert set(args.control)<={x[0] for x in controls}
            receipt['checks']=expected;receipt['controls']=[]
            for variant in variants:
                if len(variant)==5:name,target,before,after,marker=variant
                else:name,before,after,marker=variant;target='controller'
                texts=dict(runtime)
                if before:
                    assert texts[target].count(before)==1,(name,texts[target].count(before))
                    texts[target]=texts[target].replace(before,after,1)
                for key in ('needs','study','plan','models','cognition'):(out/(key+'.lua')).write_text(texts[key],encoding='utf-8')
                source=texts['controller']
                if args.personal or args.paired_order or args.hobby or args.game_input:
                    helpers='function Ctl.leisureReasons('+source.split('function Ctl.leisureReasons(',1)[1].split('function Ctl.beginConceptInquiry(',1)[0]
                    dispatcher='function Ctl.dispatchOrdinaryPurpose('+source.split('function Ctl.dispatchOrdinaryPurpose(',1)[1].split('-- A failed home route',1)[0]
                    source='local Ctl=SAO.Controller\nlocal function policy()return {desperation=.7}end\nlocal function resolvedHomeAddress()return nil end\nlocal function mayEnterBelieved()return false end\nlocal function rememberedRecoveryInquiry()return false end\n'+helpers+dispatcher
                elif args.resumption:
                    limiter='function Ctl.limitPurposeComparison('+source.split('function Ctl.limitPurposeComparison(',1)[1].split('function Ctl.beginLeisureOffer(',1)[0]
                    reconciliation='function Ctl.reconcileLeisureCommitment('+source.split('function Ctl.reconcileLeisureCommitment(',1)[1].split('function Ctl.advanceLeisureParticipation(',1)[0]
                    source='function Ctl.chooseOrdinaryPurpose('+source.split('function Ctl.chooseOrdinaryPurpose(',1)[1].split('function Ctl.beginConceptInquiry(',1)[0]
                    source='local Ctl=SAO.Controller\nlocal function policy()return {desperation=.7}end\nlocal function resolvedHomeAddress()return nil end\nlocal function mayEnterBelieved()return false end\nlocal function rememberedRecoveryInquiry()return false end\n'+limiter+reconciliation+source
                else:
                    assert source.count('local function decideRestActivity(')==1
                    invitation = 'function Ctl.proposeLeisureParticipation(' + source.split('function Ctl.proposeLeisureParticipation(',1)[1].split('local function decideRestActivity(',1)[0]
                    source=source.split('local function decideRestActivity(',1)[1].split('local function decideLocalResources(',1)[0]
                    source='local Ctl=SAO.Controller\n'+invitation+'\nfunction __restActivity('+source
                controller=out/(name+'-controller.lua');controller.write_text(source,encoding='utf-8')
                code,log=invoke(name,[JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'D2LeisureChoiceProbe',GAME,
                    out/'prelude.lua',*native,out/'needs.lua',out/'plan.lua',out/'study.lua',out/'models.lua',out/'cognition.lua',
                    controller,*([LUA/'shared/SAO_Disposition.lua'] if args.game_input else []),out/'cases.lua'],work)
                if marker:
                    assert code!=0 and ('D2_GAME_INPUT:' if args.game_input else 'D2_HOBBY_JOIN:' if args.hobby else 'D2_PAIRED_ORDER:' if args.paired_order else 'D2_PERSONAL:' if args.personal else 'D2_RESUMPTION:' if args.resumption else 'D2_LEISURE_CHOICE:')+marker in log,(name,log[-3000:])
                    receipt['controls'].append({'name':name,'expectedFailure':marker})
                else: assert code==0 and ('PASS D2 game input ' if args.game_input else 'PASS D2 hobby join ' if args.hobby else 'PASS D2 paired order ' if args.paired_order else 'PASS D2 personal ' if args.personal else 'PASS D2 resumption ' if args.resumption else 'PASS D2 leisure choice ')+str(expected) in log,log[-5000:]
            receipt['inputsAfter']={str(p):sha(p) for p in inputs}
            assert pins==receipt['inputsAfter'],'source inputs changed'
            receipt['status']='PASS'
    except Exception as error:
        receipt['failure']=str(error);save();print('FAIL',error);return 1
    save();print('PASS leisure choice',receipt['checks'],'checks',len(receipt['controls']),'controls');return 0

if __name__=='__main__':raise SystemExit(main())
