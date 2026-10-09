#!/usr/bin/env python3
"""Actor-private NewMusic playback followed by one original native dance cycle."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_music_test as music
from native_proof_preflight import installed_presence

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--baseline-only',action='store_true')
    args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar'))]
    own=Path(__file__);fixture=music.FIXTURES/'personal-dance-cases.lua'
    acquisition_fixture=music.FIXTURES/'acquisition-dance-cases.lua'
    planner=music.ROOT/'mod/42.20/media/lua/shared/SAO_ProceduralPlanning.lua'
    acquisition=music.ROOT/'mod/42.20/media/lua/client/SAO_LeisureAcquisition.lua'
    inputs=[own,fixture,acquisition_fixture,planner,acquisition,music.ROOT/'tools/native_proof_preflight.py',Path(music.__file__),music.OWNER,music.ORG,
        music.FIXTURES/'prelude.lua',music.FIXTURES/'cases.lua',music.FIXTURES/'MusicProbe.java',*native,*jars,
        music.GAME/'stdlib.lua',*[music.LS/name for name in music.LS_FILES],
        *[music.NM/name for name in music.NM_FILES+music.NM_PROOF_FILES]]
    absent=installed_presence(inputs,music.GAME,music.JDK,'D2 personal recorded dance')
    if absent is not None:return absent
    before={str(path):music.sha(path)for path in inputs}
    receipt={'schema':'sao-d2-personal-recorded-dance/1','status':'INCOMPLETE','inputsBefore':before,'runs':[],
        'boundary':'Pinned original Lifestyle solo dance callbacks and original NewMusic intent/runtime execute in native Kahlua with real Stats and source action code. Real Planner and LeisureAcquisition join the same saved purpose to personal playback and one original dance callback cycle. The WorldSources pickup receipt, actor body, carried inventory, queue, emitter, clock and audio hardware are controlled. This proves source composition and inverses, not a native pickup, loaded-game audible or rendered acceptance.'}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(name,command,cwd):
        result=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=90)
        log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr)
        receipt['runs'].append({'name':name,'exitCode':result.returncode,'log':str(log),'logSha256':music.sha(log)})
        save();return result.returncode,log.read_text(encoding='utf-8',errors='replace')
    try:
        rows=music.pins()
        receipt['sourcePins']=rows
        manifest=out/'source-paths.tsv'
        manifest.write_text(''.join(key+'\t'+str((music.LS if key.startswith('LifestyleHobbies:')else music.NM)/key.split(':',1)[1])+'\n'
            for key in {**rows,**{'NewMusic:'+name:[]for name in music.NM_PROOF_FILES}})
            +'own:planner\t'+str(planner)+'\n'+'own:acquisition\t'+str(acquisition)+'\n',encoding='utf-8')
        original=music.FIXTURES.joinpath('cases.lua').read_text(encoding='utf-8')
        anchor="local state=device();o=offer('listen-recorded-music')"
        assert original.count(anchor)==1
        combined=out/'combined-personal-dance-cases.lua'
        personal=fixture.read_text(encoding='utf-8')
        ending="print('PASS D2 personal dance '..count)"
        assert personal.count(ending)==1
        combined.write_text(original.split(anchor,1)[0]+personal.replace(ending,acquisition_fixture.read_text(encoding='utf-8')+'\n'+ending),encoding='utf-8')
        owner=music.OWNER.read_text(encoding='utf-8')
        controls=[
            ('baseline-inverse','if danceEvidence and personalRecordedDanceReady(id,body,intents) then',
                'if false then','personal_dance_intent_requests_native_voice_preparation'),
            ('actor-emitter','or channel.isWorldEmitter~=false or channel.emitter~=body:getEmitter() or not channel.soundId',
                'or channel.isWorldEmitter~=false or false or not channel.soundId','foreign_emitter_cannot_be_personal_hearing'),
            ('headphone-leak','or not finite(audibility.worldVolume) or audibility.worldVolume>.001 then return nil end',
                'or not finite(audibility.worldVolume) or false then return nil end','world_leak_cannot_be_personal_hearing'),
            ('source-epoch','if state[field]~=binding[field]then return nil end',
                'if false then return nil end','foreign_epoch_cannot_be_personal_hearing'),
            ('cycle-completion','local solo=a.danceCycle and a.danceCycle.sourceCallbackCompleted==true',
                'local solo=a.danceCycle and true','partial_original_callback_cannot_complete_personal_dance'),
            ('queue-owner','if not admitted or not ISTimedActionQueue.hasAction(a.action)then',
                'if false then','queue_refusal_retains_audio_only_failure'),
            ('foreign-source-stop','if stateExact and state.isPlaying then',
                'if state and state.isPlaying then','changed_epoch_refuses_cycle_and_preserves_new_source'),
            ('death-source-stop','and data.SAOPersonId==id and data.SAOExternalToken==w.bodyToken',
                'and false and data.SAOPersonId==id and data.SAOExternalToken==w.bodyToken',
                'death_stops_personal_source_without_cycle_credit'),
            ('death-transferred-item','local itemOwned=(live(id,a.body) or deadOwner) and resolveItem(a.body,a.offer.itemKey)==a.item',
                'local itemOwned=(live(id,a.body) and resolveItem(a.body,a.offer.itemKey)==a.item) or deadOwner',
                'death_transferred_item_preserves_source_state'),
            ('dance-acquisition-readiness','if not personalRecordedDanceReady(id,body,true) then return false end',
                'if false then return false end','dance_without_personal_concept_not_acquirable'),
        ]
        with tempfile.TemporaryDirectory(prefix='sao-personal-dance-')as temporary:
            work=Path(temporary);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua')
            cp=os.pathsep.join(map(str,jars))
            code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,music.FIXTURES/'MusicProbe.java'],work)
            assert code==0,log
            receipt['controls']=[]
            for name,old,new,marker in [('baseline',None,None,None)]+([]if args.baseline_only else controls):
                text=owner
                if old:
                    assert text.count(old)==1,(name,text.count(old))
                    text=text.replace(old,new,1)
                variant=out/(name+'-owner.lua');variant.write_text(text,encoding='utf-8')
                code,log=run(name,[music.JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                    '-cp',str(work)+os.pathsep+cp,'MusicProbe',manifest,music.FIXTURES/'prelude.lua',*native,
                    music.LS/'shared/LSUtil.lua',music.ORG,variant,combined],work)
                if marker:
                    assert code!=0 and 'D2_MUSIC:' + marker in log,(name,log[-6500:])
                    receipt['controls'].append({'name':name,'expectedFailure':marker})
                else:
                    assert code==0 and 'PASS D2 personal dance 'in log,log[-9000:]
                    receipt['checks']=int(re.search(r'PASS D2 personal dance (\d+)',log)[1])
            if not args.baseline_only:
                source=acquisition.read_text(encoding='utf-8')
                old='if row.role=="material" and provider and provider.materialRequirementAvailable then'
                assert source.count(old)==1
                variant=out/'playable-material-fallback-acquisition.lua'
                variant.write_text(source.replace(old,'if not contextual and provider and provider.materialRequirementAvailable then',1),encoding='utf-8')
                marker='own:acquisition\t'+str(acquisition)+'\n'
                manifest_text=manifest.read_text(encoding='utf-8')
                assert manifest_text.count(marker)==1
                mutant_manifest=out/'playable-material-fallback-manifest.tsv'
                mutant_manifest.write_text(manifest_text.replace(marker,'own:acquisition\t'+str(variant)+'\n'),encoding='utf-8')
                code,log=run('playable-material-fallback',[music.JDK/'java.exe','-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,'MusicProbe',mutant_manifest,
                    music.FIXTURES/'prelude.lua',*native,music.LS/'shared/LSUtil.lua',music.ORG,music.OWNER,combined],work)
                expected='D2_MUSIC:rejected_playable_cannot_fall_through_material_callback'
                assert code!=0 and expected in log,log[-6500:]
                receipt['controls'].append({'name':'playable-material-fallback','expectedFailure':expected})
        receipt['inputsAfter']={str(path):music.sha(path)for path in inputs}
        assert before==receipt['inputsAfter'],'inputs changed during proof'
        receipt['status']='PASS';save()
        print('PASS D2 personal dance',receipt['checks'],len(receipt['controls']))
        return 0
    except Exception as error:
        receipt['status']='FAIL';receipt['error']=str(error);save();raise

if __name__=='__main__':raise SystemExit(main())
