"""Conflict dispatch through production Lua owners in installed Kahlua.

Native admission/queues and private input records are controlled. This proves
dispatch and feedback, not native combat efficacy or rendered behavior.
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

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '_scratch/d1-shared-reasoning/conflict/response'
FILES = {
    'models': ROOT / 'mod/42.20/media/lua/shared/SAO_CognitiveModels.lua',
    'cognition': ROOT / 'mod/42.20/media/lua/shared/SAO_Cognition.lua',
    'concepts': ROOT / 'mod/42.20/media/lua/shared/SAO_ConceptKnowledge.lua',
    'pressure': ROOT / 'mod/42.20/media/lua/shared/SAO_PathogenPressure.lua',
    'planning': ROOT / 'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua',
    'controller': ROOT / 'mod/42.20/media/lua/client/SAO_Controller.lua',
    'response': ROOT / 'mod/42.20/media/lua/client/SAO_ConflictResponse.lua',
    'cases': ROOT / 'tools/conflict_response_cases.lua',
}

def run():
    global OUT
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=OUT)
    parser.add_argument('--production-only',action='store_true')
    args=parser.parse_args()
    OUT=args.output.resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    jar = fixture.GAME / 'projectzomboid.jar'
    perception = ROOT / 'mod/42.20/media/lua/shared/SAO_Perception.lua'
    paths = [perception, *FILES.values(), Path(__file__), Path(fixture.__file__), fixture.RUNNER, jar, fixture.GAME / 'stdlib.lua']
    paths.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "conflict response")
    if preflight is not None:
        raise SystemExit(preflight)
    pins = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    receipt = {'schema': 'sao-conflict-response-proof/1', 'status': 'INCOMPLETE', 'inputs': pins, 'runs': [], 'boundary': __doc__}
    def invoke(args):
        p = subprocess.run(list(map(str,args)), cwd=OUT, capture_output=True, text=True, timeout=120)
        return p.returncode, p.stdout+p.stderr
    code, log = invoke([fixture.JDK/'javac.exe','-cp',jar,'-d',OUT,fixture.RUNNER])
    assert code == 0, log
    shutil.copy2(fixture.GAME/'stdlib.lua',OUT/'stdlib.lua')
    owner=perception.read_text(encoding='utf-8-sig')
    sorter=owner.split('local function sortSightEvidence(',1)[1].split('local function zombieReports(',1)[0]
    (OUT/'prelude.lua').write_text(fixture.PRELUDE+'\nrequire=function()end\nlocal P=SAO.Perception\nlocal function sortSightEvidence('+sorter,encoding='utf-8')
    texts = {key:p.read_text(encoding='utf-8') for key,p in FILES.items()}
    texts['controller']=texts['controller'].replace('return Ctl\n',fixture.EXPOSE)
    variants = [
        ('production',None,None,None),
        ('forget-refused-route','if blocked then frame.escapeBlocked=true end','blocked=false', 'failed_exit_changes_actual_route'),
        ('skip-body-token','and data.SAOExternalToken == rec.bodyOwnerToken','and true','foreign_body_token_cannot_dispatch'),
        ('skip-native-handback','call("cancelCombatObserved",body)=="COMBAT_CANCELLED"','true','native_animation_keeps_custody'),
        ('nearest-target-substitution','action.targetKind,action.targetKey,action.mode','action.targetKind,"other-track",action.mode','unarmed_defense_actual_dispatch'),
        ('raw-character-health','tonumber(call("getShellHealth",body))','tonumber(body:getHealth())','native_physiology_reopens_combat'),
        ('busy-queue-ignored','if SAO.Needs and SAO.Needs.busy and SAO.Needs.busy(body) then','if false then','unrelated_timed_action_keeps_body'),
        ('crossing-custody-ignored','if nativeCrossing(SAO.Locomotion.jobs[id],body) then','if false then','accepted_crossing_before_native_state_keeps_owner'),
        ('crossing-pump-starved','if hooks.pumpMovement then hooks.pumpMovement(id) end','if false then hooks.pumpMovement(id) end','strategic_crossing_owner_keeps_ticking'),
        ('late-token-orphan','{status="cancelled",reason="terminal callback','{status="completed",reason="terminal callback','late_terminal_releases_exact_admission_without_credit'),
        ('wrong-record-admitted','rec.id~=id or SAO.Identity.get(id)~=rec','false','wrong_person_record_cannot_dispatch'),
        ('stale-agent-admitted','SAO.Controller.agents[id]~=agent','false','stale_controller_cannot_dispatch'),
        ('replaced-identity-admitted','SAO.Identity.get(id)~=rec','false','replaced_identity_record_cannot_dispatch'),
        ('transfer-danger-ignored','if reason or dangerChanged(work,body,threat,count or 0,personKey)','if false','injury_requests_exact_transfer_cancellation'),
        ('transfer-handback-ignored','if SAO.Handover.cancelAttempt(work.receiptId,id,body,work.reconsider or "transfer ended")~=true then return true end','SAO.Handover.cancelAttempt(work.receiptId,id,body,work.reconsider or "transfer ended")','injury_requests_exact_transfer_cancellation'),
        ('controller-drop-orphan','if SAO.ConflictResponse and not SAO.ConflictResponse.detach(id,Ctl.agents[id],body,"controller detached") then','if false then','drop_settles_admitted_conflict'),
        ('controller-adoption-orphan','SAO.ProceduralPlanning.reconcileConflict(rec.id,"loaded owner was absent at adoption; prior outcome is unobserved")', '-- orphan reconciliation removed by control','actual_adoption_reconciles_orphan'),
        ('distant-appraisal-gated','local frame,offers,actions=alternatives(id,agent,body,tick,threat,count,person,personKey,hooks)',
            'if threat.dist>fleeAt then return false end\n    local frame,offers,actions=alternatives(id,agent,body,tick,threat,count,person,personKey,hooks)', 'distant_contact_retains_appraisal'),
        ('ordinary-watch-interrupted','if decision.kind=="watch" and not agent.conflictRoute and not agent.conflictCoordination',
            'if decision.kind=="watch" and not action.continueOrdinary and not agent.conflictRoute and not agent.conflictCoordination', 'ordinary_away_route_remains_owned'),
        ('approach-risk-omitted','approaching and {"exposure","bodily-harm"} or {"exposure"}',
            '{"exposure"}', 'approaching_route_changes_response'),
        ('crossing-appraisal-suppressed','local frame,offers,actions=alternatives(id,agent,body,tick,threat,count,person,personKey,hooks)',
            'if nativeCrossing(SAO.Locomotion.jobs[id],body) then if hooks.pumpMovement then hooks.pumpMovement(id) end return true end\n    local frame,offers,actions=alternatives(id,agent,body,tick,threat,count,person,personKey,hooks)', 'crossing_keeps_awareness'),
    ]
    # Failure memory is independently enforced by Planning; a control removes
    # both producers of that same decision constraint.
    if args.production_only:
        variants=variants[:1]
    for name,old,new,marker in variants:
        sources=dict(texts)
        if old:
            owner='controller' if name.startswith('controller-') else 'response'
            assert sources[owner].count(old)==1,name
            sources[owner]=sources[owner].replace(old,new,1)
        if name=='forget-refused-route':
            sources['planning']=sources['planning'].replace('if offer.routeKey and P.conflictRouteBlocked(id,offer.routeKey,frame.atHours) then','if false then',1)
            sources['planning']=sources['planning'].replace('if sameConflictOffer(offer,failed) and failed.atHours<=frame.atHours','if false and failed.atHours<=frame.atHours',1)
        for key,value in sources.items(): (OUT/(key+'.lua')).write_text(value,encoding='utf-8')
        cmd=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(OUT)]),'LuaRun','prelude.lua',*[key+'.lua' for key in FILES],'--','__result']
        code,log=invoke(cmd);(OUT/(name+'.log')).write_text(log,encoding='utf-8')
        receipt['runs'].append({'name':name,'command':list(map(str,cmd)),'exit':code,'controlMarker':marker,'logSha256':hashlib.sha256(log.encode()).hexdigest()})
        (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        assert (code!=0 and 'CONFLICT_RESPONSE:'+marker in log) if marker else (code==0 and 'PASS conflict response' in log), log
        print(name+': '+log.strip().splitlines()[-1],flush=True)
    assert pins=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},'inputs changed during checks'
    receipt['status']='PASS'
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':
    try:
        run()
    except Exception as error:
        print('FAIL conflict response:',error,flush=True)
        raise SystemExit(1)
