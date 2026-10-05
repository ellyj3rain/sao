#!/usr/bin/env python3
"""D1 measured execution facts to private expectations and actual purpose choice.

Installed Kahlua and native reading/appliance action Lua; controlled bodies,
source transfer/heat responses and route completion. No rendered/native-world,
assessed understanding, education corpus, skill mastery or population claim.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import study_test as study
import ordinary_purpose_test as ordinary
import coordination_execution_test as coordination
from native_proof_preflight import installed_presence

ROOT=Path(__file__).resolve().parents[1]
LUA=ROOT/'mod/42.20/media/lua'
FILES={name:LUA/folder/('SAO_'+title+'.lua') for name,folder,title in [
    ('models','shared','CognitiveModels'),('cognition','shared','Cognition'),
    ('study','client','Study'),('cooking','client','Cooking'),('organization','shared','Organization'),
    ('controller','client','Controller'),('needs','client','Needs'),('planner','shared','ProceduralPlanning'),
    ('identity','shared','Identity'),('experience','client','CapabilityExperience'),
    ('perception','shared','Perception'),('communication','shared','Communication'),
    ('graph','shared','GraphPersistence'),('source_use','client','SourceUse'),
    ('provisioning','shared','Provisioning'),('handover','shared','Handover')]}
RUNNER=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
STUDY_CASES=ROOT/'tools/study_outcome_cases.lua'
CONSUMER_CASES=ROOT/'tools/purpose_outcome_cases.lua'
COOKING_CASES=ROOT/'tools/cooking_outcome_cases.lua'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--part',choices=['study','consumer','cooking','delivery','withdrawal'],required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--variants',nargs='*')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    jar=study.GAME/'projectzomboid.jar'
    inputs=[*FILES.values(),Path(__file__),Path(study.__file__),Path(ordinary.__file__),
        Path(ordinary.fixture.__file__),Path(coordination.__file__),RUNNER,STUDY_CASES,CONSUMER_CASES,COOKING_CASES,
        ROOT/'tools/ordinary_purpose_cases.lua',ROOT/'tools/cooking_checks/prelude.lua',jar,study.GAME/'stdlib.lua']
    native=['media/lua/shared/ISBaseObject.lua','media/lua/shared/TimedActions/ISBaseTimedAction.lua',
        'media/lua/client/TimedActions/ISInventoryTransferAction.lua','media/lua/shared/TimedActions/ISReadABook.lua',
        'media/lua/shared/TimedActions/ISToggleStoveAction.lua']
    inputs += [study.GAME/p for p in native]
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, study.GAME, ordinary.fixture.JDK, "purpose outcome")
    if preflight is not None:
        raise SystemExit(preflight)
    pins={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    receipt={'schema':'sao-purpose-outcomes/1','part':args.part,'status':'INCOMPLETE','inputs':pins,'variants':[],
        'boundary':__doc__}
    def save():
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def invoke(command):
        done=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,text=True,timeout=120)
        return done.returncode,done.stdout+done.stderr
    save()
    code,log=invoke([study.JDK/'javac.exe','-cp',jar,'-d',out,RUNNER]);assert code==0,log
    shutil.copy2(study.GAME/'stdlib.lua',out/'stdlib.lua')
    sources={k:p.read_text(encoding='utf-8-sig') for k,p in FILES.items()}
    variants=[('production',None,None,None,None)]
    controls={
      'study':[
        ('drop-reading-callback','study','SAO.Cognition.studyOutcome(action.personId,outcome)','do end','native_callback_revises_private_expectation'),
        ('drop-reading-receipt','study','person.studyOutcomes[#person.studyOutcomes+1]=outcome','-- omitted receipt','native_pages_publish_exact_receipt'),
        ('forget-resumed-pages','study','pagesBefore=work.pagesBefore,pagesAfter=pages','pagesBefore=0,pagesAfter=pages','native_pages_publish_exact_receipt'),
      ],
      'consumer':[
        ('drop-reading-prediction','models','elseif e.kind == "study-outcome" then retain("study", "learning", true)',
            'elseif e.kind == "study-outcome" then -- no prediction','study_receipt_changes_real_later_choice'),
        ('drop-reading-domain','controller','sourceId="manual:"..manual:getSkillTrained(), itemType=manual:getFullType()',
            'sourceId=nil, itemType=manual:getFullType()','study_receipt_changes_real_later_choice'),
        ('drop-physical-practice','controller','means and {kind="prepare",category="food",sourceId=means.sourceId,itemType=means.itemType,value=0.6}',
            'means and {kind="practice",category="learning",value=0.6}','native_preparation_changes_actual_practice'),
        ('drop-work-prediction','models','elseif e.kind == "commitment-outcome" then retain("commitment", "social", true)',
            'elseif e.kind == "commitment-outcome" then -- no prediction','own_performed_responsibility_changes_dispatch'),
        ('ignore-work-kind','models','b.condition==c.condition',
            'true','delivery_success_does_not_teach_preparation'),
        ('reading-owner-bypass','cognition','if not canonical or not sameData(canonical,receipt) then return false,"study-owner-unavailable" end',
            'if false then return false,"study-owner-unavailable" end','unowned_reading_receipt_refused'),
        ('preparation-owner-bypass','cognition','if not canonical or not sameData(canonical,receipt) then return false,"preparation-owner-unavailable" end',
            'if false then return false,"preparation-owner-unavailable" end','unowned_preparation_cannot_teach'),
        ('generic-preparation-bypass','cognition',' or supplied.kind=="preparation")',
            ')','generic_preparation_cannot_change_actual_choice'),
        ('work-owner-bypass','cognition','if not canonical or not sameData(canonical,receipt) then return false,"commitment-owner-unavailable" end',
            'if false then return false,"commitment-owner-unavailable" end','unowned_completed_work_does_not_teach'),
      ],
      'cooking':[
        ('ignore-selected-source','cooking','not context or not context.expectedSourceId or context.expectedSourceId==row.sourceId',
            'true','expected_different_source_is_refused'),
        ('ignore-selected-item','cooking','if exact and (row.carried or allowed(id, row)',
            'if true and (row.carried or allowed(id, row)','expected_different_item_is_refused'),
        ('drop-preparation-callback','experience','return SAO.Cognition.preparationOutcome(id, receipt)',
            'return false','actual_preparation_callback_teaches'),
        ('drop-prepared-work','organization','rememberFulfilledWork(commitment,"prepare",receiptId,native)',
            '-- accepted physical contribution omitted','performed_accepted_preparation_teaches'),
      ], 'delivery':[
        ('drop-delivery-projection','organization','rememberFulfilledWork(commitment,"deliver",receiptId,native)',
            '-- measured delivery omitted','native_delivery_teaches_only_actor'),
        ('treat-handover-ticks-as-hours','organization','occurred=math.max(commitment.acceptedAt,native.completedAt/rate)',
            'occurred=native.completedAt','native_delivery_teaches_only_actor'),
      ], 'withdrawal':[
        ('leave-withdrawn-forage-running','controller','if agent.state == "WORKWARD" or agent.state == "FORAGE" then\n            SAO.Locomotion.cancel(id)',
            'if agent.state == "WORKWARD" then\n            SAO.Locomotion.cancel(id)','loaded_withdrawal_cancels_route_owner'),
        ('cancel-unrelated-flee','controller','if agent.state == "WORKWARD" or agent.state == "FORAGE" then\n            SAO.Locomotion.cancel(id)',
            'if true then\n            SAO.Locomotion.cancel(id)','withdrawal_preserves_later_flee_owner'),
      ]}
    variants+=controls[args.part]
    if args.variants is not None:
        unknown=set(args.variants)-{v[0] for v in variants};assert not unknown,unknown
        variants=[v for v in variants if v[0] in args.variants]
    for name,target,before,after,marker in variants:
        texts=dict(sources)
        if target:
            expected_count=2 if name in ('drop-delivery-projection','ignore-work-kind') else 1
            assert texts[target].count(before)==expected_count,(name,'anchor',texts[target].count(before))
            texts[target]=texts[target].replace(before,after)
        paths=[]
        def add(name,text):
            path=out/(name+'.lua');path.write_text(text,encoding='utf-8');paths.append(path)
        def source(name):add(name,texts[name])
        if args.part=='study':
            add('prelude',study.PRELUDE+'''
local priorGet=ModData.getOrCreate
local data={}
ModData.get=function(key)return data[key]end
ModData.getOrCreate=function(key)
 if key=='SurvivorAwareness_Records' then return priorGet(key) end
 data[key]=data[key] or {};return data[key]
end
SAO.Hash.unit=function()return .2 end
''')
            paths += [study.GAME/p for p in native[:4]]
            for k in ['models','cognition','identity','planner','needs','study']:source(k)
            add('cases',STUDY_CASES.read_text())
        elif args.part=='consumer':
            add('prelude',ordinary.fixture.PRELUDE+'\nrequire=function()end\nISInventoryTransferAction={derive=function()return {}end}\n')
            for k in ['models','cognition','needs']:source(k)
            add('controller',texts['controller'].replace('return Ctl\n',ordinary.fixture.EXPOSE))
            add('cases',(ROOT/'tools/ordinary_purpose_cases.lua').read_text()+'\n'+CONSUMER_CASES.read_text())
        elif args.part=='cooking':
            paths=[ROOT/'tools/cooking_checks/prelude.lua']+[study.GAME/p for p in [native[0],native[1],native[4]]]
            add('initial','SAO.Controller={} SAO.Pharmacology={} SAO.ResourceProduction={} require=function()end\n')
            for k in ['models','cognition','organization','cooking','experience']:source(k)
            add('cases',COOKING_CASES.read_text())
        else:
            prelude=coordination.PRELUDE.replace('return { SAOPersonId=self.id }','return { SAOPersonId=self.id, SAOExternalOwner=__people[self.id].bodyOwner, SAOExternalToken=__people[self.id].bodyOwnerToken }')
            add('prelude',prelude+'\nModData.get=function(k)return __stores[k]end\nSAO.Hash={unit=function()return .2 end}\nSAO.History.TICKS_PER_HOUR=9000\nSAO.History.ticks=function()return math.floor(__now*9000)end\n')
            for k in ['models','cognition','perception','organization','communication','graph','needs','source_use','provisioning','handover']:source(k)
            add('controller',texts['controller'].replace('return Ctl\n','Ctl.__coordinationProbeAdvance=advanceCoordination\nCtl.__coordinationProbeMovement=updateMovement\nreturn Ctl\n'))
            probe=coordination.PROBE.replace('  SAO.GraphPersistence.bind()', '  SAO.Cognition.configure(1,12,3)\n  SAO.GraphPersistence.bind()',1)
            probe=probe.replace("    checks[#checks+1]=name..'='..tostring(value==true)","    if value~=true then error('OUTCOME:'..name) end\n    checks[#checks+1]=name..'='..tostring(value==true)")
            probe=probe.replace("  local handoverAction=SAO.Handover._runtime[handoverId].action", """
  check('arrival_and_queue_do_not_teach_delivery',__people.worker.fulfilledWorkOutcomes==nil)
  local handoverAction=SAO.Handover._runtime[handoverId].action""",1)
            probe=probe.replace("  __sourceItem=makeItem(2,'Base.Apple',__sourceContainer)","""
  local completed=SAO.Organization.fulfilledWorkOutcome('worker',1)
  check('native_delivery_teaches_only_actor',completed and completed.workKind=='deliver'
    and completed.nativeReceiptId==handoverId and completed.commitmentId==commitmentId
    and __people.worker.cognition and #__people.worker.cognition.experiences==1
    and __people.worker.cognition.experiences[1].kind=='commitment-outcome'
    and __people.origin.cognition==nil)
  check('delivery_replay_does_not_repeat_private_credit',#__people.worker.fulfilledWorkOutcomes==1)
  __people.worker=__nativeRoundtrip(__people.worker)
  check('delivery_private_credit_survives_native_reload',SAO.Organization.fulfilledWorkOutcome('worker',1).nativeReceiptId==handoverId
    and __people.worker.cognition.nativeExperienceCursors.commitment==1)
  __sourceItem=makeItem(2,'Base.Apple',__sourceContainer)""",1)
            # This focused producer proof ends after the actual completed and
            # interrupted transfers; the route lifecycle suite remains separate.
            if args.part=='delivery':
                probe=probe.split('  -- Reproduce native02:',1)[0]+"""
  local learnedDelivery=false
  for _,row in ipairs(__people.worker2.cognition and __people.worker2.cognition.experiences or {}) do
    if row.kind=='commitment-outcome' then learnedDelivery=true end
  end
  check('interrupted_delivery_does_not_teach',__people.worker2.fulfilledWorkOutcomes==nil and not learnedDelivery)
  return table.concat(checks,',')
end)()"""
            else:
                probe=probe.split("  __sourceItem=makeItem(6,'Base.Apple',__sourceContainer)",1)[0]+"""
  -- The obsolete coordination binding may coexist briefly with the next
  -- native escape owner. Retirement must leave that exact job untouched.
  agent.state='FLEE'
  agent.coordinationCommitment=loaded.id
  agent.coordinationRoute={commitmentId=loaded.id,routeId='retired-attempt'}
  SAO.Locomotion.order('worker',__bodies.worker,41,42,0)
  local escape=SAO.Locomotion.jobs.worker
  SAO.Controller.__coordinationProbeMovement('worker',agent,__bodies.worker)
  check('withdrawal_preserves_later_flee_owner',agent.state=='FLEE'
    and agent.coordinationCommitment==nil and agent.coordinationRoute==nil
    and SAO.Locomotion.jobs.worker==escape and escape.goal.x==41)
  SAO.Controller.__coordinationProbeMovement('worker',agent,__bodies.worker)
  check('retired_coordination_cleanup_is_idempotent',agent.state=='FLEE' and SAO.Locomotion.jobs.worker==escape)
  return table.concat(checks,',')
end)()"""
            add('cases','__result='+probe)
        command=[study.JDK/'java.exe','-Djava.awt.headless=true','-cp',os.pathsep.join([str(out),str(jar)]),RUNNER.stem,*paths,'--','__result']
        code,log=invoke(command);(out/(name+'.log')).write_text(log,encoding='utf-8')
        checks=dict(re.findall(r'([a-z0-9_]+)=(true|false)',log))
        success=code==0 and ('PASS ' in log or bool(checks)) and all(v=='true' for v in checks.values())
        rejected=marker and (('PURPOSE:'+marker in log or 'OUTCOME:'+marker in log) or checks.get(marker)=='false')
        receipt['variants'].append({'name':name,'command':list(map(str,command)),'cwd':str(out),'exit':code,'expected':marker,
            'mutation':{'source':target,'before':before,'after':after} if target else None,
            'log':str(out/(name+'.log')),'sha256':hashlib.sha256(log.encode()).hexdigest(),'checks':checks,
            'checkCount':len(checks) or (int(re.search(r'VALUE PASS [^\n]* (\d+)',log).group(1)) if re.search(r'VALUE PASS [^\n]* (\d+)',log) else None),
            'observedPass':success,'controlRejected':bool(rejected)})
        save();assert rejected if marker else success,log
        verdict=next((line for line in log.splitlines() if line.startswith(('VALUE ','ERROR '))),log.strip().splitlines()[-1])
        print(name+': '+verdict,flush=True)
    receipt['inputs_after']={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in pins}
    assert receipt['inputs_after']==pins,'changed inputs during proof'
    receipt['status']='PASS';save();return 0

if __name__=='__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print('FAIL purpose outcomes:',error,flush=True)
        raise SystemExit(1)
