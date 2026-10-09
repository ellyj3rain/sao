#!/usr/bin/env python3
"""Installed source music in native Kahlua; bodies/audio/queues are controlled."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from native_proof_preflight import installed_presence, installed_path

ROOT=Path(__file__).resolve().parents[1]
GAME=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
JDK=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
LS=installed_path(r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3403870858\mods\Lifestyle\common\media\lua')
NM=installed_path(r'C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3739256725\mods\Talis New Music\42\media\lua')
OWNER=ROOT/'mod/42.20/media/lua/client/SAO_LeisureMusic.lua'
ORG=ROOT/'mod/42.20/media/lua/shared/SAO_Organization.lua'
FIXTURES=ROOT/'tools/d2_leisure_music'
LS_FILES=['shared/LSUtil.lua','shared/Instruments/animations.lua',
    *['shared/TimedActions/'+n+'.lua' for n in ['PlayInstrumentActionNew','PlayInstrumentTraining','PlayInstrumentVocal','PlayerIsDancingToMusic']],
    'client/TimedActions/PlayerVoiceTracks.lua','client/TimedActions/PlayerDanceMoves.lua','client/XpSystem/PlayerTracker.lua',
    'client/LSDanceEffects.lua','client/JukeboxContextMenu.lua',
    'client/Instruments/Tracks/PlayVocalTracksDuet.lua',
    'client/Instruments/Tracks/PlayPianoTracks.lua',
    'client/Instruments/InstrumentPianoContextMenu.lua',
    'client/LSIsListeningEffects.lua','client/Instruments/VocalContextMenu.lua',
    'client/Instruments/Tracks/PlayPianoTracksDuet.lua',
    *['client/TimedActions/Play'+n+'TracksDuet.lua' for n in ['Banjo','GuitarAcoustic','GuitarElectricBass','GuitarElectric','Flute','Trumpet','Keytar','Saxophone','Violin','Harmonica']],
    *['client/TimedActions/Play'+n+'Tracks.lua' for n in ['Banjo','GuitarAcoustic','GuitarElectricBass','GuitarElectric','Flute','Trumpet','Keytar','Saxophone','Violin','Harmonica']]]
NM_FILES=['shared/helpers/NMAttachmentHelpers.lua','client/sync/NMClientModeReconcile.lua','shared/audio/NMPlaybackRuntimeCommon.lua','shared/audio/NMPlaybackRuntime.lua','client/intents/NMClientIntentDispatch.lua']
NM_PROOF_FILES=['shared/core/NMCore.lua','shared/core/NMRuntimeConfig.lua',
    'shared/contracts/NMDeviceProfileCatalog.lua','shared/contracts/NMDeviceProfiles.lua','shared/contracts/NMDeviceProfilesRuntime.lua','shared/contracts/NMDeviceProfilesPortable.lua',
    'shared/state/NMDeviceState.lua','shared/state/NMTransitionCommon.lua',
    'shared/state/NMTransitionActionHandlers.lua','shared/state/NMDeviceTransitions.lua',
    'shared/intent/NMIntentPayloadBuilder.lua','shared/intent/NMIntentInventoryOps.lua',
    'shared/playback_progression/NMTrackCountResolver.lua','shared/audio/NMPlaybackAudibility.lua']

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def pins():
    rows={}
    for mod,root,files in [('LifestyleHobbies',LS,LS_FILES),('NewMusic',NM,NM_FILES)]:
        for name in files:
            path=root/name;lines=path.read_text(encoding='utf-8-sig').splitlines();a=b=0
            for line in lines:
                encoded=(line+'\n').encode('utf-16-le')
                for byte in [encoded[i]+256*encoded[i+1] for i in range(0,len(encoded),2)]:
                    a=(a*31+byte)%2147483647;b=(b*131+byte)%2147483647
            rows[mod+':'+name]=[sha(path),a,b,len(lines)]
    return rows

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--write-pins',action='store_true');parser.add_argument('--baseline-only',action='store_true')
    args=parser.parse_args()
    if args.write_pins:
        rows=pins()
        source=OWNER.read_text(encoding='utf-8');marker='local PINS = {} -- SOURCE_PINS_INSERT'
        if marker not in source:
            source=re.sub(r'local PINS = \{\n.*?\n\}',marker,source,count=1,flags=re.S)
        assert source.count(marker)==1
        table='local PINS = {\n'+''.join('    ['+json.dumps(k)+'] = { '+json.dumps(v[0])+', '+', '.join(map(str,v[1:]))+' },\n' for k,v in rows.items())+'}'
        OWNER.write_text(source.replace(marker,table),encoding='utf-8',newline='')
        return 0
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    native=[GAME/'media/lua/shared/ISBaseObject.lua',GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    jars=[GAME/'projectzomboid.jar',*sorted((GAME/'jars').glob('*.jar'))]
    inputs=[Path(__file__),OWNER,ORG,*[p for p in FIXTURES.iterdir() if p.is_file()],*native,*jars,GAME/'stdlib.lua',
        *[LS/name for name in LS_FILES],*[NM/name for name in NM_FILES+NM_PROOF_FILES]]
    absent=installed_presence(inputs,GAME,JDK,'D2 isolated music source',installed_roots=(LS.parent,NM.parent))
    if absent is not None:return absent
    rows=pins()
    before={str(p):sha(p) for p in inputs}
    receipt={'schema':'sao-d2-source-music/1','status':'INCOMPLETE','inputsBefore':before,'sourcePins':rows,'runs':[],
        'boundary':'Unchanged installed action constructors/start/update/perform/stop, animation and track data, LSUtil; native Kahlua/Stats/save-load. Actor bodies, queues, emitter callbacks, clocks and planner are controlled. Tali full unchanged dispatch/runtime source loads in isolated actor environments; focused Common battery/ending controls and actual dispatch/runtime exercise are labelled independently. No rendered audio, loaded-game performance or multiplayer NPC authority claim.'}
    def save(): (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(name,command,cwd):
        result=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=90)
        log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr)
        receipt['runs'].append({'name':name,'exitCode':result.returncode,'log':str(log),'logSha256':sha(log)});save()
        return result.returncode,log.read_text(encoding='utf-8',errors='replace')
    try:
        text=OWNER.read_text(encoding='utf-8')
        for row in rows.values():assert row[0] in text,'source pin missing'
        source_manifest=out/'source-paths.tsv'
        manifest={**rows,**{'NewMusic:'+name:[] for name in NM_PROOF_FILES}}
        source_manifest.write_text(''.join(k+'\t'+str((LS if k.startswith('LifestyleHobbies:') else NM)/k.split(':',1)[1])+'\n' for k in manifest),encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='sao-music-') as temp:
            work=Path(temp);shutil.copyfile(GAME/'stdlib.lua',work/'stdlib.lua')
            cp=os.pathsep.join(map(str,jars))
            code,log=run('compile',[JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,FIXTURES/'MusicProbe.java'],work);assert code==0,log
            controls=[
                ('spoof','same(row,offer)','true','spoof_offer_refused'),
                ('body','SAO.Needs.ownsRecoveryBody(id,body)==true','true','foreign_custody_cannot_repair_voice'),
                ('planner','not planner.admitHobbyWork(id,purposeId,w.sequence,OWNER)','false','planner_refusal_prevents_queue'),
                ('sound-proof','(dance or a.heard\n','(dance or true\n','failed_practice_audio_no_completion'),
                ('ending-proof','and a.soundEnded)','and true)','early_timer_no_completion'),
                ('global-volume','function sm:setMusicVolume(v) self.volume=v end','function sm:setMusicVolume(v) getSoundManager():setMusicVolume(v) end','global_volume_unchanged'),
                ('detached','then return plain(row) end end','then return row end end','detached_outcome'),
                ('custody','return resolveItem(a.body,a.offer.itemKey)==a.item','return true','lost_custody_interrupts'),
                ('revision','h1~=pin[2] or h2~=pin[3] or #lines~=pin[4]','false','changed_repair_source_refused'),
                ('tali-callback','token.playbackEpoch~=binding.playbackEpoch','false','tali_foreign_callback_refused'),
                ('tali-sound','if not a.heard or token.uuid','if false or token.uuid','tali_no_sound_callback_refused'),
                ('tali-stale','if state[field]~=binding[field] then','if false then','tali_foreign_epoch_interrupts'),
                ('maintained-purpose','if not admission or admission.ownerName~=OWNER or admission.sequence~=w.sequence then return false end','if false then return false end','maintained_purpose_required'),
                ('source-voice-init','env.sourceVoiceInitializer(body)','local ignored=body','source_actor_voice_initialized'),
                ('tali-ending-evidence','if not endingEvidence then error("source-debounced-audio-ending-unproven") end','if false then error("source-debounced-audio-ending-unproven") end','tali_premature_same_tuple_refused'),
                ('private-skill','a.skillRequests and a.skillRequests[sequence]','person(id).leisureMusicSkillRequests and person(id).leisureMusicSkillRequests[sequence]','durable_skill_tampering_refused'),
                ('piano-seat','a and b and body:isSittingOnFurniture() and','a and b and true and','piano_native_seat_required'),
                ('piano-pair-custody','and resolveObject(id,a.body,a.offer.pairObjectKey)==a.pairObject','and true','piano_pair_custody_loss_interrupts'),
                ('piano-offset-cache','if prior and prior.sourceOffsetApplied','if false and prior.sourceOffsetApplied','piano_same_seat_no_accumulated_offset'),
            ]
            controls.extend([
                ('recorded-location','if context~=a.offer.sourceContext or NMDeviceProfiles.resolveOutputMode(profile,state,context,false)~="personal" then error("source-device-location-or-output-changed") end',
                    'if false or NMDeviceProfiles.resolveOutputMode(profile,state,context,false)~="personal" then error("source-device-location-or-output-changed") end','tali_actual_location_change_interrupts'),
                ('recorded-output','(SAO.LeisureMusicSupply and SAO.LeisureMusicSupply.outputMode(profile,state,context,supplies)\n                    or NMDeviceProfiles.resolveOutputMode(profile,state,context,false))=="personal"','true','tali_world_output_no_personal_admission'),
                ('recorded-callback-context','or token.context~=a.offer.sourceContext','or false','tali_foreign_source_context_callback_refused'),
            ])
            receipt['controls']=[]
            variants=[('baseline',None,None,None)]+([] if args.baseline_only else controls)
            for name,old,new,marker in variants:
                value=text
                if old:assert value.count(old)==1,(name,value.count(old));value=value.replace(old,new,1)
                variant=out/(name+'-owner.lua');variant.write_text(value,encoding='utf-8',newline='')
                code,log=run(name,[JDK/'java.exe','-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED','-cp',str(work)+os.pathsep+cp,
                    'MusicProbe',source_manifest,FIXTURES/'prelude.lua',*native,LS/'shared/LSUtil.lua',ORG,variant,FIXTURES/'cases.lua'],work)
                if marker:
                    assert code!=0 and 'D2_MUSIC:'+marker in log,(name,log[-4500:]);receipt['controls'].append({'name':name,'expectedFailure':marker})
                else:
                    assert code==0 and 'PASS D2 source music ' in log,log[-6500:]
                    receipt['checks']=int(re.search(r'PASS D2 source music (\d+)',log)[1])
        receipt['inputsAfter']={str(p):sha(p) for p in inputs};assert before==receipt['inputsAfter'],'inputs changed during proof'
        receipt['status']='PASS';save();print('PASS D2 source music;',len(receipt['controls']),'restored defect controls');return 0
    except Exception as error:
        receipt['status']='FAIL';receipt['error']=str(error);save();raise

if __name__=='__main__':raise SystemExit(main())
