#!/usr/bin/env python3
"""Native off-slot body, objects, source piano actions and canonical Music XP."""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import d2_leisure_music_test as music
from native_proof_preflight import installed_presence

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--baseline-only',action='store_true');args=parser.parse_args()
    out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    skill=music.ROOT/'mod/42.20/media/lua/client/SAO_LeisureSkill.lua'
    probe=music.ROOT/'tools/instrument_checks/InstrumentProbe.java'
    helpers=[music.ROOT/'tools/luacheck/MovementCrossingProbe.java',music.ROOT/'tools/luacheck/ResourceApproachProbe.java',music.ROOT/'tools/cognition_checks/CognitionUseProbe.java']
    native=[music.GAME/'media/lua/shared/ISBaseObject.lua',music.GAME/'media/lua/shared/TimedActions/ISBaseTimedAction.lua']
    jars=[music.GAME/'projectzomboid.jar',*sorted((music.GAME/'jars').glob('*.jar')),music.GAME/'ZombieBuddy.jar',music.ROOT/'mod/42.20/media/java/SAO.jar']
    manager=music.LS/'client/LSMoodleManager.lua';properties=music.LS/'client/Properties/MoodleProperties.lua'
    perks=music.LS.parent/'perks.txt';registry=music.LS.parent/'registries.lua'
    audioFiles=['shared/music/NMTrackCatalog.lua','shared/contracts/NMMediaContract.lua','shared/music/NMAlbumPackBuilder.lua','shared/music/NMProjectZomboidOST.lua']
    walkmanScript=music.NM.parent/'scripts/NM_Walkman_Items.txt'
    inputs=[Path(__file__),Path(music.__file__),music.OWNER,skill,probe,*helpers,*[p for p in music.FIXTURES.iterdir() if p.is_file()],*native,*jars,
        music.GAME/'stdlib.lua',manager,properties,perks,registry,walkmanScript,*[music.NM/p for p in music.NM_PROOF_FILES+audioFiles],*[music.LS/p for p in music.LS_FILES],*[music.NM/p for p in music.NM_FILES]]
    absent=installed_presence(inputs,music.GAME,music.JDK,'D2 native source piano',installed_roots=(music.LS.parent,music.NM.parent))
    if absent is not None:return absent
    receipt={'schema':'sao-d2-native-piano/1','status':'INCOMPLETE','inputsBefore':{str(p):music.sha(p)for p in inputs},'runs':[],
        'boundary':'Actual off-slot native SAOIsoPlayerShell, native paired IsoObjects in loaded grid, native furniture flag/facing/coordinates, actual installed trait registry with native constructor trait-map initialization after registration, actual custom Music perk/native XP, original complete Lifestyle actions/utility/data/initializer and canonical LeisureSkill; native source-script Walkman item/owned inventory/held custody plus unchanged NewMusic catalogue (13 real OST tracks), mode/attachment/dispatch/runtime/battery/ending. Initial inserted cassette/headphone/battery state and external/helper/cache hosts controlled. Furniture flag and facing are controlled native setup, not proof of native Rest preparation. Visibility observations, queue/audio/worldsound/clock/concept/planner hosts controlled. No rendered scene or gameplay prevalence claim.'}
    def save():(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    def run(name,cmd,cwd):
        result=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=90);log=out/(name+'.log');log.write_bytes(result.stdout+result.stderr)
        receipt['runs'].append({'name':name,'exitCode':result.returncode,'log':str(log),'sha256':music.sha(log)});save()
        return result.returncode,log.read_text(encoding='utf-8',errors='replace')
    try:
        manifest=out/'source-paths.tsv'
        manifest.write_text(''.join(k+'\t'+str((music.LS if k.startswith('LifestyleHobbies:')else music.NM)/k.split(':',1)[1])+'\n'for k in music.pins())+''.join('NewMusic:'+p+'\t'+str(music.NM/p)+'\n'for p in music.NM_PROOF_FILES+audioFiles),encoding='utf-8')
        init=out/'source-initializer.lua';prefix='LSMoodleManager.init = function(player)'
        original=manager.read_text(encoding='utf-8');assert original.count(prefix)==1
        init.write_text('__moodleProperties=(function()\n'+properties.read_text(encoding='utf-8')+'\nend)()\nLSMoodleManager={}\n'
            +'local previousRequire=require;require=function(name)if name=="Properties/MoodleProperties"then return __moodleProperties end;return previousRequire(name)end\n'
            +prefix+original.split(prefix,1)[1].split('function LSMoodleManager.getMoodle',1)[0],encoding='utf-8')
        enums=out/'native-enums.lua';enums.write_text('Perks=__nativePerks;CharacterTrait=__nativeCharacterTrait;Metabolics=__nativeMetabolics;MoodleType=__nativeMoodleType;IsoDirections=__nativeIsoDirections;instanceof=__nativeinstanceof\n',encoding='utf-8')
        java=probe.read_text(encoding='utf-8').replace('public final class InstrumentProbe','public final class NativePianoProbe')
        java=java.replace('IsoCell.class,zombie.iso.IsoGridSquare.class',
            'java.util.Map.class,zombie.characters.IsoGameCharacter.XP.class,zombie.characters.skills.PerkFactory.Perk.class,zombie.characters.skills.PerkFactory.Perks.class,zombie.scripting.objects.CharacterTrait.class,zombie.characters.BodyDamage.Metabolics.class,zombie.iso.IsoDirections.class,zombie.characters.AttachedItems.AttachedItems.class,zombie.characters.AttachedItems.AttachedItem.class,zombie.characters.WornItems.WornItems.class,zombie.characters.WornItems.WornItem.class,\n            IsoCell.class,zombie.iso.IsoGridSquare.class')
        injection='''LuaCompiler.register(env);
        var sources=platform.newTable();for(var row:Files.readAllLines(Path.of(MANIFEST))){var parts=row.split("\\t",2);sources.rawset(parts[0],Files.readString(Path.of(parts[1])).replace("\\r\\n","\\n"));}env.rawset("__sources",sources);
        zombie.scripting.ScriptManager.instance.ParseScript(zombie.scripting.ScriptLoadMode.Init,"module NewMusic { }");
        var nmModule=zombie.scripting.ScriptManager.instance.getModule("NewMusic");
        String deviceText=zombie.scripting.ScriptParser.stripComments(Files.readString(Path.of(WALKMAN)));
        int start=deviceText.indexOf("item WalkmanBlue");if(start<0)throw new AssertionError("native NewMusic device source missing");
        int end=deviceText.indexOf('{',start)+1,depth=1;while(depth>0){char c=deviceText.charAt(end++);if(c=='{')depth++;else if(c=='}')depth--;}
        var definition=new zombie.scripting.objects.Item();definition.setModule(nmModule);definition.setName("WalkmanBlue");definition.Load("WalkmanBlue",deviceText.substring(start,end));definition.setRegistry_id((short)2999);nmModule.items.getScriptMap().put("WalkmanBlue",definition);
        var device=definition.InstanceItem(null);if(device==null)throw new AssertionError("native NewMusic factory refused");device.setID(2999);env.rawset("__device",device);
        var custom=new zombie.characters.skills.CustomPerks();var read=zombie.characters.skills.CustomPerks.class.getDeclaredMethod("readFile",String.class);read.setAccessible(true);read.invoke(custom,PERKS);custom.init();custom.initLua();
        for(String name:new String[]{"Perks","CharacterTrait","Metabolics","MoodleType","IsoDirections","instanceof"})env.rawset("__native"+name,env.rawget(name));
        exposer.exposeGlobalClassFunction((se.krka.kahlua.vm.KahluaTable)env.rawget("CharacterTrait"),zombie.scripting.objects.CharacterTrait.class,zombie.scripting.objects.CharacterTrait.class.getMethod("register",String.class),"register");
        exposer.exposeGlobalClassFunction((se.krka.kahlua.vm.KahluaTable)env.rawget("ItemTag"),zombie.scripting.objects.ItemTag.class,zombie.scripting.objects.ItemTag.class.getMethod("register",String.class),"register");
        var global=new zombie.Lua.LuaManager.GlobalObject();
        env.rawset("addXp",(JavaFunction)(f,n)->{global.addXp((zombie.characters.IsoPlayer)f.get(0),(zombie.characters.skills.PerkFactory.Perk)f.get(1),((Number)f.get(2)).floatValue());return 0;});
        env.rawset("SyncXp",(JavaFunction)(f,n)->{global.SyncXp((zombie.characters.IsoPlayer)f.get(0));return 0;});
        env.rawset("__initSourceTraits",(JavaFunction)(f,n)->{body.getCharacterTraits().getTraits().putAll(new zombie.characters.traits.CharacterTraits().getTraits());return 0;});
        body.getForwardDirection().set(0,-1);
        var p=new IsoObject(cell);p.setSquare(cell.getGridSquare(10,19,0));var ps=new zombie.iso.sprite.IsoSprite();ps.name="recreational_01_8";p.setSprite(ps);p.getSquare().getObjects().add(p);
        var q=new IsoObject(cell);q.setSquare(cell.getGridSquare(11,19,0));var qs=new zombie.iso.sprite.IsoSprite();qs.name="recreational_01_9";q.setSprite(qs);q.getSquare().getObjects().add(q);
        env.rawset("__piano",p);env.rawset("__pair",q);
        '''
        injection=injection.replace('WALKMAN',json.dumps(str(walkmanScript))).replace('MANIFEST',json.dumps(str(manifest))).replace('PERKS',json.dumps(str(perks)))
        java=java.replace('env.rawset("__body",body);',injection+'env.rawset("__body",body);')
        generated=out/'NativePianoProbe.java';generated.write_text(java,encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='sao-native-piano-')as tmp:
            work=Path(tmp);shutil.copyfile(music.GAME/'stdlib.lua',work/'stdlib.lua');cp=os.pathsep.join(map(str,jars))
            code,log=run('compile',[music.JDK/'javac.exe','-encoding','UTF-8','-cp',cp,'-d',work,*helpers,generated],work);assert code==0,log
            receiver=skill.read_text(encoding='utf-8-sig');receipt['controls']=[]
            ownerText=music.OWNER.read_text(encoding='utf-8');variants=[('baseline',receiver,None)]
            if not args.baseline_only:
                variants.append(('omitted-native-XP',receiver.replace('addXp(body,perk,request.amount)','-- native primitive removed',1),'joined_native_music_XP'))
                variants.append(('omitted-native-trait-init',receiver,'native_source_registered_traits'))
                variants.append(('omitted-native-location-guard',receiver,'native_audio_attachment_loss_interrupts'))
                variants.append(('omitted-private-audio-cleanup',receiver,'native_audio_death_owned_cleanup'))
            for name,text,marker in variants:
                variant=out/(name+'-receiver.lua');variant.write_text(text,encoding='utf-8')
                ownerPath=music.OWNER
                if name=='omitted-native-location-guard':
                    ownerPath=out/(name+'-owner.lua');ownerPath.write_text(ownerText.replace('context~=a.offer.sourceContext','false',1),encoding='utf-8')
                if name=='omitted-private-audio-cleanup':
                    ownerPath=out/(name+'-owner.lua');ownerPath.write_text(ownerText.replace('if a.playback then a.env.NMPlaybackRuntime.forceStop(body,a.playback.deviceUUID,reason or "sao-interrupted") end','-- private retained sound cleanup omitted',1),encoding='utf-8')
                cases=music.FIXTURES/'native-piano-cases.lua'
                if name=='omitted-native-trait-init':
                    changed=out/(name+'-cases.lua');changed.write_text(cases.read_text().replace('__initSourceTraits()','-- native constructor initialization omitted',1),encoding='utf-8');cases=changed
                code,log=run(name,[music.JDK/'java.exe','-Duser.home='+str(work),'-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
                    '-cp',str(work)+os.pathsep+cp,'NativePianoProbe',music.GAME,music.FIXTURES/'prelude.lua',enums,registry,*native,music.LS/'shared/LSUtil.lua',init,variant,ownerPath,cases],work)
                if marker:assert code!=0 and 'D2_NATIVE_PIANO:'+marker in log,log[-7000:];receipt['controls'].append({'name':name,'expectedFailure':marker})
                else:assert code==0 and 'PASS native source piano 'in log,log[-8500:];receipt['checks']=int(re.search(r'PASS native source piano (\d+)',log)[1])
        receipt['inputsAfter']={str(p):music.sha(p)for p in inputs};assert receipt['inputsBefore']==receipt['inputsAfter'],'inputs changed'
        receipt['status']='PASS';save();print('PASS native piano',receipt['checks'],'checks;',len(receipt['controls']),'controls');return 0
    except Exception as error:receipt['status']='FAIL';receipt['error']=str(error);save();raise
if __name__=='__main__':raise SystemExit(main())
