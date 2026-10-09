#!/usr/bin/env python3
"""Actual Organization agreement and unchanged Lifestyle duet sources in Kahlua."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,tempfile
import d2_leisure_music_test as music
from native_proof_preflight import installed_presence

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--baseline-only',action='store_true');args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
    inputs=[Path(__file__),Path(music.__file__),music.OWNER,music.ORG,*[p for p in music.FIXTURES.iterdir() if p.is_file()],*native,*jars,
        music.GAME/'stdlib.lua',*[music.LS/p for p in music.LS_FILES],*[music.NM/p for p in music.NM_FILES]]
    absent=installed_presence(inputs,music.GAME,music.JDK,'D2 source duet',installed_roots=(music.LS.parent,music.NM.parent))
    if absent is not None:return absent
    receipt={'schema':'sao-d2-source-duet/1','status':'INCOMPLETE','inputsBefore':{str(p):music.sha(p) for p in inputs},'runs':[],
        'boundary':'Actual unchanged Organization proposal/acquisition/appraisal/respond/deliver/claimed commitments and typed work/result APIs. Original installed source instrument/vocal constructors/start/update/perform/stop, LSUtil and exact OtherPlayerIsStartingDuet callback; native Kahlua/Stats/save-load. Actor bodies/queues/emitters/native visibility/front geometry/clocks/concept familiarity/learned source history/planner and communication transport host controlled. No rendered native transport, broad normal policy reachability or multiplayer claim.'}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(name,args,cwd):
        result=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True,timeout=90)
        log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr)
        receipt['runs'].append({'name':name,'exitCode':result.returncode,'log':str(log),'sha256':music.sha(log)});save()
        return result.returncode,log.read_text(encoding='utf-8',errors='replace')
    try:
        owner=music.OWNER.read_text(encoding='utf-8');organization=music.ORG.read_text(encoding='utf-8-sig')
        manifest=out/'source-paths.tsv';pins=music.pins()
        manifest.write_text(''.join(k+'\t'+str((music.LS if k.startswith('LifestyleHobbies:') else music.NM)/k.split(':',1)[1])+'\n' for k in pins),encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='sao-duet-')as tmp:
            work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
            code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,music.FIXTURES/'MusicProbe.java'],work);assert code==0,log
            controls=[
                ('premature-delivery','org','return Org.appraiseMatter(processId,id,context,DUET)',
                 'local formed=Org.appraiseMatter(processId,id,context,DUET);Org.deliverResponse(processId,id,process.originatorId,"premature",{});return formed','generic_duet_delivery_refused'),
                ('generic-reception','org','not participationTransport(processId, fromId, personId, "proposal")','false','generic_duet_reception_refused'),
                ('generic-delivery','org','not participationTransport(processId, personId, toId, "response")','false','generic_duet_delivery_refused'),
                ('generic-raise','org','if kind=="leisure-duet" and authority~=DUET then return nil end','if false then return nil end','generic_duet_proposal_refused'),
                ('generic-appraise','org','process and process.kind=="leisure-duet" and authority~=DUET','false','generic_duet_appraisal_refused'),
                ('generic-response','org','process and process.kind=="leisure-duet" and authority~=DUET','false','generic_duet_response_refused'),
                ('foreign-actor','org','(id~=terms.originatorId and id~=terms.partnerId)','false','foreign_actor_no_agreement'),
                ('expired','org','terms.expiresAtHours<nowHours()','false','expired_agreement_refused'),
                ('song','org','choice.songId~=terms.songId','false','foreign_song_acceptance_refused'),
                ('admission-bypass','org','process.kind == "leisure-duet" and authority ~= DUET','false','generic_work_admission_refused'),
                ('terminal-bypass','org','process.kind == "leisure-duet" and authority ~= DUET','false','generic_terminal_result_refused'),
                ('piano-duet-flag','music','current.trackLevel,false,current.isDuet==true,result.object)',
                 'current.trackLevel,false,false,result.object)','piano_original_duet_waits'),
                ('missing-peer','music','local agreement=SAO.Organization.duetReady and SAO.Organization.duetReady(id,a.offer.duet.processId)',
                 'local agreement={partnerId=id}','missing_partner_does_not_release'),
                ('visibility','music','a.body:CanSee(partner.body) and partner.body:CanSee(a.body)','true','private_visibility_blocks_release'),
                ('wrong-result-partner','org','bind.partnerId~=partnerId','false','wrong_partner_result_no_receipt'),
                ('missing-native-perform','org','native.sourcePerformReturned~=true','false','missing_native_result_no_receipt'),
                ('duplicate-delivery','org','if duplicate and freezeDuetParticipation(processId) then deliverDuetParticipation(processId) end',
                 'if false then deliverDuetParticipation(processId) end','duplicate_callback_retries_without_rewrite'),
            ]
            receipt['controls']=[]
            for name,which,before,after,marker in [('baseline',None,None,None,None)]+([]if args.baseline_only else controls):
                current_owner,current_org=owner,organization
                if before:
                    # Duet and dance retain parallel guards. Mutate the duet
                    # section only so the control stays bound to its producer.
                    dance_boundary=current_org.index('local DANCE_CHOICE_FIELDS=') if which=='org' else None
                    target=current_org[:dance_boundary] if which=='org' else current_owner
                    if name=='premature-delivery':
                        target=target.replace('not participationTransport(processId, personId, toId, "response")','false',1)
                    if name=='generic-appraise':
                        target=target.replace('process and process.kind=="leisure-duet" and authority~=DUET','false')
                        before=None
                    if name=='foreign-actor':
                        target=target.replace('local view=Org.viewFor(id,processId,true)','local view=Org.viewFor(process.originatorId,processId,true)',1)
                    if name=='generic-appraise':
                        pass
                    elif name=='generic-response':
                        assert target.count(before)==2
                        position=target.index(before) if name=='generic-appraise' else target.rfind(before)
                        target=target[:position]+target[position:].replace(before,after,1)
                    elif name=='terminal-bypass':
                        assert target.count(before)==2;position=target.rfind(before);target=target[:position]+target[position:].replace(before,after,1)
                    else:assert target.count(before)==(2 if name=='admission-bypass' else 1),(name,target.count(before));target=target.replace(before,after,1)
                    if which=='org':current_org=target+current_org[dance_boundary:]
                    else:current_owner=target
                op=out/(name+'-owner.lua');op.write_text(current_owner,encoding='utf-8')
                gp=out/(name+'-organization.lua');gp.write_text(current_org,encoding='utf-8')
                code,log=run(name,[music.JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                    '-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,music.FIXTURES/'prelude.lua',*native,
                    music.LS/'shared/LSUtil.lua',gp,op,music.FIXTURES/'duet-cases.lua'],work)
                if marker:
                    assert code!=0 and 'D2_DUET:'+marker in log,(name,log[-6000:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
                else:assert code==0 and 'PASS D2 source duet 'in log,log[-6500:];receipt['checks']=int(re.search(r'PASS D2 source duet (\d+)',log)[1])
        receipt['inputsAfter']={str(p):music.sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs drifted'
        receipt['status']='PASS';save();print('PASS source duet',receipt['checks'],'checks;',len(receipt['controls']),'controls');return 0
    except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
