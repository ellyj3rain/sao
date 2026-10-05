"""Person-private initial/report/witness awareness and actual conflict choices in installed Kahlua.

Admission provider and native scanner outputs are controlled. Exact source owners,
native table serialization and conflict dispatch execute; no rendered-play or
eyewitness-death/reanimation transition claim. Familiar-change association only.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,sys
import conflict_response_test as existing
from native_proof_preflight import installed_presence
fixture=existing.fixture
ROOT=existing.ROOT
FILES=dict(existing.FILES)
FILES.update(perception=ROOT/'mod/42.20/media/lua/shared/SAO_Perception.lua',
 knowledge=ROOT/'mod/42.20/media/lua/shared/SAO_Knowledge.lua',
 awareness=ROOT/'mod/42.20/media/lua/shared/SAO_PersonalAwareness.lua',
 awareness_cases=ROOT/'tools/personal_awareness_cases.lua')
EXPOSE="""
__awarenessInherited=__result
__awarenessFixture={fresh=fresh,decide=decide,
 record=function(id,rec)records[id]=rec end,
 offers=function(value,available)moves=value;native=available end}
"""
CONTROLS=[
 ('foreign-record','awareness','record(rec.id)~=rec','false','foreign_record_refused'),
 ('future-initial','awareness','value.admittedAtHours>now','false','future_initial_refused'),
 ('ignore-contrary','awareness','positive=positive or yes and not no','positive=positive or yes','contrary_evidence_retained'),
 ('retained-current-binding','awareness','stateValid(rec.personalAwareness,rec.id,now) and currentCustody(rec,rec.personalAwareness,now)','stateValid(rec.personalAwareness,rec.id,now)','initial_never_overwrites_private_state'),
 ('query-current-binding','awareness','if not stateValid(state,id,now) or not currentCustody(rec,state,now) then','if not stateValid(state,id,now) then','pure_query_withholds_rebound_admission'),
 ('missing-state-legacy','awareness','if not ok or value~=nil then','if false then','unattached_authored_person_is_not_legacy'),
 ('foreign-state','awareness','value.actorId~=id','false','foreign_saved_state_withheld'),
 ('radio-confirmation','awareness','certainty="reported",basis="personal-radio-reception"','certainty="witnessed",basis="personal-radio-reception"','radio_is_report_not_confirmation'),
 ('future-radio','awareness','receipt.receivedAt<=now','true','future_saved_radio_withheld'),
 ('told-memory-witness','perception','pb.source=="observed"','(pb.source=="observed" or pb.source=="told")','told_person_memory_does_not_confirm_turn'),
 ('foreign-body-witness','awareness','data.SAOExternalToken==rec.bodyOwnerToken','true','foreign_body_token_cannot_gain_witness'),
 ('future-witness','awareness','SAO.History.ticks()==tick','true','future_scan_cannot_gain_witness'),
 ('ignore-private-recognition','response','if unresolvedCause then objections[#objections+1]="unanswered" end','if false then objections[#objections+1]="unanswered" end','private_awareness_changes_actual_shared_choice'),
 ('disable-naive-defense','response','available=permitted==true and mode~=nil','available=permitted==true and mode~=nil and not unresolvedCause','naive_still_physically_defends'),
]
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,default=ROOT/'_scratch/d1-shared-reasoning/awareness/verification')
 ap.add_argument('--baseline-only',action='store_true');ap.add_argument('--variants',nargs='*');args=ap.parse_args()
 out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
 jar=fixture.GAME/'projectzomboid.jar';runner=ROOT/'tools/luacheck/PhysicalMeansLuaProbe.java'
 paths=[*FILES.values(),runner,Path(__file__),Path(existing.__file__),Path(fixture.__file__),jar,fixture.GAME/'stdlib.lua']
 paths.append(Path(__file__).with_name('native_proof_preflight.py'))
 preflight = installed_presence(paths, fixture.GAME, fixture.JDK, "personal awareness")
 if preflight is not None:
     raise SystemExit(preflight)
 pins=lambda:{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
 receipt={'schema':'sao.personal-awareness-proof/1','status':'INCOMPLETE','inputs':pins(),'runs':[],'boundary':__doc__}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
 def run(cmd):
  p=subprocess.run(list(map(str,cmd)),cwd=out,text=True,capture_output=True,timeout=120);return p.returncode,p.stdout+p.stderr
 save();code,log=run([fixture.JDK/'javac.exe','-cp',jar,'-d',out,runner]);(out/'compile.log').write_text(log,encoding='utf-8')
 assert code==0,log
 owner=FILES['perception'].read_text(encoding='utf-8-sig')
 sorter=owner.split('local function sortSightEvidence(',1)[1].split('local function zombieReports(',1)[0]
 shutil.copyfile(fixture.GAME/'stdlib.lua',out/'stdlib.lua');(out/'prelude.lua').write_text(fixture.PRELUDE+'\nrequire=function()end\nlocal P=SAO.Perception\nlocal function sortSightEvidence('+sorter,encoding='utf-8')
 originals={key:p.read_text(encoding='utf-8') for key,p in FILES.items()}
 originals['controller']=originals['controller'].replace('return Ctl\n',fixture.EXPOSE)
 originals['cases']+=EXPOSE
 originals['awareness_cases']='local function __runAwareness()\n'+originals['awareness_cases'].replace('checks=checks+1 end','checks=checks+1;if name~="canonical_initial_attaches" then __lastAwarenessCheck=name end end')+'\nend\nlocal ok,why=pcall(__runAwareness);if not ok then error(tostring(why).." after "..tostring(__lastAwarenessCheck)) end\n'
 variants=[('production',None,None,None,None)]+([] if args.baseline_only else [v for v in CONTROLS if not args.variants or v[0] in args.variants])
 for name,key,old,new,marker in variants:
  sources=dict(originals)
  if old:assert sources[key].count(old)==1,(name,sources[key].count(old));sources[key]=sources[key].replace(old,new)
  for owner,text in sources.items():(out/(owner+'.lua')).write_text(text,encoding='utf-8')
  command=[fixture.JDK/'java.exe','-cp',os.pathsep.join([str(jar),str(out)]),'PhysicalMeansLuaProbe','prelude.lua',*[key+'.lua' for key in FILES],'--','__result']
  code,log=run(command);(out/(name+'.log')).write_text(log,encoding='utf-8')
  receipt['runs'].append(dict(name=name,exitCode=code,command=list(map(str,command)),log=name+'.log',logSha256=hashlib.sha256(log.encode()).hexdigest(),marker=marker));save()
  assert (code!=0 and 'PERSONAL_AWARENESS:'+marker in log) if marker else (code==0 and 'PASS personal awareness' in log),log
  print(name+': '+next((line for line in log.splitlines() if 'VALUE ' in line or 'ERROR ' in line),log.strip().splitlines()[-1]),flush=True)
 assert receipt['inputs']==pins(),'source inputs changed'
 receipt['status']='PASS';save()
if __name__=='__main__':
 try:main()
 except Exception as error:
  print('FAIL personal awareness: '+str(error),file=sys.stderr)
  raise SystemExit(1)
