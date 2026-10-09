#!/usr/bin/env python3
"""Actual Coordination/Communication/selected Controller duet joins in Kahlua."""
from pathlib import Path
from native_proof_preflight import installed_presence
import argparse,json,os,re,shutil,subprocess,tempfile
import d2_leisure_music_test as music

ROOT=music.OWNER.parents[5]
HERE=Path(__file__).parent/'d2_leisure_social'
COORD=ROOT/'mod/42.20/media/lua/shared/SAO_Coordination.lua'
COMM=ROOT/'mod/42.20/media/lua/shared/SAO_Communication.lua'
CTL=ROOT/'mod/42.20/media/lua/client/SAO_Controller.lua'

def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--baseline-only',action='store_true');a=p.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),Path(music.__file__),music.OWNER,music.ORG,COORD,COMM,CTL,*[f for f in music.FIXTURES.iterdir() if f.is_file()],*[f for f in HERE.iterdir() if f.is_file()],*native,*jars,music.GAME/'stdlib.lua',*[music.LS/p for p in music.LS_FILES],*[music.NM/p for p in music.NM_FILES]]
 absent=installed_presence(inputs,music.GAME,music.JDK,'D2 d2_leisure_social_test',installed_roots=(music.LS.parent,music.NM.parent));
 if absent is not None:return absent
 receipt={'schema':'sao-d2-leisure-social-join/1','status':'INCOMPLETE','inputsBefore':{str(p):music.sha(p)for p in inputs},'runs':[],
 'boundary':'Full actual Coordination, Communication and Organization; unchanged source Music and Lifestyle constructors/callbacks. Exact extracted Controller leisureReasons/duetInvitationOffers/leisureOffers/limitPurposeComparison/beginLeisureOffer. Native Kahlua, Stats/save-load. Controlled body/source equipment/queues, private perception, standing/traits/interests/personal-memory input and native canConverseNow hearing receiver; actual Communication transient transport lifetime, no direct Organization delivery. Native hearing jar proof and ordinary gameplay separate.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,args,cwd):
  r=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'sha256':music.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  controller=CTL.read_text(encoding='utf-8-sig');start=controller.index('function Ctl.leisureReasons(');end=controller.index('local LEISURE_WORK_OWNERS',start)
  ctl='local Ctl=SAO.Controller\n'+controller[start:end]
  prefix=(music.FIXTURES/'duet-cases.lua').read_text().split("fixture();check('source_roles_personal'",1)[0]
  cases=prefix+(HERE/'cases.lua').read_text()
  manifest=out/'source-paths.tsv';pins=music.pins()
  manifest.write_text(''.join(k+'\t'+str((music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1])+'\n'for k in pins)+''.join('social:'+n+'\t'+str(path)+'\n'for n,path in [('coord',COORD),('comm',COMM)]))
  controls=[
   ('hostile-contact','ctl','not contact.hostile and SAO.Communication.canConverse(id,contact.id)','SAO.Communication.canConverse(id,contact.id)','hostile_invitation_refused'),
   ('private-source-role','coord','choice.role==terms.partnerRole','true','absent_source_declines'),
   ('bodily-need','coord','pressure[key] >= 0.75','false','urgent_need_defers'),
   ('negative-recall','coord','affinity<0','false','negative_history_declines'),
   ('obligation','coord','not available or obligations or interests.competing','not available or interests.competing','other_obligation_defers'),
   ('response-transport','comm','local admitted = admittedConversation(fromId, toId, channel)','local admitted = "spoken"','unheard_response_stays_private'),
   ('proposal-refusal-propagation','comm','(message.payload.kind == "leisure-participation" or message.payload.kind=="leisure-duet" or message.payload.kind=="leisure-dance") and not acquired','message.payload.kind == "leisure-participation" and not acquired','lost_transport_owner_reports_refusal'),
   ('collector-truncation','ctl','local purpose=planning and planning.pending','if #candidates>=130 then return end;local purpose=planning and planning.pending','collector_retains_all_acquired_and_late_families'),
   ('invitation-source-requery','coord','SAO.Organization.proposeDuet(id,recipientId,choiceId,partnerRole,nowHours()+1)','SAO.Organization.proposeDuet(id,recipientId,__savedChoiceId,partnerRole,nowHours()+1)','stale_choice_requery_refused'),
  ]
  with tempfile.TemporaryDirectory(prefix='sao-social-')as tmp:
   work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,music.FIXTURES/'MusicProbe.java'],work);assert code==0,log
   receipt['controls']=[]
   for name,which,before,after,marker in [('baseline',None,None,None,None)]+([]if a.baseline_only else controls):
    coord=COORD.read_text(encoding='utf-8-sig');comm=COMM.read_text(encoding='utf-8-sig');current=ctl
    if before:
     target={'coord':coord,'comm':comm,'ctl':current}[which]
     start,end=0,len(target)
     if name in ['private-source-role','negative-recall','obligation']:
      start=target.index('function Coordination.duetAppraisal(');end=target.index('function Coordination.proposeDuet(',start)
     elif name=='hostile-contact':
      start=target.index('function Ctl.duetInvitationOffers(');end=target.index('function Ctl.danceInvitationOffers(',start)
     part=target[start:end];assert part.count(before)==1,(name,part.count(before));target=target[:start]+part.replace(before,after,1)+target[end:]
     if which=='coord':coord=target
     elif which=='comm':comm=target
     else:current=target
    local_manifest=out/(name+'-paths.tsv');coord_path=out/(name+'-coord.lua');comm_path=out/(name+'-comm.lua')
    coord_path.write_text(coord);comm_path.write_text(comm)
    local_manifest.write_text(manifest.read_text().replace(str(COORD),str(coord_path)).replace(str(COMM),str(comm_path)))
    owner=out/(name+'-owner.lua');owner.write_text(music.OWNER.read_text())
    script=out/(name+'-cases.lua');script.write_text(cases.replace('-- CONTROLLER_SOURCE',current))
    code,log=run(name,[music.JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'MusicProbe',local_manifest,music.FIXTURES/'prelude.lua',*native,music.LS/'shared/LSUtil.lua',music.ORG,owner,script],work)
    if marker:assert code!=0 and 'D2_SOCIAL:'+marker in log,(name,log[-7000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:assert code==0 and 'PASS D2 social 'in log,log[-7500:];receipt['checks']=int(re.search(r'PASS D2 social (\d+)',log)[1])
  receipt['inputsAfter']={str(p):music.sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs drifted'
  receipt['status']='PASS';save();print('PASS D2 social',receipt['checks'],'checks;',len(receipt['controls']),'controls');return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
