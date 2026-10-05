"""Production personal association transport, source authority and reload."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,json,hashlib,os,shutil,subprocess
import flee_continuity_test as fixture
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'_scratch/d1-shared-reasoning/concepts/reception'
SOURCES={'knowledge':ROOT/'mod/42.20/media/lua/shared/SAO_ConceptKnowledge.lua',
 'communication':ROOT/'mod/42.20/media/lua/shared/SAO_Communication.lua',
 'cases':ROOT/'tools/concept_reception_cases.lua'}
MAP_NORMALIZATION='''if type(s.witnesses)~="table" then s.witnesses={} end
    local retained={}
    for index=1,math.min(#s.order,MAX_RELATIONS) do
        local identity=s.order[index]
        local held=s.relations[identity]
        if reusable(held,row.actorId,identity,at) then retained[held.id]=s.witnesses[held.id] end
    end
    s.witnesses=retained'''
CONTROLS=[
 ('restore-source-identity-churn','knowledge','if reusable(prior,id,identity,provenance.acquiredAt) and prior.affirmed==(edge.affirmed~=false)',
  'if reusable(prior,id,identity,provenance.acquiredAt) and prior.sourceId==provenance.sourceId and prior.affirmed==(edge.affirmed~=false)', 'same_fact_witnesses_do_not_repeat_testimony'),
 ('leak-private-witnesses','knowledge','and not spoken[edge.id] then return copy(edge) end',
  'and not spoken[edge.id] then local offered=copy(edge);offered.witnesses=s.witnesses and s.witnesses[edge.id];return offered end','support_provenance_is_private'),
 ('retain-evicted-witnesses','knowledge','s.witnesses=retained',
  '-- private evidence never retired','eviction_retires_private_witness_bucket'),
 ('accept-future-witness','knowledge','and candidate.lastObservedAt<=at then',
  'and true then','future_witness_not_observation_authority'),
 ('trust-malformed-witness-map','knowledge',MAP_NORMALIZATION,
  's.witnesses=s.witnesses or {}','malformed_map_recovers_on_observation'),
 ('accept-generic-message','communication','local receipt=conceptReceptions[message]',
  'local receipt=conceptReceptions[message] or {to=message.to,from=message.from,at=message.at,edge=message.payload,id="forged",channel="spoken"}', 'generic_delivery_not_reception'),
 ('omit-transport','communication','if not channel then return nil,why or "transport-refused" end',
  'if false then return nil,why or "transport-refused" end;channel=channel or "spoken"', 'unadmitted_offer_does_not_remember'),
 ('drop-taught-prior','knowledge','or edge.basis=="taught-association")','or false)', 'reception_changes_inference'),
 ('leak-context','knowledge','then return copy(edge) end',
  'then local leaked=copy(edge);leaked.contextId="house:A";return leaked end', 'offered_general_not_local'),
 ('lose-speaker','knowledge','speakerId=receipt.from','speakerId=nil','retains_speaker_channel_source'),
 ('retain-capability','communication','conceptReceptions[message]=nil','-- retained capability','receipt_capability_retired'),
 ('erase-contrary','knowledge','if denied[receipt.edge.from.."|"..receipt.edge.into] then','if false then','own_contrary_evidence_preserved'),
 ('consult-private-listener','knowledge','local s=state(fromId,false)',
  'local listenerEdges,listenerDenied=available(toId,nil);if listenerDenied["room|seat"] then return nil end;local s=state(fromId,false)', 'offer_independent_of_listener_belief'),
 ('omit-spoken-memory','communication','pcall(knowledge.rememberSpokenAssociation,fromId,message)',
  '-- omitted spoken memory','actual_utterance_remembered'),
 ('erase-duplicate-refusal','knowledge','if key(edge)==key(receipt.edge) then','if false then','receiver_owns_duplicate_refusal'),
 ('ignore-date','knowledge','and edge.acquiredAt<=at','and true','future_dated_prior_refused'),
]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 global OUT
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=OUT)
 parser.add_argument('--variants',nargs='+');args=parser.parse_args();OUT=args.output.resolve()
 OUT.mkdir(parents=True,exist_ok=True)
 jar=fixture.GAME/'projectzomboid.jar'
 runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
 preflight = installed_presence([*SOURCES.values(),Path(__file__),Path(fixture.__file__),runner,jar,fixture.GAME/'stdlib.lua',Path(__file__).with_name('native_proof_preflight.py')], fixture.GAME, fixture.JDK, "concept reception")
 if preflight is not None:
     raise SystemExit(preflight)
 inputs={str(p):sha(p) for p in [*SOURCES.values(),Path(__file__),Path(fixture.__file__),runner,jar,fixture.GAME/'stdlib.lua',Path(__file__).with_name('native_proof_preflight.py')]}
 def run(cmd):
  p=subprocess.run(list(map(str,cmd)),cwd=OUT,capture_output=True,text=True,timeout=120)
  return p.returncode,p.stdout+p.stderr
 compile_command=[fixture.JDK/'javac.exe','-cp',jar,'-d',OUT,runner]
 code,log=run(compile_command);assert code==0,log
 shutil.copy2(fixture.GAME/'stdlib.lua',OUT/'stdlib.lua')
 (OUT/'prelude.lua').write_text('SAO={};require=function()end\n')
 texts={n:p.read_text() for n,p in SOURCES.items()}
 variants=[]
 receipt={'schema':'sao.personal-concept-reception-proof/1','status':'INCOMPLETE',
  'atUtc':datetime.now(timezone.utc).isoformat(),'inputs':inputs,'variants':variants,
  'compile':{'command':list(map(str,compile_command)),'cwd':str(OUT),'exit':0},
  'boundary':'Installed Kahlua executes production knowledge/communication and native table serialization; canConverse physical hearing admission controlled. Live Exchange and dormant encounter calls are separate integration inputs. Admitted spoken transport is not a Voice/body:Say emission receipt.'}
 def save():(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 save()
 selected=[('production',None,None,None,None)]+CONTROLS
 if args.variants:
  selected=[v for v in selected if v[0] in args.variants];assert len(selected)==len(args.variants)
 for name,module,before,after,marker in selected:
  changed=texts.copy()
  if module:
   assert before in changed[module],name+' control site missing'
   changed[module]=changed[module].replace(before,after,1)
  for n,t in changed.items():(OUT/(n+'.lua')).write_text(t)
  command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(OUT)]),'PhysicalMeansLuaProbe',
    'prelude.lua','knowledge.lua','communication.lua','cases.lua','--','__result']
  code,log=run(command)
  (OUT/(name+'.log')).write_text(log)
  variants.append({'name':name,'exit':code,'expectedFailure':marker,'logSha256':sha(OUT/(name+'.log')),
   'command':list(map(str,command)),'cwd':str(OUT),'mutation':{'source':module,'before':before,'after':after} if module else None})
  passed=(code!=0 and 'RECEPTION:'+marker in log) if marker else (code==0 and 'PASS concept reception' in log)
  if not passed:receipt['status']='FAIL'
  save();assert passed,log
  print(name+': '+log.strip().splitlines()[-1])
 assert all(sha(Path(p))==h for p,h in inputs.items()),'inputs changed during proof'
 receipt.update(status='PASS',inputsAfter={p:sha(Path(p)) for p in inputs},controls=sum(v[4] is not None for v in selected))
 save()
if __name__=='__main__':
 try:main()
 except Exception as error:
  print('Concept reception verification failed: '+str(error))
  raise SystemExit(1)
