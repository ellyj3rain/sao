#!/usr/bin/env python3
"""Personally visible native loose item -> actual SourceUse -> maintained leisure receiver."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile
from native_proof_preflight import installed_presence
ROOT=Path(__file__).resolve().parents[1]
HERE=ROOT/'tools/floor_asset_checks'
CONTROLS=[
 ('observation-join-omitted','Perception','        pcall(function() P.observeLooseItems(id, body, tick) end)\n','','ordinary_perception_cadence_produces_floor_offer',1),
 ('native-instrument-omitted','java-needs','|| ("Instrument".equals(item.getDisplayCategory())','|| (false && "Instrument".equals(item.getDisplayCategory())','material_support_uses_installed_metadata',1),
 ('native-gaze-omitted','java-sources','if (!SAOPerceptionScanner.canSeeWorldSquareNow(shell, square, radius)) continue;','if (square == null) continue;','hidden_or_other_floor_is_not_observed',2),
 ('body-authority-omitted','WorldSources','or not SAO.Needs.ownsRecoveryBody or not SAO.Needs.ownsRecoveryBody(actorId,body)','or not SAO.Needs.ownsRecoveryBody','foreign_asleep_dead_and_external_bodies_refused',1),
 ('partial-source-erased','WorldSources','if partial and not seen[id] then','if false then','visible_packet_preserves_other_observed_source',1),
 ('passive-full-inspection','Perception','source == "native-visible-ground" and "visible-ground" or nil','nil','passive_sight_does_not_reveal_hidden_fluid_safety',1),
 ('hidden-fluid-refilled','WorldSources','observed.knowledgeKind ~= "visible-ground" and observed.revision == physical.revision','observed.revision == physical.revision','passive_sight_does_not_reveal_hidden_fluid_safety',1),
 ('private-signature-refilled','WorldSources','operation == "acquire" and source.knowledgeKind ~= "visible-ground" and itemSignature(item)','operation == "acquire" and itemSignature(item)','visible_leisure_candidates_do_not_refill_hidden_fields',1),
 ('future-observation-admitted','Perception',' or tick ~= nil and tick ~= current','','future_observation_time_cannot_create_private_offer',1),
 ('floor-alternative-omitted','Controller','ipairs(Ctl.leisureGroundOffers(id,body))','ipairs({})','actual_harmonica_acquisition_then_same_purpose_native_sound',1),
 ('acquired-continuity-omitted','Controller','if not retained and planning and planning.leisureAcquiredPurpose then','if false then','acquired_reading_purpose_competes_with_other_carried_material',1),
 ('acquired-purpose-forked','ProceduralPlanning','        or acquiredLeisurePurpose(id, itemKey, context.affordance, context.owner)\n','','actual_harmonica_acquisition_then_same_purpose_native_sound',1),
 ('generic-acquisition-completed','ProceduralPlanning','    if purpose and purpose.leisureAcquisition and not purpose.leisure and authority ~= RESOURCE_RESULT then return false end\n','','queue_and_generic_result_are_not_acquisition',1),
 ('result-item-unbound','ProceduralPlanning','or acquisition.itemId~=tostring(authoritative.itemId) or acquisition.itemType~=authoritative.itemType','or acquisition.itemType~=authoritative.itemType','contrary_private_acquisition_identity_refuses_result',1),
 ('retry-not-retained','ProceduralPlanning','            if finite(acquisition.failedAt) and nowHours() < acquisition.failedAt + 1/60 then return false end\n','','interrupted_acquisition_delays_only_exact_source_retry',1),
 ('reacquisition-rewrites-history','ProceduralPlanning','    if previous then key=key..":after:"..previous end\n','','reobserved_dropped_item_retains_prior_acquisition_receipt',1),
]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--variants',nargs='+')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    game=Path(os.environ.get('PZ_DIR',r'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'))
    jdk=Path(os.environ.get('JDK_BIN',r'C:\Users\jleyv\Peanut Butter\JetBrains\Java\bin'))
    jars=[game/'projectzomboid.jar',game/'ZombieBuddy.jar',ROOT/'mod/42.20/media/java/SAO.jar']
    java=[ROOT/p for p in ['java/src/com/sao/engine/SAOWorldSources.java','java/src/com/sao/engine/SAONeeds.java',
        'java/src/com/sao/bridge/SAOBridge.java','java/src/com/sao/engine/SAOWorldSoundPulses.java',
        'java/src/com/sao/engine/SAOPerceptionScanner.java','java/src/com/sao/engine/SAOSenses.java',
        'java/src/com/sao/agent/SAOOrientationWeave.java','tools/luacheck/MovementCrossingProbe.java',
        'tools/luacheck/ResourceApproachProbe.java','tools/cognition_checks/CognitionUseProbe.java',
        'tools/instrument_checks/InstrumentProbe.java','tools/orienting_checks/OrientationProbeAgent.java']]+[HERE/'FloorAssetFixture.java']
    prototype=ROOT/'tools/participation_pulse_checks/PulseParticipationProbe.java'
    runtime={name:ROOT/'mod/42.20/media/lua'/area/('SAO_'+name+'.lua') for name,area in [
        ('Needs','client'),('Gesture','client'),('Study','client'),('Controller','client'),
        ('WorldSources','shared'),('Perception','shared'),('ProceduralPlanning','shared'),('SourceUse','client')]}
    runtime.update({name:ROOT/'mod/42.20/media/lua/shared'/('SAO_'+name+'.lua') for name in ('CognitiveModels','Cognition')})
    native=[game/'media/lua'/p for p in ['shared/ISBaseObject.lua','shared/TimedActions/ISBaseTimedAction.lua',
        'client/TimedActions/ISTimedActionQueue.lua','shared/TimedActions/ISReadABook.lua',
        'client/TimedActions/ISGrabItemAction.lua']]
    fixtures=[ROOT/'tools/instrument_checks/prelude.lua',ROOT/'tools/instrument_checks/setup.lua',HERE/'setup.lua',HERE/'cases.lua']
    inputs=[Path(__file__),*java,prototype,*runtime.values(),*native,*fixtures,*jars,game/'stdlib.lua',
        *[game/'media/scripts/generated/items'/p for p in ['normal.txt','weapon.txt','literature.txt']]]
    inputs.append(Path(__file__).with_name('native_proof_preflight.py'))
    preflight = installed_presence(inputs, game, jdk, "floor asset verb")
    if preflight is not None:
        raise SystemExit(preflight)
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    receipt={'status':'INCOMPLETE','inputsBefore':{str(p):sha(p)for p in inputs},'commands':[],
        'boundary':'Installed native body/item/source identity/visibility/grab/read/sound and Kahlua serialization with actual Cognition/Models and full Controller/Lua owners. Controlled personal values, locomotion scheduling, audio hardware and downstream receipt transport; no game/cache/save mutation or rendered acceptance.'}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(label,command,cwd):
        r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=120)
        log=out/(label+'.log');log.write_bytes(r.stdout+r.stderr)
        receipt['commands'].append({'name':label,'command':list(map(str,command)),'exitCode':r.returncode,'log':str(log),'logSha256':sha(log)})
        save();return r.returncode,log.read_text(encoding='utf-8',errors='replace')
    try:
        with tempfile.TemporaryDirectory(prefix='sao-floor-asset-') as temp:
            work=Path(temp);classes=work/'classes';classes.mkdir();shutil.copyfile(game/'stdlib.lua',work/'stdlib.lua')
            generated=prototype.read_text().replace('public final class PulseParticipationProbe','public final class FloorAssetProbe')
            anchor='{"weapon.txt","GuitarAcoustic","__guitar"}'
            assert generated.count(anchor)==1
            generated=generated.replace(anchor,anchor+',{"literature.txt","Book","__book"},{"literature.txt","Notebook","__notebook"},{"normal.txt","WaterBottle","__bottle"}')
            anchor='        for(int i=1;i<args.length;i++){'
            assert generated.count(anchor)==1
            generated=generated.replace(anchor,'        FloorAssetFixture.install(env,exposer,cell);\n'+anchor)
            probe=out/'FloorAssetProbe.java';probe.write_text(generated,encoding='utf-8')
            cp=os.pathsep.join(map(str,jars))
            code,log=run('compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',classes,*java,probe],work)
            assert code==0,log[-5000:]
            manifest=work/'MANIFEST.MF';manifest.write_text('Manifest-Version: 1.0\nPremain-Class: OrientationProbeAgent\nCan-Retransform-Classes: true\n\n')
            agent=work/'agent.jar';code,log=run('agent',[jdk/'jar.exe','cfm',agent,manifest,'-C',classes,'.'],work);assert code==0,log
            expected=set(re.findall(r'check\("([a-z0-9_]+)"',(HERE/'cases.lua').read_text()))
            variants=args.variants or ['production',*[c[0] for c in CONTROLS]]
            assert set(variants)<={'production',*[c[0] for c in CONTROLS]}
            receipt['variants']=[]
            for variant in variants:
                pathsByName=runtime.copy();extra='';marker=None
                if variant!='production':
                    _,key,before,after,marker,count=next(c for c in CONTROLS if c[0]==variant)
                    target={'java-needs':java[1],'java-sources':java[0]}.get(key,runtime.get(key))
                    source=target.read_text(encoding='utf-8-sig');assert source.count(before)==count,variant+': anchor'
                    directory=out/variant;directory.mkdir();overlay=directory/target.name
                    overlay.write_text(source.replace(before,after,1),encoding='utf-8')
                    if key.startswith('java-'):
                        overlayClasses=directory/'classes';overlayClasses.mkdir()
                        code,log=run(variant+'-compile',[jdk/'javac.exe','-encoding','UTF-8','-cp',str(classes)+os.pathsep+cp,'-d',overlayClasses,overlay],work)
                        assert code==0,log;extra=str(overlayClasses)+os.pathsep
                    else:pathsByName[key]=overlay
                controller=out/(variant+'-Controller.lua')
                source=pathsByName['Controller'].read_text(encoding='utf-8-sig');assert source.count('return Ctl\n')==1
                controller.write_text(source.replace('return Ctl\n','Ctl.__floorRest=decideRestActivity\nreturn Ctl\n'),encoding='utf-8')
                paths=[fixtures[0],*native,fixtures[1],HERE/'setup.lua',*[pathsByName[k] for k in
                    ('Needs','Gesture','WorldSources','Perception','CognitiveModels','Cognition','ProceduralPlanning','Study','SourceUse')],controller,HERE/'cases.lua']
                code,log=run(variant,[jdk/'java.exe','-Duser.home='+str(work),'-Djava.library.path='+str(game),'-Djava.awt.headless=true',
                    '--enable-native-access=ALL-UNNAMED','-javaagent:'+str(agent),'-cp',extra+str(classes)+os.pathsep+cp,'FloorAssetProbe',game,*paths],work)
                rows=dict(re.findall(r'^CHECK ([a-z0-9_]+)=(true|false)$',log,re.M))
                receipt['variants'].append({'name':variant,'checks':rows,'expectedFailure':marker});save()
                assert 'FLOOR_ASSET_DONE' in log and set(rows)==expected,log[-4000:]
                if marker:assert code!=0 and rows[marker]=='false' and 'FLOOR_ASSET_FAIL:' in log,variant+': control survived'
                else:assert code==0 and all(v=='true' for v in rows.values()),log[-4000:]
            receipt['checks']=len(expected);receipt['controls']=len(variants)-('production' in variants)
            receipt['inputsAfter']={str(p):sha(p)for p in inputs}
            assert receipt['inputsBefore']==receipt['inputsAfter'],'source drift'
            receipt['status']='PASS'
    except Exception as error:
        receipt['failure']=str(error);save();print('FAIL floor asset:',error);return 1
    save();print('PASS floor asset',receipt['checks']);return 0
if __name__=='__main__':raise SystemExit(main())
