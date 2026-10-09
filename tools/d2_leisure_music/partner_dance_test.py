#!/usr/bin/env python3
"""Typed delivered dance consent and exact original source partner callbacks."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_music_test as music
import d2_leisure_music.world_audio_test as world
from native_proof_preflight import installed_presence
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--baseline-only',action='store_true');a=p.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 coord=music.ROOT/'mod/42.20/media/lua/shared/SAO_Coordination.lua';comm=music.ROOT/'mod/42.20/media/lua/shared/SAO_Communication.lua';ctl=music.ROOT/'mod/42.20/media/lua/client/SAO_Controller.lua'
 native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
 jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
 inputs=[Path(__file__),music.ROOT/'tools/native_proof_preflight.py',Path(music.__file__),Path(world.__file__),music.OWNER,music.ORG,coord,comm,ctl,music.FIXTURES/'prelude.lua',music.FIXTURES/'world-audio-cases.lua',music.FIXTURES/'partner-dance-cases.lua',music.FIXTURES/'MusicProbe.java',*native,*jars,music.GAME/'stdlib.lua',*[music.LS/n for n in music.LS_FILES],*[music.NM/n for n in music.NM_FILES+music.NM_PROOF_FILES+world.EXTRA]]
 absent=installed_presence(inputs,music.GAME,music.JDK,'D2 partner dance consent/source',installed_roots=(music.LS.parent,music.NM.parent))
 if absent is not None:return absent
 receipt={'schema':'sao-d2-source-partner-dance/1','status':'INCOMPLETE','inputsBefore':{str(f):music.sha(f)for f in inputs},'runs':[],'controls':[],
 'boundary':'Full actual Organization/Coordination/Communication, exact extracted Controller leisure hooks, complete original source dance/acceptance/positioning/face/stop and pinned original willingness producers. Native Kahlua/Stats/save-load with controlled bodies/queue/acquisition/source public renderer/hardware/native hearing/personal relationship-interest inputs. Native AnimationTrack helper absent by default; selected foreign/stale/readiness/completion/cleanup controls explicitly use controlled native helper receipts and scopes. Acceptance/animation assignment alone remains active. Actual native AnimationTrack.Update and LuaTimedActionNew.perform weave producer qualification is a separate caller proof.'}
 def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def run(name,cmd,cwd):
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(r.stdout+r.stderr)
  receipt['runs'].append({'name':name,'exitCode':r.returncode,'logSha256':music.sha(log)});save();return r.returncode,log.read_text(errors='replace')
 try:
  keys={**music.pins(),**{'NewMusic:'+n:[]for n in music.NM_PROOF_FILES+world.EXTRA},'social:coord':[],'social:comm':[]}
  manifest=out/'source-paths.tsv';manifest.write_text(''.join(k+'\t'+str({'social:coord':coord,'social:comm':comm}.get(k,(music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1]))+'\n'for k in keys))
  text=ctl.read_text(encoding='utf-8-sig');hooks='local Ctl=SAO.Controller\n'+text[text.index('function Ctl.leisureReasons('):text.index('local LEISURE_WORK_OWNERS')]
  prefix=(music.FIXTURES/'world-audio-cases.lua').read_text().split('local function offer()')[0]
  combined=out/'combined-partner-dance.lua';combined.write_text(prefix+(music.FIXTURES/'partner-dance-cases.lua').read_text().replace('-- CONTROLLER_SOURCE',hooks))
  with tempfile.TemporaryDirectory(prefix='sao-partner-dance-')as tmp:
   work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
   code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,music.FIXTURES/'MusicProbe.java'],work);assert code==0,log
   controls=[
    ('generic-proposal','org','if kind=="leisure-dance" and authority~=DANCE then return nil end','if false then return nil end','generic_proposal_consent_and_receipt_bypass_refused'),
    ('generic-originator','org','if process and process.kind=="leisure-dance" and authority~=DANCE then return nil,"typed-dance-originator-required"end','if false then return nil end','generic_originator_commitment_refused'),
    ('generic-work','org','if process and process.kind == "leisure-dance" and authority ~= DANCE then return false end','if false then return false end','generic_work_admission_refused'),
    ('generic-result','org','if process and process.kind == "leisure-dance" and authority ~= DANCE then return false end','if false then return false end','generic_procedure_result_refused'),
    ('source-visibility','owner','or not a.body:CanSee(peer.body)or not peer.body:CanSee(a.body)','or false ','current_native_visibility_required_before_release'),
    ('original-willingness','owner','target.env.JukeboxMenu.onEnableDancing(target.body)','do end','both_actual_source_owners_release_original_acceptance'),
    ('native-cycle-custody','owner','cycle.actorId~=id','false','foreign_native_cycle_receipt_refused'),
    ('native-cycle-current','owner','SAOJavaBridge:nativeDanceCycleCurrent(a.body,w.workId,cycle.sequence)~=true','false','noncurrent_native_cycle_receipt_refused'),
    ('completion-readiness','owner','SAOJavaBridge:nativeDanceCycleCompletionReady()~=true','false','unready_native_completion_never_registers_cycle'),
    ('completion-authority','owner','SAOJavaBridge:nativeDanceCycleCompletionCurrent(body,w.workId,a.partnerCycle.sequence)==true','true','completion_scope_false_refused'),
    ('emission-ownership','owner','and w.workId==workId and a.offer.roleAnimation==clip','and true','emission_guard_only_exact_maintained_owners'),
    ('native-need','coord','pressure[key] >= 0.75','false','current_need_defers'),
    ('negative-memory','dance-appraisal','affinity<0','false','negative_personal_recall_declines'),
    ('own-obligation','dance-appraisal','not available or obligations or interests.competing','not available or interests.competing','other_accepted_obligation_defers'),
    ('return-transport','comm','local admitted = admittedConversation(fromId, toId, channel)','local admitted = "spoken"','unheard_return_no_agreement'),
    ('cleanup-fault-containment','owner','local ok,result=pcall(callback)','local ok,result=true,callback()','independent_source_cleanup_faults_cannot_escape_or_skip_native_retirement'),
    ('unconfirmed-native-retirement','owner','requiresConfirmation and result~=true','false','native_retirement_false_explicitly_unconfirmed'),
    ('first-finisher-peer-stop','owner','retirePartnerDance(a,nativePartner and succeeded)','retirePartnerDance(a)','first_native_dance_part_preserves_second'),
    ('second-finisher-native-guard','owner','or completedPartnerDance(a,peer)','or false','first_native_dance_part_preserves_second'),
    ('wrong-dance-partner','org','or bind.partnerId~=partnerId or bind.role~=choice.role','or false or bind.role~=choice.role','wrong_partner_result_no_dance_receipt'),
    ('wrong-dance-revision','org','or bind.revision~=process.revision or bind.commitmentId~=own.commitmentId','or false or bind.commitmentId~=own.commitmentId','wrong_revision_result_no_dance_receipt'),
    ('wrong-dance-role','org','or bind.role~=choice.role or bind.musicKey~=terms.musicKey','or false or bind.musicKey~=terms.musicKey','wrong_role_result_no_dance_receipt'),
    ('wrong-dance-source-choice','org','or result.sourceId~=terms.sourceId or not danceChoiceEqual(result.sourceOffer,choice)','or result.sourceId~=terms.sourceId or false','wrong_music_result_no_dance_receipt'),
    ('missing-dance-perform','org','or native.danceReleased~=true or native.sourcePerformReturned~=true','or native.danceReleased~=true or false','missing_native_perform_return_no_dance_receipt'),
    ('wrong-dance-native-partner','org','or setup.role~=choice.role or setup.partnerId~=partnerId','or setup.role~=choice.role or false','wrong_native_setup_partner_no_dance_receipt'),
   ]
   for name,which,old,new,marker in [('baseline',None,None,None,None)]+([]if a.baseline_only else controls):
    sources={'owner':music.OWNER.read_text(),'org':music.ORG.read_text(encoding='utf-8-sig'),'coord':coord.read_text(encoding='utf-8-sig'),'comm':comm.read_text(encoding='utf-8-sig')}
    if old:
     key='coord'if which=='dance-appraisal'else which;text=sources[key]
     start=text.index('function Coordination.danceAppraisal(')if which=='dance-appraisal'else 0
     end=text.index('function Coordination.proposeDance(',start)if which=='dance-appraisal'else len(text)
     part=text[start:end];count=part.count(old)
     expected=2 if name in ['generic-work','generic-result']else 1
     assert count==expected,(name,count)
     if name=='generic-result':at=part.rindex(old);part=part[:at]+part[at:].replace(old,new,1)
     else:part=part.replace(old,new,1)
     sources[key]=text[:start]+part+text[end:]
    paths={}
    for key,text in sources.items():paths[key]=out/(name+'-'+key+'.lua');paths[key].write_text(text)
    localManifest=out/(name+'-sources.tsv');localManifest.write_text(manifest.read_text().replace(str(coord),str(paths['coord'])).replace(str(comm),str(paths['comm'])))
    code,log=run(name,[music.JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'MusicProbe',localManifest,music.FIXTURES/'prelude.lua',*native,music.LS/'shared/LSUtil.lua',paths['org'],paths['owner'],combined],work)
    if marker:assert code!=0 and 'D2_PARTNER_DANCE:'+marker in log,(name,log[-10000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
    else:assert code==0 and 'PASS source partner dance 'in log,log[-10000:];receipt['checks']=int(re.search(r'PASS source partner dance (\d+)',log)[1])
  receipt['inputsAfter']={str(f):music.sha(f)for f in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs changed'
  receipt['status']='PASS';save();print('PASS source partner dance',receipt['checks'],len(receipt['controls']));return 0
 except Exception as e:receipt['status']='FAIL';receipt['error']=str(e);save();raise
if __name__=='__main__':raise SystemExit(main())
