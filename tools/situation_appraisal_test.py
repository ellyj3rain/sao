"""Shared situation questions through actual ordinary arbitration in installed Kahlua.

Production awareness, concepts, health traits, Neuro, planning, cognition,
Controller and Locomotion run with controlled native observation rows, bodies
and movement receipts. This is mechanical proof, not a rendered native trial.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parents[1]
FILES={name:ROOT/f'mod/42.20/media/lua/{scope}/SAO_{module}.lua' for name,scope,module in [
    ('models','shared','CognitiveModels'),('cognition','shared','Cognition'),('needs','client','Needs'),
    ('perception','shared','Perception'),('concepts','shared','ConceptKnowledge'),('awareness','shared','PersonalAwareness'),
    ('disposition','shared','Disposition'),('conditions','shared','Conditions'),('neuro','shared','Neuro'),
    ('situation','shared','SituationAppraisal'),('planning','shared','ProceduralPlanning'),
    ('locomotion','client','Locomotion'),('controller','client','Controller')]}
FILES.update(ordinary=ROOT/'tools/ordinary_purpose_cases.lua',cases=ROOT/'tools/situation_appraisal_cases.lua')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,default=ROOT/'_scratch/d1-situation-appraisal/verification-01')
    ap.add_argument('--baseline-only',action='store_true')
    args=ap.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=fixture.GAME/'projectzomboid.jar'
    runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
    paths=[*FILES.values(),Path(__file__),Path(fixture.__file__),runner,jar,fixture.GAME/'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "situation appraisal")
    if preflight is not None:
        raise SystemExit(preflight)
    pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt={'schema':'sao-situation-appraisal-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],'boundary':__doc__}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(command):
        p=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,text=True,timeout=120)
        return p.returncode,p.stdout+p.stderr
    save();command=[fixture.JDK/'javac.exe','-cp',jar,'-d',out,runner]
    code,log=invoke(command);receipt['compile']={'command':list(map(str,command)),'exit':code};save();assert code==0,log
    shutil.copyfile(fixture.GAME/'stdlib.lua',out/'stdlib.lua')
    (out/'prelude.lua').write_text(fixture.PRELUDE+'\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n__ordinaryPerception={} for k,v in pairs(SAO.Perception) do __ordinaryPerception[k]=v end\n',encoding='utf-8')
    capture='''__situationModules={perception=SAO.Perception,planning=SAO.ProceduralPlanning,locomotion=SAO.Locomotion,disposition={}}
for k,v in pairs(SAO.Disposition) do __situationModules.disposition[k]=v end
SAO.Perception=__ordinaryPerception
'''
    (out/'capture.lua').write_text(capture,encoding='utf-8')
    original={k:p.read_text(encoding='utf-8') for k,p in FILES.items()}
    controls=[
        ('drop-producer','cognition','return SAO.SituationAppraisal.query(id,body,tick)','return nil','reported_premise_uncertain'),
        ('drop-consumer','controller','if not studying and planning.situationInquiryOffer then','if false then','curiosity_without_deprivation_dispatches'),
        ('discard-clarity','situation','q.utility=clarity*challenge*','q.utility=challenge*','actual_neuro_changes_competing_value'),
        ('discard-source-custody','awareness','if not stateValid(state,id,now) or not currentCustody(rec,state,now) then','if not stateValid(state,id,now) then','rebound_source_withholds_question'),
        ('discard-contradiction','awareness','propositions[kind]=yes and no and "challenged"','propositions[kind]=false and "challenged"','known_witness_contradiction_retained'),
        ('discard-attempt','planning','purpose.inquiry.attempts[step.target]={at=at,status=job.result=="arrived" and "approached" or "route-blocked"}',
            '-- attempt discarded','attempt_not_repeated'),
        ('drop-exterior-inquiry','planning','elseif question.subject=="unclassified-sound" and body then',
            'elseif false then','exterior_sound_can_prompt_owned_route'),
        ('drop-ground-lead','planning','for _,row in ipairs(context.approaches or {}) do leads[#leads+1]=row end',
            'for _,row in ipairs({}) do leads[#leads+1]=row end','retained_sound_uses_current_visible_approach'),
        ('forget-retained-sound','situation','local retained=held and held.questions["unclassified-sound"]',
            'local retained=nil','expired_pulse_still_records_owned_attempt'),
        ('reverse-private-cue-priority','perception','if a.distance ~= b.distance then return a.distance < b.distance end',
            'if a.distance ~= b.distance then return a.distance > b.distance end','personally_heard_cues_rank_near_before_far'),
        ('drop-new-cue-at-capacity','perception','if count >= SOUND_CUE_LIMIT and oldestToken then\n            row.cues[oldestToken] = nil',
            'if count >= SOUND_CUE_LIMIT and oldestToken then\n            return','new_heard_impact_survives_full_private_cache'),
        ('accept-forged-ground','perception','and tonumber(gx)==math.floor(row.x)\n                and tonumber(gy)==math.floor(row.y) and tonumber(gz)==row.z then',
            'and tonumber(gz)==row.z then','forged_ground_coordinate_withheld'),
        ('drop-source-ground','perception','ok,view,sourceBrain=pcall(sourceConceptView,id,body)',
            'ok,view,sourceBrain=true,nil,nil','source_rebound_refreshes_throttled_context'),
        ('source-indoor-as-exterior','perception','if not okOutside or outside~=true then return nil end',
            'if false then return nil end','source_interior_cannot_claim_exterior_ground'),
        ('source-borrows-prior-sight','perception','concepts.sourceGroundOnly=view.coverage=="source-current-visible-ground"',
            'concepts.sourceGroundOnly=false','source_same_tick_does_not_borrow_ordinary_sight'),
        ('drop-rebound-scan','perception','if not asleep and (not conceptObservers[id]\n            or conceptObservers[id].body ~= body) then',
            'if false then','source_rebound_refreshes_throttled_context'),
        ('drop-context-body-binding','perception','if not bound or bound.body~=body then',
            'if false then','source_context_withheld_before_rebound_scan'),
        ('drop-source-generation-binding','perception','or brain.id~=bound.sourceBrainId or brain.born~=bound.sourceBorn then',
            'then','source_ground_requires_current_brain_generation'),
        ('drop-source-person-purpose','planning','if purpose and step then',
            'if false then','source_inquiry_uses_retained_person_purpose'),
        ('drop-source-native-admission','planning',
            'if not P.noteAdmission(id,purpose.id,"SAO.WeekOneContinuity",\n            "source-inquiry:"..tostring(nextSequence),step.id) then return nil end',
            'if false then return nil end',
            'source_inquiry_uses_retained_person_purpose'),
        ('generic-interrupt-steals-source-admission','planning',
            'and (purpose.admission.owner=="SAO.Locomotion"\n                or purpose.admission.owner=="SAO.WorldSources") then',
            'and true then',
            'controller_interrupt_preserves_source_admission'),
        ('misreport-interruption','planning','status=result=="observed"\n        and "approached" or "route-unconfirmed"',
            'status="approached"','lost_source_body_reconciles_unconfirmed_attempt'),
        ('accept-wrong-position','planning','if dx*dx+dy*dy>1 then return false end',
            'if false then return false end','source_position_requires_selected_ground'),
        ('borrow-prior-tile-receipt','perception','or math.floor(x)~=bound.tileX or math.floor(y)~=bound.tileY',
            'or false','source_new_tile_invalidates_prior_scan_receipt'),
        ('drop-completed-concept-receipt','perception','conceptObservers[id].completedAt=tick',
            'conceptObservers[id].completedAt=nil','source_fresh_successful_concept_receipt'),
        ('accept-stale-concept-receipt','planning','and SAO.Perception.conceptObservationReceipt(id,body,tick)) then return false end',
            'and true) then return false end','source_arrival_needs_new_successful_sight'),
        ('drop-source-situation-custody','situation','if ok and sourceBody==body then return rec end',
            'if false then return rec end','source_person_has_private_situation_question'),
    ]
    variants=[('production',None,None,None,None)]+([] if args.baseline_only else controls)
    for name,key,old,new,marker in variants:
        texts=dict(original)
        if old:
            assert texts[key].count(old)==1,(name,texts[key].count(old));texts[key]=texts[key].replace(old,new,1)
        texts['controller']=texts['controller'].replace('return Ctl\n',fixture.EXPOSE)
        texts['cases']=texts.pop('ordinary')+'\n'+texts['cases']
        texts['cases']=texts['cases'].replace('if not value then error("PURPOSE:"..name) end',
            '__lastSituationCheck="PURPOSE:"..name; if not value then error("PURPOSE:"..name) end').replace(
            'if not value then error("SITUATION:"..name)end',
            '__lastSituationCheck="SITUATION:"..name;if not value then error("SITUATION:"..name)end')
        texts['cases']='local function runCases()\n'+texts['cases']+'\nend\nlocal ok,why=pcall(runCases);if not ok then error(tostring(why).." after "..tostring(__lastSituationCheck))end\n'
        for k,value in texts.items():(out/(k+'.lua')).write_text(value,encoding='utf-8')
        command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out)]),'PhysicalMeansLuaProbe','prelude.lua',
            *[k+'.lua' for k in FILES if k not in ('controller','ordinary','cases')],
            'capture.lua','controller.lua','cases.lua','--','__result']
        code,log=invoke(command);(out/(name+'.log')).write_bytes(log.encode('utf-8'))
        receipt['runs'].append({'name':name,'command':list(map(str,command)),'exit':code,'marker':marker,
            'logSha256':hashlib.sha256((out/(name+'.log')).read_bytes()).hexdigest(),
            'mutation':{'file':key,'before':old,'after':new} if old else None});save()
        assert (code!=0 and 'SITUATION:'+marker in log) if marker else (code==0 and 'PASS situation appraisal:' in log),log
        print(name+': '+next((line for line in log.splitlines() if 'VALUE ' in line or 'ERROR ' in line),log.strip()),flush=True)
    receipt['inputs_after']=pins();assert receipt['inputs_after']==receipt['inputs'],'source inputs changed'
    receipt['status']='PASS';save()

if __name__=='__main__':
    main()
